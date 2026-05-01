# Security Policy

## Threat model

ClaudeMon handles a `sessionKey` cookie that grants read access to your
claude.ai account. The app's posture:

- **At rest:** the cookie is written to the macOS Keychain under service
  `app.claudemon.ClaudeMon`, account `claude-ai-session-key`, with
  accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (won't
  sync to iCloud, won't roam to other devices).
- **In transit:** HTTPS-only, exclusively to `claude.ai`. The app sandbox
  declares `com.apple.security.network.client` and nothing else.
- **No telemetry:** no analytics, no crash reporting, no third-party SDKs.

## What we consider a security issue

- Anything that exfiltrates the session cookie or other Keychain data.
- Weakening of the Keychain accessibility attribute.
- Network calls to hosts other than `claude.ai`.
- App-sandbox capabilities added without justification.
- Code paths that log the cookie value.

## Not a security issue

- The upstream API breaking when Anthropic changes the schema (open a regular
  issue with the captured response payload, sanitized of identifiers).
- Failure to detect that an Anthropic-side rate limit has been applied.

## How to report

Please **do not** open a public GitHub issue for security problems. Open a
private report via the repo's
[GitHub Security Advisories](https://github.com/gltorres/macos-claude-code-monitoring/security/advisories/new)
tab.

Include reproduction steps, the version (`MARKETING_VERSION` from the built
app's Info.plist or the git SHA you built from), and macOS version.

## What to expect

- Acknowledgment within **7 days**.
- Triage and a fix or mitigation plan within **30 days** for confirmed issues.
- Coordinated disclosure: we'll agree on a public-disclosure date with you.

## Scope

In scope: the source code in this repository and the official DMG releases.
Out of scope: anything Anthropic-operated, third-party forks, or builds you
modified locally.
