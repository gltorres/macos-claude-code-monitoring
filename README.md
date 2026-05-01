# ClaudeMon

A native macOS menu bar app that displays the same usage data shown at
[claude.ai/settings/usage](https://claude.ai/settings/usage) — current 5-hour
session, weekly all-models, weekly Sonnet-only, Claude Design, daily routine
runs, and extra-usage spend — driven by your `sessionKey` cookie.

The app lives next to your system clock, shows a small `bolt` icon with an
optional `NN%` overlay when the highest tracked bucket is `>= 10%`, and opens
a Docker-Desktop-style popover with progress bars on click.

## Install (build from source)

Requirements:

- macOS 14.0+
- Xcode 15+ (or 16, 26)
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```bash
xcodegen generate
open ClaudeMon.xcodeproj
# In Xcode: select the ClaudeMon scheme and press Cmd-R
```

Or to build a Debug binary without opening Xcode:

```bash
xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon \
    -configuration Debug build \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

For a notarized release DMG see `scripts/build-release.sh` (requires an Apple
Developer ID and an `AC_NOTARY` keychain profile created via `xcrun notarytool
store-credentials`).

## How to find your `sessionKey`

1. Sign in to [claude.ai](https://claude.ai) in Chrome or Safari.
2. Open DevTools (`Option-Cmd-I`).
3. Application tab → Storage → Cookies → `https://claude.ai`.
4. Find the row named `sessionKey`, double-click its **Value**, copy it.
5. In ClaudeMon, click the menu bar bolt → paste into the Settings field →
   click **Save**. The value starts with `sk-ant-sid01-`.

## Schema verification (must do before relying on the values)

The fields the app reads from `GET /api/organizations/{uuid}/usage` are
*placeholders* until verified against the real response. The five-hour and
seven-day buckets are corroborated by multiple open-source projects, but the
"Claude Design" weekly bucket, "Daily routine runs", and "Extra usage" object
are not publicly documented. To verify:

1. Open Chrome DevTools → Network tab → filter Fetch/XHR → check **Preserve
   log**.
2. Visit `https://claude.ai/settings/usage`.
3. For every request whose path starts with `/api/`, copy the URL and the
   response body to a scratch file.
4. Map the captured field names to the placeholders in
   `ClaudeMon/Models/UsageSnapshot.swift` (search for `TODO` comments) and
   adjust the `CodingKeys` enum.

The Codable model uses optionals everywhere, so unknown fields silently
degrade to "—" rather than crashing the app.

## Privacy & security

- Your `sessionKey` is stored only in the macOS Keychain
  (`com.alejtr.ClaudeMon` / `claude-ai-session-key`, accessibility
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- The app makes one HTTPS GET per minute to `claude.ai/api/organizations` and
  `claude.ai/api/organizations/{uuid}/usage`. No data is sent anywhere else.
- Sandboxed with App Sandbox + `com.apple.security.network.client` only.
- Verify presence with `security find-generic-password -s com.alejtr.ClaudeMon`.

## Polling cadence

The app polls every 60 seconds by default (configurable via the
`refreshIntervalSeconds` `UserDefaults` key, hard-floored at 30s and capped at
600s). The lower bound is intentional: claude.ai enforces against automated
access, and a 60s cadence is well within the read-only safe range used by
similar open-source projects.

## Manual smoke test

Before each release, walk through `manual-smoke-test.md`. Native AppKit
popovers cannot be exercised by Playwright; XCUITest is a follow-up.

## License

MIT.
