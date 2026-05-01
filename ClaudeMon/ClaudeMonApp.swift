import SwiftUI

@main
struct ClaudeMonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Required: SwiftUI App needs at least one Scene.
        // We don't show a window — the AppDelegate creates the NSStatusItem + NSPopover.
        Settings { EmptyView() }
    }
}
