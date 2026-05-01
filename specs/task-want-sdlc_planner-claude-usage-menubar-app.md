# Claude Usage Menu Bar App Implementation Plan

## Metadata
task_id: `want`
task_input: `Native macOS menu bar app that displays the same usage data as claude.ai/settings/usage (current 5-hour session, weekly all-models, weekly Sonnet-only, Claude Design, daily routine runs, extra usage), driven by the user's claude.ai sessionKey cookie. UI styled like the Docker Desktop menu bar dropdown, with progress bars for the current session and weekly usage.`

## Overview

Build a native macOS status-bar app ("ClaudeMon") that lives next to the system clock. When the user clicks the icon, a popover panel shows the same usage windows visible at https://claude.ai/settings/usage — current 5-hour session, weekly All-models, weekly Sonnet-only, Claude Design (if exposed by the API), daily routine runs, and Extra-usage spend. The icon shows a compact "X%" badge of whichever bucket is closest to its limit, so the user sees pressure without opening the panel. The app authenticates by polling the same internal HTTP endpoint that the Settings page uses, using a `sessionKey` cookie the user pastes once and we store in the macOS Keychain.

The product goal is friction-free monitoring during long Claude Code sessions: no browser tab to keep open, no app to switch to, glanceable.

## Current State Analysis

There is no existing project at `/Users/alejtr/workspace/apps/claude-code-monitoring/` — the directory exists but is empty. We are starting from scratch. There is also no preferred toolchain / language convention to inherit; this directory is intentionally a greenfield app (separate from the rest of `~/workspace/apps`).

### Key Discoveries (from research):

- **The usage endpoint is `GET https://claude.ai/api/organizations/{org_uuid}/usage`**, corroborated across multiple open-source projects (hamed-elfayome/Claude-Usage-Tracker, sshnox/Claude-Usage-Tracker, alexesprit/claude-usage-widget). The `org_uuid` comes from `GET https://claude.ai/api/organizations` → `[0].uuid`. Both endpoints use cookie auth via `sessionKey=sk-ant-sid01-...`.
- **Confirmed JSON shape (partial):**
  ```json
  {
    "five_hour":        { "utilization": 34, "resets_at": "2026-04-30T18:00:00Z" },
    "seven_day":        { "utilization": 72, "resets_at": "2026-05-04T04:00:00Z" },
    "seven_day_opus":   { "utilization": 93, "resets_at": "2026-05-06T12:00:00Z" },
    "seven_day_sonnet": { "utilization": 49, "resets_at": "2026-05-04T04:00:00Z" }
  }
  ```
  `utilization` is integer 0–100, `resets_at` is ISO 8601.
- **Fields visible in the user's screenshot but NOT confirmed in any public project**: "Claude Design" weekly bucket, "Daily included routine runs" count, "Extra usage" dollars/limit/balance, auto-reload toggle. These may live on the same `/usage` payload (under different keys) or on a separate billing/entitlements endpoint. The implementer must capture the actual shape via Chrome DevTools (Network tab → filter Fetch/XHR → load /settings/usage) on Day 1 of Phase 3 before finalizing the data model.
- **Anti-bot considerations**: Anthropic enforces against automated access of `claude.ai`. Documented bans target *message-sending* through subscription sessions (the OpenClaw enforcement), not usage polling. To stay safely on the read-only side, the client must (a) use a realistic browser User-Agent, (b) include `Referer: https://claude.ai/` and the standard `Sec-Fetch-*` headers, (c) poll no more often than every 60 seconds, (d) use macOS `URLSession` (which has a normal TLS fingerprint — no spoofing library needed).
- **Architecture consensus in 2026**: For a popover-style menu bar app with auto-refreshing content, use `NSStatusItem` + `NSPopover` hosting an `NSHostingController<SwiftUIView>`. SwiftUI's `MenuBarExtra` (macOS 13+) has multiple unresolved bugs as of April 2026 — no programmatic show/hide (FB11984872), broken `openSettings` on macOS 26, no rerender-on-open (FB13683950) — and the popular `FluidMenuBarExtra` workaround was archived January 2026.
- **Closest reference apps**:
  - [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker) (~2.3k stars, Swift/macOS, exact same use case) — the closest prior art; instructive but we're not forking.
  - [eddmann/ClaudeMeter](https://github.com/eddmann/ClaudeMeter) — Swift, same manual-paste flow.
  - [AnaghSharma/Ambar-SwiftUI](https://github.com/AnaghSharma/Ambar-SwiftUI) — clean architectural template.
- **Tooling consensus**: vanilla Xcode project (not Tuist / SPM executable / XcodeGen) for a single-target signed/notarized app. macOS 14.0 minimum deployment target. Raw `SecItem` for Keychain (~30 lines, no dependency). `SMAppService.mainApp.register()` for launch at login.

## Desired End State

A user can:
1. Download a notarized `.dmg` or build from source, launch the app, and see a small bolt-shaped icon in their menu bar next to the clock with no Dock icon.
2. Click the icon once to open a Preferences flow that asks for their `sessionKey`, with copy-pasteable instructions for retrieving it from Chrome/Safari DevTools.
3. Paste the cookie value once; the app stores it in Keychain, fetches the org UUID, and from that point displays usage automatically.
4. See a Docker-Desktop-style popover with section headers ("Plan usage limits", "Weekly limits", "Additional features", "Extra usage"), each row showing a label, a horizontal progress bar tinted blue (or red for >80%), the percentage to the right, and a "Resets in N hr M min" subtitle below the label. The popover updates every 60 seconds.
5. See a numeric badge on the menu bar icon — the higher of current-session % and weekly all-models %, shown only when ≥10% to keep the bar quiet — so they can monitor without opening the popover.
6. Toggle "Launch at login" from the popover's footer. Quit cleanly via "Quit ClaudeMon ⌘Q" in the footer.

Verification: a real claude.ai user can paste their sessionKey and see live numbers within 5 seconds; the values match what the web Settings → Usage page shows; the menu bar badge updates on a 60-second cadence.

## What We're NOT Doing

- **Not parsing local Claude Code CLI files** (`~/.claude/projects/**/*.jsonl`). That's a different feature space (ccusage, claude-monitor, ClaudeBar) and not what the user asked for. The web Settings → Usage page reflects API-side accounting, which is what we're surfacing.
- **Not OAuth via Claude Code credentials** (`~/.claude/.credentials.json`). Claude-God / claude-monitor do this and it works, but the user explicitly said "take the token from the web session for Claude," meaning the cookie-based path. We can add OAuth as a Phase 7 follow-up if requested.
- **Not an embedded WebView login** that scrapes the cookie. That's the most user-friendly auth (hamed-elfayome does it) but is a substantial separate feature; manual paste is acceptable for v1 and is what eddmann/ClaudeMeter ships.
- **Not iOS/iPad companion or iCloud sync.** Mac menu bar only.
- **Not historical usage charts.** Just the current snapshot. Adding history is a Phase 7 follow-up.
- **Not a Dock-app fallback UI.** Status-bar-only (`LSUIElement = YES`).
- **Not handling the "Buy extra usage" flow.** We display the spend numbers; the user clicks through to claude.ai to buy.
- **Not multi-account / multi-org.** v1 supports one signed-in claude.ai account.
- **Not browser-based E2E with Playwright.** Native AppKit popovers cannot be driven by Playwright. v1 ships with a manual smoke-test checklist; XCUITest is a follow-up if the app warrants it.

## Implementation Approach

**Stack:** Swift 5.10 / 6.0 + SwiftUI (for popover content) + AppKit (`NSStatusItem`, `NSPopover`, `NSHostingController` bridge). Built as a single-target Xcode project.

**Why this stack:** Swift+SwiftUI is the only path that produces a binary with native menu-bar integration, native template-image handling for light/dark, native Keychain access, native notarization, and zero runtime overhead. Electron is rejected because the whole point is glanceable + lightweight. Tauri is interesting but its menu-bar support is not on par with native AppKit. A pure AppKit (no SwiftUI) version would also work but SwiftUI's `ProgressView`, `VStack`, and binding model save substantial layout code for what is fundamentally a list of progress bars.

**Why NSStatusItem + NSPopover (not MenuBarExtra):** see Key Discoveries. MenuBarExtra is shorter to write but has open SwiftUI bugs (FB11984872, FB13683950, broken openSettings on macOS 26) that bite real apps. NSStatusItem hosting a `NSHostingController<SwiftUIView>` gives us SwiftUI for the panel content with full programmatic control over show/hide/sizing/dismissal and the menu bar icon swap-out.

**Layered design:**
- `App/AppDelegate.swift` owns the NSStatusItem + NSPopover and the auto-refresh timer.
- `Auth/KeychainStore.swift` is a 30-line SecItem wrapper for read/write/delete of the sessionKey.
- `Network/ClaudeUsageClient.swift` is `URLSession`-based; one method `fetchUsage() async throws -> UsageSnapshot`. Bootstraps org UUID once per launch, then polls.
- `Models/UsageSnapshot.swift` is a Codable struct with one optional bucket per dashboard row (so unknown fields gracefully degrade to "—" rather than crashing).
- `UI/UsagePanelView.swift` is a SwiftUI view rendering sections + progress bars from a `@StateObject` ViewModel. `UI/SettingsView.swift` is the sessionKey paste / launch-at-login screen.
- `UI/MenuBarBadge.swift` renders the SF Symbol icon + optional "%" overlay when the highest bucket exceeds a threshold.

**Phase ordering rationale:** Phase 1 produces a runnable shell with no API. Phase 2 adds Keychain in isolation. Phase 3 adds the network client and *finalizes the data model* using the user's actual DevTools capture (the unknown fields). Phase 4 wires the popover UI to the data model. Phase 5 is auto-refresh + the menu bar badge. Phase 6 is launch-at-login + signing/notarization. Each phase produces a working app — incremental, demoable.

## Relevant Files

This is greenfield, so all files are new. The "relevant files" are conceptual references (research links + similar projects to model after).

External references to read before starting Phase 3:
- https://github.com/hamed-elfayome/Claude-Usage-Tracker — closest prior art (Swift/macOS); skim its `UsageService.swift` and `KeychainHelper.swift` for shape, do not copy.
- https://github.com/AnaghSharma/Ambar-SwiftUI — minimal NSStatusItem + NSPopover + SwiftUI template; reference for `AppDelegate` wiring.
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — current canonical guide.
- https://multi.app/blog/pushing-the-limits-nsstatusitem — for menu-bar icon overlays / dynamic sizing / multi-click targets.

### New Files

Project root `/Users/alejtr/workspace/apps/claude-code-monitoring/`:

- `ClaudeMon.xcodeproj/` — Xcode project with one app target. Created via Xcode → File → New → Project → macOS → App, language Swift, interface SwiftUI, lifecycle SwiftUI App.
- `ClaudeMon/ClaudeMonApp.swift` — `@main` SwiftUI entry, declares `NSApplicationDelegateAdaptor(AppDelegate.self)` and an empty `Settings { EmptyView() }` scene (required so SwiftUI has a Scene).
- `ClaudeMon/AppDelegate.swift` — owns `NSStatusItem`, `NSPopover`, refresh timer; sets `NSApp.setActivationPolicy(.accessory)`; handles icon click toggling popover.
- `ClaudeMon/Info.plist` (or `INFOPLIST_KEY_LSUIElement = YES` in build settings if using generated Info.plist) — `LSUIElement = YES`.
- `ClaudeMon/ClaudeMon.entitlements` — App Sandbox: `com.apple.security.app-sandbox = true`, `com.apple.security.network.client = true`. (Keychain access for generic password items in your own bundle does not require an explicit entitlement.)
- `ClaudeMon/Auth/KeychainStore.swift` — `static func setSessionKey(_:)`, `static func sessionKey() -> String?`, `static func delete()`.
- `ClaudeMon/Network/ClaudeUsageClient.swift` — `URLSession`-based; `func bootstrapOrgUUID() async throws -> String`, `func fetchUsage(orgUUID:) async throws -> UsageSnapshot`.
- `ClaudeMon/Network/HTTPHeaders.swift` — central place for `User-Agent`, `Referer`, `Sec-Fetch-*`, `Accept` constants.
- `ClaudeMon/Models/UsageSnapshot.swift` — Codable; one struct, with `Bucket` substruct (`utilization`, `resetsAt`) and optional members so unknown server fields degrade gracefully.
- `ClaudeMon/Models/Bucket.swift` — `struct Bucket: Codable { let utilization: Int; let resetsAt: Date }` + helpers (color, formatted reset).
- `ClaudeMon/UI/UsagePanelView.swift` — the popover SwiftUI view (the visual analog of image #1 in the user's request).
- `ClaudeMon/UI/UsageRowView.swift` — one row: label + reset subtitle + ProgressView + "%" trailing label. Reused for every bucket.
- `ClaudeMon/UI/SettingsView.swift` — sessionKey paste field, launch-at-login toggle, "How do I find my sessionKey?" disclosure with screenshot.
- `ClaudeMon/UI/MenuBarBadge.swift` — `func renderIcon(highest: Int?) -> NSImage` that returns either the bare bolt symbol or a composited bolt + small "%" badge using `NSImage.lockFocus`.
- `ClaudeMon/State/UsageStore.swift` — `@MainActor final class UsageStore: ObservableObject` with `@Published var snapshot`, `@Published var lastError`, `@Published var lastUpdated`, plus `func refresh() async`. Owned by `AppDelegate`, injected into views as an `@EnvironmentObject`.
- `ClaudeMon/State/Preferences.swift` — `@AppStorage` wrappers for non-secret prefs (refresh interval, badge threshold).
- `README.md` — install instructions, sessionKey extraction guide with screenshot, security note ("the cookie stays in your Keychain, never leaves your machine"), build-from-source instructions.
- `manual-smoke-test.md` — the manual checklist used in lieu of Playwright E2E (see Testing Strategy).

## User Stories

### User Stories

- **As a Claude Max subscriber doing long coding sessions, I want to see my current 5-hour-session percentage in the menu bar without opening anything,** so that I know when to pause or switch models before I burn through my window.
- **As a user setting up the app for the first time, I want clear, illustrated instructions for finding my sessionKey cookie in Chrome/Safari DevTools,** so that I don't have to leave the app to figure out what to paste.
- **As a privacy-conscious user, I want my sessionKey stored only in macOS Keychain and never written to disk in plaintext,** so that the cookie can't be read by other apps in my account.
- **As a user, I want a click on the menu bar icon to show me a Docker-Desktop-style dropdown with all four usage windows (current session, weekly all-models, weekly Sonnet, weekly Claude Design) plus reset times,** so that I have the same view I'd get from claude.ai/settings/usage.
- **As a user, when my current-session usage exceeds 80%, the progress bar shall turn red,** so that pressure is glanceable.
- **When my sessionKey expires or is revoked, the app shall display "Not signed in — paste a new sessionKey" in the popover and stop polling,** so that I don't see stale data and the app doesn't hammer the API.
- **When the network is offline, the app shall preserve the last successful snapshot, show a "Last updated 3 min ago" subtitle, and retry on the next interval,** so that transient outages don't blank the UI.
- **As a user who runs many menu bar apps, I want this one to launch at login automatically when I toggle a setting,** so that monitoring resumes after a reboot without manual steps.
- **As a user, I want the app to poll no more often than once a minute,** so that my account doesn't trigger Anthropic's automated-access detection.

---

## Phase 1: Project Bootstrap & Empty Menu Bar Shell

IMPORTANT: Execute every step in order, top to bottom.

### Overview
Produce a runnable, signed-with-development-cert app that puts a bolt SF Symbol in the menu bar, hides the Dock icon, and shows an empty placeholder popover when clicked. No networking, no Keychain, no SwiftUI complexity yet — just prove the AppKit wiring is correct.

### Changes Required:

#### 1. Create the Xcode project
Open Xcode (any version on macOS 14+; Xcode 16 / 26 both fine). File → New → Project → macOS → **App**:
- Product Name: `ClaudeMon`
- Team: your Apple ID (Personal team is fine for development; needed for code signing later)
- Organization Identifier: `com.alejtr` (use whatever bundle prefix you prefer)
- Bundle Identifier: `com.alejtr.ClaudeMon`
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: None
- Save under `/Users/alejtr/workspace/apps/claude-code-monitoring/`. Uncheck "Create Git repository on my Mac" — we'll do that ourselves below.
- After project creates: Project → Targets → ClaudeMon → General → Minimum Deployments → **macOS 14.0**.

#### 2. Mark as menu-bar-only (no Dock icon)
**File**: `ClaudeMon.xcodeproj` build settings (or generated `Info.plist`)
**Changes**: Add `LSUIElement = YES`.

In Xcode: select the ClaudeMon target → Info tab → click `+` → add key **`Application is agent (UIElement)`** → set value `YES`.
(If you prefer raw plist editing: `INFOPLIST_KEY_LSUIElement = YES` in build settings.)

#### 3. Replace the SwiftUI App scene with an empty Scene + AppDelegateAdaptor
**File**: `ClaudeMon/ClaudeMonApp.swift`

```swift
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
```

Delete the auto-generated `ContentView.swift` (we'll replace it with `UsagePanelView` later).

#### 4. Create the AppDelegate that owns the status item
**File**: `ClaudeMon/AppDelegate.swift`

```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // belt-and-suspenders with LSUIElement

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "bolt.fill",
                accessibilityDescription: "ClaudeMon usage"
            )
            image?.isTemplate = true   // auto-tints for light/dark/highlight
            button.image = image
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: Text("Hello, ClaudeMon").frame(width: 360, height: 220)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

#### 5. Init git repo
**Working dir**: `/Users/alejtr/workspace/apps/claude-code-monitoring/`

```bash
git init
echo "DerivedData/" > .gitignore
echo "*.xcuserstate" >> .gitignore
echo "xcuserdata/" >> .gitignore
echo ".DS_Store" >> .gitignore
git add . && git commit -m "Phase 1: empty menu bar shell"
```

### Success Criteria:

- [ ] `xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon -configuration Debug build` succeeds with zero errors and zero warnings.
- [ ] Running the app from Xcode (⌘R): a bolt icon appears in the menu bar, no Dock icon appears, no app menu appears at the top of the screen.
- [ ] Clicking the bolt icon shows a small popover containing "Hello, ClaudeMon"; clicking outside dismisses it.
- [ ] Quitting Xcode kills the menu bar icon (development behavior — fine for now).
- [ ] `git log --oneline` shows the bootstrap commit.

**Implementation Note**: After completing this phase, run all automated verification checks before proceeding to the next phase. Specifically: `xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon clean build` must pass.

---

## Phase 2: Keychain-Backed Token Storage & Settings Screen

IMPORTANT: Execute every step in order, top to bottom.

### Overview
Add Keychain read/write/delete for the sessionKey, plus a SwiftUI Settings screen the user opens to paste their cookie. The popover shows either the Settings screen (if no token saved) or a "Token saved — networking next phase" placeholder. No networking yet.

### Changes Required:

#### 1. KeychainStore — raw SecItem wrapper
**File**: `ClaudeMon/Auth/KeychainStore.swift`

```swift
import Foundation
import Security

enum KeychainStore {
    private static let service = "com.alejtr.ClaudeMon"
    private static let account = "claude-ai-session-key"

    static func setSessionKey(_ value: String) throws {
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Update if exists, otherwise add.
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(updateStatus)
        }
    }

    static func sessionKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    struct KeychainError: Error { let status: OSStatus
        init(_ s: OSStatus) { status = s }
    }
}
```

#### 2. SettingsView — paste field + Save / Clear buttons
**File**: `ClaudeMon/UI/SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @State private var pastedKey: String = ""
    @State private var status: SaveStatus = .idle
    var onSaved: () -> Void = {}

    enum SaveStatus { case idle, saved, error(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sign in to ClaudeMon")
                .font(.headline)

            DisclosureGroup("How do I find my sessionKey?") {
                Text("""
                1. Open Chrome / Safari and sign in to claude.ai.
                2. Press ⌥⌘I to open DevTools.
                3. Application tab → Storage → Cookies → https://claude.ai.
                4. Find sessionKey, double-click its Value, copy.
                5. Paste it below. Starts with sk-ant-sid01-.
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            SecureField("sk-ant-sid01-...", text: $pastedKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(pastedKey.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Clear", role: .destructive) {
                    KeychainStore.delete(); pastedKey = ""; status = .idle
                }
                Spacer()
                statusLabel
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .idle: EmptyView()
        case .saved: Text("Saved").foregroundStyle(.green).font(.caption)
        case .error(let m): Text(m).foregroundStyle(.red).font(.caption)
        }
    }

    private func save() {
        do {
            try KeychainStore.setSessionKey(pastedKey.trimmingCharacters(in: .whitespacesAndNewlines))
            status = .saved
            onSaved()
        } catch {
            status = .error("Keychain error: \(error)")
        }
    }
}
```

#### 3. Update AppDelegate to swap the popover content based on token presence
**File**: `ClaudeMon/AppDelegate.swift`
**Changes**: Replace the `Hello, ClaudeMon` placeholder with a routing view.

```swift
// In applicationDidFinishLaunching, replace the contentViewController = NSHostingController(...) line:
popover.contentViewController = NSHostingController(rootView: rootView())

// Add as method:
private func rootView() -> some View {
    Group {
        if KeychainStore.sessionKey() != nil {
            VStack(spacing: 12) {
                Text("Token saved.").font(.headline)
                Text("Networking arrives in Phase 3.").foregroundStyle(.secondary)
                Button("Sign out") {
                    KeychainStore.delete()
                    self.refreshPopoverContent()
                }
            }.padding(20).frame(width: 360, height: 220)
        } else {
            SettingsView(onSaved: { self.refreshPopoverContent() })
        }
    }
}

private func refreshPopoverContent() {
    popover.contentViewController = NSHostingController(rootView: rootView())
}
```

### Success Criteria:

- [ ] `xcodebuild ... build` passes with zero warnings.
- [ ] First launch: popover shows the Settings paste-field UI.
- [ ] Pasting any non-empty string and clicking Save → popover re-renders to "Token saved." state.
- [ ] Quitting and relaunching: popover opens directly to "Token saved." state (Keychain persisted).
- [ ] Clicking "Sign out" → popover returns to Settings paste-field UI, and `security find-generic-password -s com.alejtr.ClaudeMon -a claude-ai-session-key` from Terminal returns "could not be found".
- [ ] Manual: `security find-generic-password -s com.alejtr.ClaudeMon -a claude-ai-session-key -w` after Save prints the pasted value.

**Implementation Note**: After completing this phase, run all automated verification checks before proceeding to the next phase.

---

## Phase 3: Network Client + Live DevTools Capture + Data Model

IMPORTANT: Execute every step in order, top to bottom.

### Overview
This is the highest-risk phase because the schema for "Claude Design", "Daily routine runs", and "Extra usage" is not publicly known. Step 1 of this phase is a **manual capture session** by the developer, which determines the rest of the phase. Then we build a Codable model that mirrors the captured response, and a `URLSession` client that fetches it.

### Changes Required:

#### 1. **PREREQUISITE: Capture the real response**
Before writing code, the developer must:
1. Open Chrome → DevTools → Network tab → filter `Fetch/XHR` → check **Preserve log**.
2. Navigate to `https://claude.ai/settings/usage`. Wait for the page to render.
3. For every request whose path starts with `/api/`, record:
   - URL (path + query)
   - Method
   - Request headers (especially `User-Agent`, `Sec-Fetch-*`, `Cookie`, any `x-anthropic-*`, any `csrf` token)
   - Response body (paste verbatim into a scratch file)
4. Identify which response(s) contain: current 5-hour utilization, weekly all-models, Sonnet-only, Claude Design, daily routine runs, extra-usage spend dollars, monthly limit, current balance, auto-reload state.
5. Save the verbatim JSON to `ClaudeMon/Models/_Fixtures/captured_usage.json` (gitignored — contains an org UUID). This is our test fixture.

This step is mandatory; do not skip it. The schema below uses placeholder names and will need to be updated to match the captured field names exactly.

#### 2. UsageSnapshot model
**File**: `ClaudeMon/Models/UsageSnapshot.swift`

```swift
import Foundation

struct UsageSnapshot: Decodable {
    let fiveHour: Bucket?
    let sevenDay: Bucket?            // weekly All models
    let sevenDaySonnet: Bucket?      // weekly Sonnet only
    let sevenDayOpus: Bucket?        // weekly Opus only (bonus, may not be on free)
    let sevenDayDesign: Bucket?      // weekly Claude Design — TODO: confirm key from capture
    let routineRuns: RoutineRuns?    // TODO: confirm key from capture
    let extraUsage: ExtraUsage?      // TODO: confirm key from capture

    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
        case sevenDayDesign = "seven_day_design"   // verify
        case routineRuns    = "routine_runs"       // verify
        case extraUsage     = "extra_usage"        // verify
    }
}

struct Bucket: Decodable {
    let utilization: Int       // 0–100
    let resetsAt: Date

    enum CodingKeys: String, CodingKey {
        case utilization, resetsAt = "resets_at"
    }
}

struct RoutineRuns: Decodable {
    let used: Int
    let total: Int   // e.g. 0 / 15
}

struct ExtraUsage: Decodable {
    let spentCents: Int        // verify scale
    let monthlyLimitCents: Int
    let balanceCents: Int
    let autoReload: Bool
    let resetsAt: Date?
}
```

A `JSONDecoder` with `dateDecodingStrategy = .iso8601` is configured in the client.

#### 3. ClaudeUsageClient
**File**: `ClaudeMon/Network/ClaudeUsageClient.swift`

```swift
import Foundation

actor ClaudeUsageClient {
    static let shared = ClaudeUsageClient()
    private var cachedOrgUUID: String?

    enum ClientError: Error, LocalizedError {
        case missingSessionKey
        case unauthorized
        case noOrganization
        case http(status: Int, body: String)
        case decoding(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .missingSessionKey: return "No sessionKey saved."
            case .unauthorized:      return "Session expired — paste a new sessionKey."
            case .noOrganization:    return "No organizations on this account."
            case .http(let s, _):    return "claude.ai returned HTTP \(s)."
            case .decoding(let e):   return "Couldn't parse usage response: \(e)."
            }
        }
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let key = KeychainStore.sessionKey() else { throw ClientError.missingSessionKey }
        let orgUUID = try await orgUUID(sessionKey: key)
        let url = URL(string: "https://claude.ai/api/organizations/\(orgUUID)/usage")!
        let data = try await get(url, sessionKey: key)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(UsageSnapshot.self, from: data)
        } catch {
            throw ClientError.decoding(underlying: error)
        }
    }

    private func orgUUID(sessionKey: String) async throws -> String {
        if let cached = cachedOrgUUID { return cached }
        let url = URL(string: "https://claude.ai/api/organizations")!
        let data = try await get(url, sessionKey: sessionKey)
        struct Org: Decodable { let uuid: String }
        let orgs = try JSONDecoder().decode([Org].self, from: data)
        guard let first = orgs.first?.uuid else { throw ClientError.noOrganization }
        cachedOrgUUID = first
        return first
    }

    private func get(_ url: URL, sessionKey: String) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in HTTPHeaders.standard { req.setValue(v, forHTTPHeaderField: k) }
        req.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.http(status: -1, body: "") }
        if http.statusCode == 401 || http.statusCode == 403 { throw ClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
```

#### 4. HTTPHeaders constants
**File**: `ClaudeMon/Network/HTTPHeaders.swift`

```swift
enum HTTPHeaders {
    static let standard: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
                    + "(KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Accept": "application/json",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://claude.ai/",
        "Origin": "https://claude.ai",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Dest": "empty",
        "Cache-Control": "no-cache",
    ]
}
```

If the DevTools capture in step 1 reveals additional required headers (e.g. `x-anthropic-*`), add them here.

#### 5. UsageStore — observable wrapper
**File**: `ClaudeMon/State/UsageStore.swift`

```swift
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var lastError: String?
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let new = try await ClaudeUsageClient.shared.fetchUsage()
            snapshot = new
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
```

#### 6. AppDelegate wires the store + a one-shot fetch on launch (timer comes Phase 5)
**File**: `ClaudeMon/AppDelegate.swift`
**Changes**: Add `let usageStore = UsageStore()` property. In `applicationDidFinishLaunching`, after popover setup: `Task { await usageStore.refresh() }`. Pass `.environmentObject(usageStore)` to the hosting controller's root view.

### Success Criteria:

- [ ] `xcodebuild ... build` passes.
- [ ] Manual: with a real sessionKey saved, `print(usageStore.snapshot)` (added temporarily) shows non-nil values for `fiveHour` and `sevenDay`, and the percentages match what claude.ai/settings/usage shows ±1%.
- [ ] Manual: with no sessionKey, `usageStore.lastError == "No sessionKey saved."`.
- [ ] Manual: with a known-bad sessionKey, `usageStore.lastError == "Session expired — paste a new sessionKey."`.
- [ ] Unit test: a JSON fixture matching the captured response decodes into `UsageSnapshot` with the expected values (XCTest target — see Testing Strategy).

**Implementation Note**: Schema may differ from the placeholders above. Source of truth is the developer's DevTools capture. After completing this phase, run all automated verification checks before proceeding.

---

## Phase 4: Popover UI — The Docker-Style Panel

IMPORTANT: Execute every step in order, top to bottom.

### Overview
Build the SwiftUI views that render the popover: section headers, rows of (label / reset-time / progress bar / percentage), error banner, last-updated footer. Wire to `UsageStore` so it automatically reflects whatever is in the snapshot. Visual reference is image #2 in the user's request (Docker Desktop dropdown style).

### Changes Required:

#### 1. UsageRowView — the reusable row
**File**: `ClaudeMon/UI/UsageRowView.swift`

```swift
import SwiftUI

struct UsageRowView: View {
    let label: String
    let bucket: Bucket?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.body)
                    Text(resetSubtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(percentLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: barValue)
                .progressViewStyle(.linear)
                .tint(barColor)
        }
    }

    private var barValue: Double {
        Double(min(bucket?.utilization ?? 0, 100)) / 100.0
    }

    private var barColor: Color {
        guard let p = bucket?.utilization else { return .gray }
        if p >= 90 { return .red }
        if p >= 80 { return .orange }
        return .accentColor   // matches blue in the screenshot
    }

    private var percentLabel: String {
        bucket.map { "\($0.utilization)% used" } ?? "—"
    }

    private var resetSubtitle: String {
        guard let resetsAt = bucket?.resetsAt else { return "No data yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Resets " + formatter.localizedString(for: resetsAt, relativeTo: Date())
    }
}
```

#### 2. UsagePanelView — the whole popover
**File**: `ClaudeMon/UI/UsagePanelView.swift`

```swift
import SwiftUI

struct UsagePanelView: View {
    @EnvironmentObject var store: UsageStore
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            if let err = store.lastError {
                ErrorBanner(message: err, retry: { Task { await store.refresh() } })
            }

            section("Plan usage limits") {
                UsageRowView(label: "Current session", bucket: store.snapshot?.fiveHour)
            }

            section("Weekly limits") {
                UsageRowView(label: "All models", bucket: store.snapshot?.sevenDay)
                UsageRowView(label: "Sonnet only", bucket: store.snapshot?.sevenDaySonnet)
                if let design = store.snapshot?.sevenDayDesign {
                    UsageRowView(label: "Claude Design", bucket: design)
                }
            }

            if let runs = store.snapshot?.routineRuns {
                section("Additional features") {
                    HStack {
                        Text("Daily included routine runs")
                        Spacer()
                        Text("\(runs.used) / \(runs.total)").font(.caption.monospacedDigit())
                    }
                    ProgressView(value: Double(runs.used), total: Double(max(runs.total, 1)))
                        .progressViewStyle(.linear)
                }
            }

            if let extra = store.snapshot?.extraUsage {
                section("Extra usage") {
                    extraUsageView(extra)
                }
            }

            Divider()

            HStack {
                Text(footerText).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(action: { Task { await store.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.borderless)
                Button("Settings…", action: onOpenSettings).buttonStyle(.borderless)
                Button("Quit", action: onQuit).buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).bold()
            content()
        }
    }

    private func extraUsageView(_ extra: ExtraUsage) -> some View {
        let pct = extra.monthlyLimitCents > 0
            ? Int(Double(extra.spentCents) / Double(extra.monthlyLimitCents) * 100)
            : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("$\(Double(extra.spentCents)/100, specifier: "%.2f") spent")
                Spacer()
                Text("\(pct)% used").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(pct, 100))/100.0)
                .tint(pct >= 100 ? .red : .accentColor)
            Text("Monthly limit $\(Double(extra.monthlyLimitCents)/100, specifier: "%.2f") · "
               + "Balance $\(Double(extra.balanceCents)/100, specifier: "%.2f") · "
               + (extra.autoReload ? "Auto-reload on" : "Auto-reload off"))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var footerText: String {
        if store.isLoading { return "Updating…" }
        guard let t = store.lastUpdated else { return "Not yet updated" }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return "Updated \(f.localizedString(for: t, relativeTo: Date()))"
    }
}

private struct ErrorBanner: View {
    let message: String; let retry: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.caption)
            Spacer()
            Button("Retry", action: retry).buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
```

#### 3. AppDelegate wiring: route popover content
**File**: `ClaudeMon/AppDelegate.swift`
**Changes**: Replace `rootView()` to return either `SettingsView` or `UsagePanelView` depending on whether a token exists. Pass `usageStore` as environment object. `onQuit` calls `NSApp.terminate(nil)`. `onOpenSettings` swaps the popover content to a `SettingsView` and on save swaps it back. Keep the popover height dynamic (`popover.contentSize` updates from `.frame(width:height:)` of the SwiftUI root via `geometryReader`-based sizing OR a fixed 460×440 — start with fixed, tighten in Phase 6).

### Success Criteria:

- [ ] Popover renders the screenshot's layout: "Plan usage limits" / "Weekly limits" / "Additional features" / "Extra usage" sections in order.
- [ ] Bars show actual numbers from the saved sessionKey; resetting time shows "Resets in 3 hours" style copy.
- [ ] Color of a bar at 90% is red; at 50% is the accent blue.
- [ ] When the user clicks Refresh (arrow.clockwise), the "Updated 12s ago" footer updates within ~1s.
- [ ] When the user clicks Settings…, the popover swaps to `SettingsView`; saving a new key swaps back and a fresh fetch fires.
- [ ] When `lastError` is non-nil, a yellow error banner appears at the top.
- [ ] Visual: ProgressView matches the screenshot's blue (`.accentColor`); spacing is comfortable, not cramped.

#### 4. Manual smoke test file (instead of Playwright E2E)

**File**: `manual-smoke-test.md`

This native AppKit popover cannot be exercised by Playwright (Playwright drives browsers, not menu bar apps). Create a plain-text manual checklist that the developer (and any reviewer) walks through before each release. **List the steps explicitly** so the test is reproducible:

1. Build & launch the app from a clean Keychain state (run `security delete-generic-password -s com.alejtr.ClaudeMon` first).
2. Click the menu bar bolt → confirm SettingsView appears.
3. Paste a known-valid `sessionKey` → click Save → confirm UsagePanelView appears with non-zero `fiveHour` row within 5 seconds.
4. Compare the four bars to the live values at `https://claude.ai/settings/usage` → they match within ±1% and reset times match within ±1 minute.
5. Click Refresh → the "Updated" footer ticks to "0s ago".
6. Sign out from Settings → confirm SettingsView reappears.
7. Paste a *bad* sessionKey → confirm yellow "Session expired" banner appears.
8. Toggle network off (turn Wi-Fi off) → wait 60s → confirm an error banner appears, last snapshot stays visible.

Capture screenshots of states 3, 5, 7 and store them in `manual-smoke-test/screenshots/` for visual regression review.

(If the project later warrants automated UI testing, XCUITest is the native path — see Phase 7 future work in Notes.)

**Implementation Note**: After completing this phase, run all automated verification checks before proceeding.

---

## Phase 5: Auto-Refresh Timer + Menu Bar Percentage Badge

IMPORTANT: Execute every step in order, top to bottom.

### Overview
Add a one-minute polling timer and a small "%" badge that overlays the bolt icon in the menu bar so the user gets glanceable info without opening the popover. Stop polling when there's no sessionKey or when the app is sleeping.

### Changes Required:

#### 1. Auto-refresh in AppDelegate
**File**: `ClaudeMon/AppDelegate.swift`
**Changes**: Add a Swift `Task` that loops with `try await Task.sleep(for: .seconds(60))`, calling `usageStore.refresh()`. Cancel on `applicationWillTerminate`. Use `NSWorkspace.didWakeNotification` to fire an immediate refresh on wake. Skip the network call if `KeychainStore.sessionKey() == nil`.

```swift
private var refreshTask: Task<Void, Never>?

func applicationDidFinishLaunching(_ notification: Notification) {
    // ...existing setup...
    startAutoRefresh()
    NotificationCenter.default.addObserver(
        self, selector: #selector(didWake),
        name: NSWorkspace.didWakeNotification, object: nil
    )
}

private func startAutoRefresh() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
        guard let self else { return }
        while !Task.isCancelled {
            await self.usageStore.refresh()
            await MainActor.run { self.updateMenuBarBadge() }
            try? await Task.sleep(for: .seconds(60))
        }
    }
}

@objc private func didWake() {
    Task { await usageStore.refresh(); updateMenuBarBadge() }
}

func applicationWillTerminate(_ notification: Notification) {
    refreshTask?.cancel()
}
```

#### 2. Menu bar badge composer
**File**: `ClaudeMon/UI/MenuBarBadge.swift`

```swift
import AppKit

enum MenuBarBadge {
    static let showThreshold = 10  // don't show 0–9% to keep menu bar quiet

    static func compose(highest pct: Int?) -> NSImage {
        let bolt = NSImage(systemSymbolName: "bolt.fill",
                           accessibilityDescription: "Claude usage")!
        bolt.isTemplate = true
        guard let pct, pct >= showThreshold else { return bolt }

        // Render bolt + small "NN%" trailing text into a new template image.
        let text = "\(pct)%"
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 11),
            .foregroundColor: NSColor.black,   // template — system retints
        ]
        let textSize = (text as NSString).size(withAttributes: textAttrs)
        let totalWidth = bolt.size.width + 4 + textSize.width
        let totalHeight = max(bolt.size.height, textSize.height)

        let composed = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        composed.lockFocus()
        bolt.draw(in: NSRect(origin: .zero, size: bolt.size))
        (text as NSString).draw(
            at: NSPoint(x: bolt.size.width + 4,
                        y: (totalHeight - textSize.height) / 2),
            withAttributes: textAttrs
        )
        composed.unlockFocus()
        composed.isTemplate = true
        return composed
    }
}

extension AppDelegate {
    func updateMenuBarBadge() {
        let snap = usageStore.snapshot
        let highest = [snap?.fiveHour?.utilization, snap?.sevenDay?.utilization]
            .compactMap { $0 }.max()
        statusItem.button?.image = MenuBarBadge.compose(highest: highest)
    }
}
```

(Make `statusItem` and `usageStore` accessible to the extension — adjust visibility as needed.)

### Success Criteria:

- [ ] Bolt icon shows alone when both current-session and weekly are <10%.
- [ ] Bolt icon shows "+ 49%" (or whatever the highest is) when above threshold.
- [ ] Badge updates within 60 seconds of consuming Claude usage in another tab.
- [ ] Putting the Mac to sleep and waking → badge refreshes within 5 seconds of wake.
- [ ] Quitting the app cancels the Task (verify no debug-print leaks after termination).

**Implementation Note**: After completing this phase, run all automated verification checks before proceeding.

---

## Phase 6: Launch at Login + Code Signing + Distribution

IMPORTANT: Execute every step in order, top to bottom.

### Overview
Add the SMAppService-backed launch-at-login toggle, configure the app for code signing & notarization, build a `.dmg` for distribution. After this phase the app is shippable.

### Changes Required:

#### 1. Launch-at-login toggle
**File**: `ClaudeMon/UI/SettingsView.swift`
**Changes**: Add a `Toggle` bound to a state that reads/writes `SMAppService.mainApp`.

```swift
import ServiceManagement

// Add to SettingsView body, below the secure field:
Toggle("Launch at login", isOn: launchAtLoginBinding)
    .toggleStyle(.switch)

private var launchAtLoginBinding: Binding<Bool> {
    Binding(
        get: { SMAppService.mainApp.status == .enabled },
        set: { newValue in
            do {
                if newValue { try SMAppService.mainApp.register() }
                else        { try SMAppService.mainApp.unregister() }
            } catch {
                status = .error("Launch-at-login: \(error)")
            }
        }
    )
}
```

#### 2. Code signing & entitlements
**File**: `ClaudeMon/ClaudeMon.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

In Xcode: Target → Signing & Capabilities → Team = your Developer ID Application identity (required for notarization; Personal/Free team produces a build that won't notarize). Capability: `App Sandbox` (already covered) + `Hardened Runtime` (required for notarization).

#### 3. Notarization & DMG build script
**File**: `scripts/build-release.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

APP="ClaudeMon"
SCHEME="ClaudeMon"
BUILD_DIR=".build"
EXPORT_DIR="$BUILD_DIR/Export"
ARCHIVE="$BUILD_DIR/$APP.xcarchive"
DMG="$BUILD_DIR/$APP.dmg"

xcodebuild -project "$APP.xcodeproj" -scheme "$SCHEME" \
    -configuration Release -archivePath "$ARCHIVE" archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist scripts/ExportOptions.plist

xcrun notarytool submit "$EXPORT_DIR/$APP.app" \
    --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple "$EXPORT_DIR/$APP.app"

hdiutil create -volname "$APP" -srcfolder "$EXPORT_DIR/$APP.app" -ov -format UDZO "$DMG"
echo "Built $DMG"
```

`scripts/ExportOptions.plist` contains `<key>method</key><string>developer-id</string>` etc. (standard Apple-provided template).

The `AC_NOTARY` keychain profile is created once via `xcrun notarytool store-credentials AC_NOTARY --apple-id ... --team-id ... --password <app-specific-password>`.

#### 4. README
**File**: `README.md`
**Changes**: Document install (`open ClaudeMon.dmg`, drag to /Applications), the sessionKey extraction steps with screenshots from `manual-smoke-test/screenshots/`, build-from-source instructions, security note ("Your sessionKey is stored only in your Mac's Keychain. The app makes one HTTPS request per minute to claude.ai/api/organizations/.../usage. No data is sent anywhere else."), and a link to claude.ai/settings/usage as the source of truth.

### Success Criteria:

- [ ] `bash scripts/build-release.sh` produces `.build/ClaudeMon.dmg` with no errors.
- [ ] Mounting the DMG and dragging the app to `/Applications`, then launching, works on a clean Mac (or a fresh user account) without Gatekeeper warnings.
- [ ] Toggling "Launch at login" → log out and back in → bolt icon appears in the menu bar automatically.
- [ ] `spctl -a -vv /Applications/ClaudeMon.app` reports `accepted source=Notarized Developer ID`.
- [ ] `codesign --verify --deep --strict /Applications/ClaudeMon.app` exits 0.

**Implementation Note**: After completing this phase, run all automated verification checks before declaring the project complete.

---

## Testing Strategy

### Unit Tests (XCTest target):
- `UsageSnapshot` decodes the captured JSON fixture from Phase 3 with all fields populated to known values.
- `UsageSnapshot` decodes a partial fixture (e.g. response missing `seven_day_design` and `routine_runs`) without throwing — those fields land as `nil`.
- `UsageSnapshot` rejects a malformed fixture (missing `utilization` on `five_hour`) with a `DecodingError`.
- `Bucket.utilization` clamping in `UsageRowView` (101% → 100% bar, -3% → 0% bar).
- `MenuBarBadge.compose` returns the bare bolt for `nil` and `<10`, and a composed image for `≥10`.
- `KeychainStore.setSessionKey` followed by `KeychainStore.sessionKey()` round-trips. `KeychainStore.delete()` clears it.

### Integration Tests:
- A live integration test (skipped in CI; runs only when `CLAUDE_TEST_SESSION_KEY` env var is set on the developer's machine) that calls `ClaudeUsageClient.shared.fetchUsage()` and asserts non-nil `fiveHour.utilization`. Documented in the Xcode test plan as the only test that hits the network.

### Manual Smoke Test (in lieu of Playwright E2E):
See `manual-smoke-test.md`. Walk through the 8-step checklist from Phase 4. Native AppKit menu bar UI is not driveable by Playwright (Playwright drives browsers); there is no equivalent of `e2e:test_basic_query` for this stack. The native equivalent is XCUITest — out of scope for v1, listed in Notes as a Phase 7 follow-up. Why no auto E2E in v1: the manual checklist takes 5 minutes per release and validates real account data that XCUITest stubs would have to mock anyway.

### E2E Test Files
**Not applicable.** The existing `.claude/commands/e2e/` Playwright skills target browser-based web apps; they cannot interact with macOS menu bar UI, NSPopover, or native ProgressView elements. The `manual-smoke-test.md` file (Phase 4, step 4) is the explicit substitute.

## Performance Considerations

- **Polling cadence is 60s** (configurable down to 30s, up to 600s in `Preferences`). Below 60s risks tripping Anthropic's automated-access detection per the OpenClaw enforcement coverage; we hard-floor at 30s.
- **Memory**: a SwiftUI menu bar app with one snapshot in memory is <30 MB resident. No streaming, no caching beyond the latest snapshot.
- **CPU on idle**: the only work is one HTTPS GET per minute and one NSImage composition for the badge. Should round to 0% in Activity Monitor.
- **Battery**: the polling timer keeps the CPU mildly active. To be a good citizen, suppress the timer when the system is on battery and below 20% (read via `IOPowerSources`). Defer this micro-optimization to Phase 7.
- **Network egress** per day: ~1.4 KB/request × 1440 = ~2 MB/day. Negligible.

## Migration Notes

Not applicable — greenfield app.

## Acceptance Criteria

- [ ] App appears in menu bar with no Dock icon and no app menu.
- [ ] Clicking the icon opens a popover styled like image #2 in the user's request, content modeled on image #1.
- [ ] Current-session, weekly all-models, weekly Sonnet-only, and (when API exposes it) Claude Design / routine runs / extra usage rows render with progress bars and reset times.
- [ ] Numbers shown match `https://claude.ai/settings/usage` ±1% / ±1 minute, validated manually.
- [ ] Menu bar icon shows a numeric % overlay when the highest tracked bucket is ≥10%.
- [ ] Polling runs every 60s, stops cleanly on quit, resumes on wake.
- [ ] sessionKey is stored only in Keychain (`security find-generic-password -s com.alejtr.ClaudeMon` confirms presence; nothing in `~/Library/Application Support/ClaudeMon/` or similar).
- [ ] App is signed (Developer ID) and notarized; `spctl -a -vv` says "Notarized Developer ID".
- [ ] Launch-at-login toggle works across reboots.
- [ ] All validation commands pass with zero errors.

## Validation Commands

Execute every command to validate the feature works correctly with zero regressions.

- `xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon -configuration Debug clean build` — build with zero errors and zero warnings.
- `xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon test` — run XCTest unit tests with zero failures.
- `swift package resolve` is N/A (no SPM). `xcodebuild -resolvePackageDependencies` if any SPM packages get added later.
- `bash scripts/build-release.sh` — release build, sign, notarize, DMG with zero errors.
- `spctl -a -vv .build/Export/ClaudeMon.app` — notarization passes.
- `codesign --verify --deep --strict .build/Export/ClaudeMon.app` — signing passes.
- Manual: walk through every step in `manual-smoke-test.md` — all 8 steps pass; screenshots match prior release. (Replaces Playwright E2E, which does not apply to native menu bar apps.)
- Manual: open the app, paste a real sessionKey, compare to claude.ai/settings/usage — values within ±1%.

## References

- Closest prior art (do not copy, model after for shape): https://github.com/hamed-elfayome/Claude-Usage-Tracker
- Architectural template: https://github.com/AnaghSharma/Ambar-SwiftUI
- Canonical menu-bar guide (2024+): https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- NSStatusItem advanced patterns: https://multi.app/blog/pushing-the-limits-nsstatusitem
- Keychain SecItem reference: https://swiftsenpai.com/development/persist-data-using-keychain/
- SMAppService docs: https://developer.apple.com/documentation/servicemanagement/smappservice
- MenuBarExtra unresolved bugs (rationale for not using it): FB11984872 (https://github.com/feedback-assistant/reports/issues/383), FB13683950 (https://github.com/feedback-assistant/reports/issues/475)
- Endpoint corroboration: https://github.com/sshnox/Claude-Usage-Tracker (response shape), https://github.com/alexesprit/claude-usage-widget (Go reference)
- Anti-bot context (OpenClaw): https://venturebeat.com/technology/anthropic-cracks-down-on-unauthorized-claude-usage-by-third-party-harnesses
- Anthropic GitHub issue requesting a public usage endpoint: https://github.com/anthropics/claude-code/issues/19880

## Notes

**Schema risk.** The single biggest risk is that the fields in image #1 ("Claude Design", "Daily included routine runs", "Extra usage" with dollars/limit/balance/auto-reload) are not on the `/api/organizations/{uuid}/usage` payload at all and live on a different endpoint. Phase 3 step 1 (the DevTools capture) is mandatory. If the capture reveals a separate billing endpoint, the only change is to add a second URL to `ClaudeUsageClient` and a second `await get(billingURL, ...)` call inside `fetchUsage()`. The Codable model and the UI are already structured to accept missing fields gracefully (`?` everywhere on the snapshot).

**Cookie expiry.** `sessionKey` does not expire on a fixed schedule but Anthropic can revoke it. The 401-handling in `ClaudeUsageClient` surfaces "Session expired — paste a new sessionKey" to the user; that's enough for v1. A nicer Phase 7 follow-up: detect 401, slide in a notification banner ("Your session expired") with a one-click button to open Settings.

**Phase 7 follow-ups (not in scope of this plan):**
- Embedded WebView login that auto-extracts the cookie (kills the manual paste — biggest UX win).
- Historical chart (last 7 days of utilization snapshots stored in CoreData/SQLite).
- XCUITest-driven UI smoke tests, replacing the manual checklist.
- macOS notification when current-session crosses 80% / 90% / 100%.
- Battery-aware polling backoff.
- Multi-org / multi-account support.
- OAuth fallback path that reads `~/.claude/.credentials.json` (Claude Code creds) when present, so users with Claude Code installed don't need to paste a cookie at all.

**No new third-party libraries are required for v1.** Pure first-party Swift / AppKit / Foundation / Security / ServiceManagement. This keeps notarization and supply-chain review trivial.

**Why we're not using `MenuBarExtra` even though it's shorter.** MenuBarExtra has open SwiftUI bugs (no programmatic close, no rerender-on-open, broken `openSettings` on macOS 26) and the most popular workaround library `FluidMenuBarExtra` was archived January 2026. NSStatusItem + NSPopover is ~30 extra lines of AppDelegate and gives us full programmatic control over the popover lifecycle, which we need for "swap to Settings on click, swap back on save" and the dynamic-sized error banner. This is documented in the Implementation Approach section above; pasting it again here so a future reader doesn't second-guess the choice.

**Why the user pastes a cookie instead of OAuth.** The user said "take the token from the web session for Claude," explicitly the web cookie path. OAuth via Claude Code creds (Lcharvol/Claude-God's approach) is a strictly nicer UX but is a different feature; we can add it as a Phase 7 path so users who have both can choose either.
