# Validation and Release

## Validation Ladder

Choose the smallest useful check while iterating, but run the repository test gate before claiming a code change is ready.

### Repository test gate

Run from the repository root:

```bash
xcodebuild test \
  -project AgentQuotaBar.xcodeproj \
  -scheme AgentQuotaBar \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AgentQuotaBar-DerivedData
```

Use a task-specific temporary Derived Data directory if parallel work might collide. Do not write new generated build output into the repository.
The XCTest host disables `QuotaController` startup effects; a normal unit-test run must not read user credentials or call live Cursor/Codex services.

### Focused evidence

- Parser or mapping change: add or update deterministic unit cases for missing fields, unexpected types, unknown plan values, boundary percentages, and timestamp conversion.
- Process or cancellation change: prove timeout and cancellation terminate the child process and do not hang on pipes.
- Cache-policy change: test current, cached, disconnected, and refresh-failure state transitions.
- UI-only change: compilation and tests prove static correctness. Visual layout, menu-bar interaction, VoiceOver, and real appearance modes remain unverified unless the user authorizes launching the app.
- Credential or service change: do not use the user's real tokens or logged-in sessions unless explicitly authorized.

## Release Workflow

Run `./scripts/build-release.sh` only when packaging or release verification is in scope. The script currently:

1. Builds a Release app for `arm64` and `x86_64`.
2. Verifies version, build number, bundle identifier, and architectures.
3. Applies an ad-hoc hardened-runtime signature.
4. Creates a ZIP and SHA-256 checksum.
5. Extracts the archive and verifies the packaged application again.

The script writes release artifacts under `dist/` and replaces the version-matching ZIP and checksum. Treat that as a material artifact change and do not run it merely as a generic compile check.

## Distribution Constraints

- Source code is MIT-licensed. Release artifacts are currently ad-hoc signed, without Developer ID notarization.
- Preserve bundle identifier `com.agentquotabar.app` unless an explicit migration covers Keychain and login-item consequences.
- Preserve universal architecture support while the release script promises `arm64 + x86_64`.
- Treat `CHANGELOG.md` as the single checked-in version history. Keep its current entry, README requirements, GitHub Release text, and the script's version metadata aligned when preparing a release; do not add per-version release-note files unless automation requires one.
- Do not claim Gatekeeper, login-item, Keychain persistence, or live-service compatibility from unit tests alone.

## Common Validation Noise

- Xcode may emit local cache or file-event warnings that are unrelated to compilation or test correctness. Evaluate the final test result and actual diagnostics rather than treating every environment warning as a code failure.
- Private Cursor and Codex integrations can fail because the installed client or protocol changed. Separate those compatibility failures from UI or cache-policy regressions.
