import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    let usageStore = UsageStore()

    private enum PopoverMode { case settings, usage }
    private var currentMode: PopoverMode = .usage
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // belt-and-suspenders with LSUIElement

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuBarBadge.compose(percent: nil, resetsAt: nil)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 440)
        refreshPopoverContent()

        // Kick off an immediate fetch + the auto-refresh loop.
        startAutoRefresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Decide what to show: SettingsView if no token yet, otherwise the panel.
            let mode: PopoverMode = (KeychainStore.sessionKey() == nil) ? .settings : .usage
            setPopoverMode(mode)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func didWake() {
        Task { @MainActor in
            await usageStore.refresh()
            updateMenuBarBadge()
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if KeychainStore.sessionKey() != nil {
                    await self.usageStore.refresh()
                    await MainActor.run { self.updateMenuBarBadge() }
                }
                let interval = Preferences.clampedRefreshIntervalSeconds
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        }
    }

    // MARK: - Popover content routing

    private func setPopoverMode(_ mode: PopoverMode) {
        currentMode = mode
        refreshPopoverContent()
    }

    private func refreshPopoverContent() {
        let host: NSViewController
        switch currentMode {
        case .settings:
            let view = SettingsView(onSaved: { [weak self] in
                guard let self else { return }
                // Token saved — swap to usage panel and trigger a fresh fetch.
                self.setPopoverMode(.usage)
                Task { @MainActor in
                    await self.usageStore.refresh()
                    self.updateMenuBarBadge()
                }
            })
            host = NSHostingController(rootView: view)
        case .usage:
            // If somehow there's no token yet, show settings instead.
            if KeychainStore.sessionKey() == nil {
                currentMode = .settings
                refreshPopoverContent()
                return
            }
            let view = UsagePanelView(
                onOpenSettings: { [weak self] in
                    self?.setPopoverMode(.settings)
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
            .environmentObject(usageStore)
            host = NSHostingController(rootView: view)
        }
        popover.contentViewController = host
    }

    func updateMenuBarBadge() {
        let session = usageStore.snapshot?.fiveHour
        statusItem.button?.image = MenuBarBadge.compose(
            percent: session?.utilizationInt,
            resetsAt: session?.resetsAt
        )
    }
}
