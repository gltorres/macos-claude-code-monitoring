import Foundation
import OSLog
import WebKit

enum CookieExtractor {
    static let cookieName = "sessionKey"
    private static let log = Logger(subsystem: "app.claudemon.ClaudeMon", category: "CookieExtractor")

    /// Accept exactly "claude.ai" and any subdomain of claude.ai.
    static func matches(_ cookie: HTTPCookie) -> Bool {
        guard cookie.name == cookieName else { return false }
        let domain = cookie.domain.lowercased()
        return domain == "claude.ai" || domain == ".claude.ai" || domain.hasSuffix(".claude.ai")
    }

    /// Trim + prefix-validate a candidate sessionKey value.
    /// Returns the cleaned value if it looks plausible, else nil.
    /// Public so the unit tests can exercise the gate without WebKit.
    static func validate(value: String) -> String? {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Primary expected format. If Anthropic ever rotates the prefix this
        // first guard rejects it; the looser fallback below still accepts
        // anything plausibly key-shaped so the user isn't stuck.
        if raw.hasPrefix("sk-ant-sid01-") { return raw }
        // Fallback: any non-empty token of reasonable length.
        if raw.count >= 32, !raw.contains(" ") {
            log.notice("accepting sessionKey with unfamiliar prefix; please update validator if this is intentional (len=\(raw.count, privacy: .public))")
            return raw
        }
        log.notice("rejected sessionKey value (len=\(raw.count, privacy: .public))")
        return nil
    }

    /// Read the persistent WKWebsiteDataStore cookie jar and return the sessionKey value, if any.
    /// Returns nil if no matching cookie or if the value does not look like a session key.
    @MainActor
    static func currentValueFromWebKit() async -> String? {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await store.allCookies()
        guard let match = cookies.first(where: matches) else {
            log.debug("no sessionKey cookie in jar (\(cookies.count, privacy: .public) total cookies)")
            return nil
        }
        return validate(value: match.value)
    }
}

extension CookieExtractor {
    @MainActor
    private static var activeController: SignInWindowController?

    @MainActor
    static func presentInteractiveSignIn(
        onSuccess: @escaping (String) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let controller = SignInWindowController(
            onCaptured: { key in
                onSuccess(key)
                Self.activeController = nil
            },
            onCancelled: {
                onCancel()
                Self.activeController = nil
            })
        Self.activeController = controller
        controller.present()
    }
}

extension CookieExtractor {
    /// Layer A: Headlessly load a known claude.ai endpoint to give WebKit a
    /// chance to honour any rotated Set-Cookie, then re-read the persistent
    /// cookie jar. Returns the new sessionKey only if it differs from the
    /// value currently in Keychain.
    @MainActor
    static func attemptSilentRefresh(timeout: TimeInterval = 8) async -> String? {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: cfg)
        let waiter = SilentRefreshWaiter()
        webView.navigationDelegate = waiter
        // Hold a strong reference until the wait completes (the local + the
        // navigation delegate's continuation keep webView alive throughout).
        Self.silentRefreshWebView = webView
        defer { Self.silentRefreshWebView = nil }
        webView.load(URLRequest(url: URL(string: "https://claude.ai/api/auth/current_account")!))
        await waiter.waitForFinish(timeout: timeout)
        let key = await currentValueFromWebKit()
        if let key, key != KeychainStore.sessionKey() { return key }
        return nil
    }

    @MainActor
    private static var silentRefreshWebView: WKWebView?
}

private final class SilentRefreshWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var fired = false

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { resume() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { resume() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { resume() }

    private func resume() {
        guard !fired else { return }
        fired = true
        continuation?.resume()
        continuation = nil
    }

    func waitForFinish(timeout: TimeInterval) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in self?.resume() }
        }
    }
}

private extension WKHTTPCookieStore {
    /// async wrapper around getAllCookies — WebKit's API is callback-based pre-iOS 17 / macOS 14.
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { (cont: CheckedContinuation<[HTTPCookie], Never>) in
            getAllCookies { cookies in
                cont.resume(returning: cookies)
            }
        }
    }
}
