import SwiftUI

/// Lightweight @AppStorage wrapper for non-secret preferences.
/// Secrets live in `KeychainStore`; everything cosmetic / cadence lives here.
struct Preferences {
    /// Polling cadence (seconds). Hard-floored at 30s in `clampedRefreshIntervalSeconds`
    /// to avoid tripping Anthropic's automated-access detection.
    @AppStorage("refreshIntervalSeconds") static var refreshIntervalSeconds: Int = 60

    /// Minimum percentage at which the menu bar badge starts showing the "%" overlay.
    /// Below this threshold, only the bare bolt icon is displayed.
    @AppStorage("badgeThresholdPercent") static var badgeThresholdPercent: Int = 10

    static var clampedRefreshIntervalSeconds: Int {
        max(30, min(600, refreshIntervalSeconds))
    }
}
