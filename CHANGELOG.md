# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- LICENSE (MIT) at the repo root.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- `CHANGELOG.md` (this file).
- `.github/` issue templates and PR template.
- `.github/workflows/ci.yml` running `xcodebuild test` on every PR.
- `.github/workflows/release.yml` building a DMG on `v*` tags
  (notarized when maintainer secrets are present, unsigned otherwise).
- `docs/ARCHITECTURE.md` describing the polling cycle and auth flow.
- README disclaimer banner clarifying the project's experimental,
  unaffiliated status.
- README badges (CI, license, latest release, macOS version).

### Changed
- Bundle ID prefix updated to `app.claudemon` (neutral, no personal owner).
  **Existing users will need to sign in again** — the Keychain entry under
  the old service name is orphaned.
- `manual-smoke-test.md` moved to `docs/manual-smoke-test.md` and clarified
  as a maintainer-only release checklist.
- `.gitignore` annotated to explain why `ClaudeMon.xcodeproj/` and `specs/`
  are excluded.
- `scripts/build-release.sh` documented as maintainer-only (requires Apple
  Developer ID + `AC_NOTARY` keychain profile).

## [0.1.0] - Unreleased

Initial scaffold (see git history `25450a7..cc1f9fa`).

### Added
- Native macOS menu bar app with `bolt` icon and Docker-Desktop-style
  popover (`AppDelegate`, `ClaudeMonApp`, `MenuBarBadge`, `UsagePanelView`,
  `UsageRowView`, `SettingsView`).
- `UsageStore` 60s polling timer (clamped 30–600s) with
  `NSWorkspace.didWakeNotification` triggered refresh.
- `ClaudeUsageClient` reading
  `GET /api/organizations` and `GET /api/organizations/{uuid}/usage`.
- `KeychainStore` persisting the `sessionKey` cookie with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- In-app WKWebView sign-in flow (`SignInWindowController`, `CookieExtractor`)
  capturing the cookie automatically after login.
- Manual cookie-paste fallback in `SettingsView`.
- App Sandbox + Hardened Runtime, network client only.
- `xcodegen` project generation from `project.yml`.
- README with local run guide and DMG build instructions.

### Known limitations
- "Daily routine runs", "Claude Design weekly", and "Extra usage" buckets
  are unverified placeholders pending schema verification.

[Unreleased]: https://github.com/OWNER/REPO/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OWNER/REPO/releases/tag/v0.1.0
