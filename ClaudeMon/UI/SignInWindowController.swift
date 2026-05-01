import AppKit
import OSLog
import WebKit

@MainActor
final class SignInWindowController: NSWindowController, WKNavigationDelegate {
    private let webView: WKWebView
    private let onCaptured: (String) -> Void
    private let onCancelled: () -> Void
    private let cookieObserver = CookieChangeObserver()
    private var didFinishOnce = false
    private var pollTask: Task<Void, Never>?
    private static let log = Logger(subsystem: "app.claudemon.ClaudeMon", category: "SignIn")

    init(onCaptured: @escaping (String) -> Void, onCancelled: @escaping () -> Void) {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()  // persistent across launches
        let webView = WKWebView(frame: .zero, configuration: cfg)
        if #available(macOS 13.3, *) {
            webView.isInspectable = true  // right-click → Inspect Element to debug
        }
        self.webView = webView
        self.onCaptured = onCaptured
        self.onCancelled = onCancelled

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Sign in to Claude"
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        webView.navigationDelegate = self

        // Subscribe to cookie-store writes — claude.ai is an SPA so the
        // sessionKey may land via XHR after didFinish has already fired.
        cookieObserver.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.checkForSessionKey(reason: "cookie-store-change")
            }
        }
        WKWebsiteDataStore.default().httpCookieStore.add(cookieObserver)
    }
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Belt-and-suspenders: poll every 1s as well, in case the observer
        // misses (or the cookie was already there from a previous session).
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, self?.didFinishOnce == false {
                self?.checkForSessionKey(reason: "poll")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func checkForSessionKey(reason: String) {
        Task { @MainActor [weak self] in
            guard let self, !self.didFinishOnce else { return }
            let store = WKWebsiteDataStore.default().httpCookieStore
            let cookies = await store.allCookies()
            Self.log.debug("\(reason, privacy: .public): \(cookies.count, privacy: .public) cookies in jar")
            for c in cookies {
                Self.log.debug("  cookie name=\(c.name, privacy: .public) domain=\(c.domain, privacy: .public) httpOnly=\(c.isHTTPOnly, privacy: .public) secure=\(c.isSecure, privacy: .public) valueLen=\(c.value.count, privacy: .public)")
            }
            if let key = await CookieExtractor.currentValueFromWebKit() {
                Self.log.debug("captured sessionKey via \(reason, privacy: .public)")
                self.finish(with: key)
            }
        }
    }

    // MARK: - WKNavigationDelegate
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.checkForSessionKey(reason: "didFinish")
        }
    }

    private func finish(with key: String) {
        guard !didFinishOnce else { return }
        didFinishOnce = true
        pollTask?.cancel()
        WKWebsiteDataStore.default().httpCookieStore.remove(cookieObserver)
        onCaptured(key)
        close()
    }
}

extension SignInWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pollTask?.cancel()
            WKWebsiteDataStore.default().httpCookieStore.remove(self.cookieObserver)
            if !self.didFinishOnce { self.onCancelled() }
        }
    }
}

/// Bridge for `WKHTTPCookieStoreObserver`, which is `@objc` and not
/// `@MainActor`. Forwards a single closure-shaped notification.
private final class CookieChangeObserver: NSObject, WKHTTPCookieStoreObserver {
    var onChange: (() -> Void)?
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        onChange?()
    }
}
