# Architecture

ClaudeMon is a single AppKit/SwiftUI menu-bar app with no external service
dependencies beyond `claude.ai`. This doc maps the four module boundaries
and the two flows that span them.

## Module map

| Folder | Responsibility |
| --- | --- |
| `ClaudeMon/Auth/` | Cookie capture (WKWebView), cookie persistence (Keychain). |
| `ClaudeMon/Network/` | HTTPS client for `claude.ai/api/organizations[/:uuid/usage]`. |
| `ClaudeMon/Models/` | `Codable` types for the usage payload. |
| `ClaudeMon/State/` | Polling timer, refresh-interval preference, in-memory snapshot. |
| `ClaudeMon/UI/` | SwiftUI popover content + AppKit menu-bar item glue. |

Entry points (`AppDelegate`, `ClaudeMonApp`) live at the target root because
moving them into a subfolder buys nothing at this size.

## Flow 1: polling cycle

```
NSStatusItem (menu bar bolt)
        │ click
        ▼
NSPopover ── hosts ──► UsagePanelView (SwiftUI)
                            │ observes
                            ▼
                       UsageStore (@MainActor, ObservableObject)
                            │ Timer @ refreshIntervalSeconds (30–600s)
                            ▼
                       ClaudeUsageClient.fetchUsage()
                            │ HTTPS GET, sessionKey in cookie header
                            ▼
                       claude.ai/api/organizations
                       claude.ai/api/organizations/{uuid}/usage
                            │ JSON
                            ▼
                       UsageSnapshot (Codable, all fields optional)
                            │ assigned to @Published
                            ▼
                       UsagePanelView re-renders
                       MenuBarBadge re-renders (NN% overlay if any bucket ≥ 10%)
```

Two out-of-band triggers also call into `UsageStore.refresh()`:
- The footer refresh button in `UsagePanelView`.
- `NSWorkspace.didWakeNotification` (so the badge isn't stale after sleep).

The 30–600s clamp lives in `Preferences.refreshIntervalSeconds`. The 30s
floor is intentional: claude.ai is sensitive to automated traffic, and 60s
is the project's default safe cadence.

## Flow 2: auth (cookie acquisition)

Two paths produce a `sessionKey` in the Keychain. Both end at the same store.

**Path A — in-app sign-in (default).** User clicks "Sign in to Claude":

```
SettingsView (Sign in button)
        │
        ▼
SignInWindowController (AppKit window, 540×700)
        │ hosts
        ▼
WKWebView at https://claude.ai/login
        │ user signs in normally
        │ WKWebsiteDataStore.default() persists cookies
        ▼
CookieExtractor.extract(from: webView)
        │ filters HTTPCookie where name == "sessionKey"
        │ and domain matches claude.ai (exact or subdomain)
        ▼
KeychainStore.setSessionKey(value)
        │ kSecClassGenericPassword
        │ kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ▼
window auto-closes; UsageStore observes the new key and starts polling
```

**Path B — manual paste.** User pastes a `sk-ant-sid01-…` value into the
"Advanced: paste cookie manually" field in `SettingsView`. Bypasses the
WebView entirely, lands directly in `KeychainStore.setSessionKey`.

## Sign-out

`KeychainStore.delete()` removes the entry. `UsageStore` notices the missing
key on next refresh, blanks its snapshot, and `UsagePanelView` swaps back to
`SettingsView`.

## What's deliberately not here

- No analytics, telemetry, or crash reporting.
- No third-party SDKs. Only Apple frameworks (Foundation, AppKit, SwiftUI,
  WebKit, Security, OSLog).
- No background daemon or LaunchAgent. The app is `LSUIElement` and lives in
  the user-session menu bar; it exits with the user.
- No iCloud sync of the cookie. The Keychain accessibility flag explicitly
  disables device-to-device sync.

## Where to put your PR

- Fixing the response schema (verifying placeholders): `Models/UsageSnapshot.swift`.
- Adding a UI bucket: extend `UsageSnapshot`, then add a row in `UsagePanelView`.
- Changing polling cadence behavior: `State/UsageStore.swift` + `State/Preferences.swift`.
- Touching auth: `Auth/`. Re-run the full smoke test in `docs/manual-smoke-test.md`.
