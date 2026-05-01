# Contributing to ClaudeMon

Thanks for your interest. This is a small project; PRs that fix bugs, verify
the unverified API schema, or improve the menu-bar UX are especially welcome.

## Dev setup

1. macOS 14+ and Xcode 15+ with Command Line Tools.
2. `brew install xcodegen`.
3. `git clone` the repo, then `xcodegen generate` to produce `ClaudeMon.xcodeproj`.
4. `open ClaudeMon.xcodeproj` and `Cmd-R`, or run from the CLI per
   [README "Run from the command line"](README.md#3b-run-from-the-command-line-no-xcode-ui).

Re-run `xcodegen generate` any time `project.yml` changes.

## Tests

```bash
xcodebuild -project ClaudeMon.xcodeproj -scheme ClaudeMon \
    -destination 'platform=macOS' test
```

CI runs the same command on every PR.

## Bundle ID for forks

The project ships with bundle ID `app.claudemon.ClaudeMon`. If you sign
your fork under your own Apple ID, swap the prefix in `project.yml`,
`ClaudeMon/Auth/KeychainStore.swift`, and the two `Logger(subsystem:)` calls
in `ClaudeMon/Auth/CookieExtractor.swift` and
`ClaudeMon/UI/SignInWindowController.swift`. Use one find-replace
(`app.claudemon` → your prefix) and you're done.

## PR checklist

- Tests pass (`xcodebuild ... test`).
- For UI-touching changes, the maintainer-only smoke test at
  [`docs/manual-smoke-test.md`](docs/manual-smoke-test.md) still passes.
- New entries added under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md).
- No real `sessionKey`, account UUID, or email committed in fixtures.
- Branch name uses one of `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`.

## Code of conduct

Participation in this project is governed by
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Security issues

Don't open public issues for security problems — see [SECURITY.md](SECURITY.md).
