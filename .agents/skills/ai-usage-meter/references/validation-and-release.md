# Validation and Release

## Validation Ladder

Choose the smallest useful check while iterating, but run the repository test gate before claiming a code change is ready.

### Repository test gate

Run from the repository root:

```bash
xcodebuild test \
  -project AIUsageMeter.xcodeproj \
  -scheme AIUsageMeter \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AIUsageMeter-DerivedData
```

Use a task-specific temporary Derived Data directory if parallel work might collide. Do not write new generated build output into the repository.
The XCTest host disables `QuotaController` startup effects; a normal unit-test run must not read user credentials or call live Cursor/Codex services.
The shared scheme uses the `Testing` configuration for its Test action and `Release` for Run, Profile, Analyze, and Archive. `Testing` enables `@testable` imports without shipping a Debug configuration or Debug-only preview behavior.

### Focused evidence

- Parser or mapping change: add or update deterministic unit cases for missing fields, unexpected types, unknown plan values, boundary percentages, and timestamp conversion.
- Process or cancellation change: prove timeout and cancellation terminate the child process and do not hang on pipes.
- Cache-policy change: test current, cached, disconnected, and refresh-failure state transitions.
- UI-only change: compilation and tests prove static correctness. Visual layout, menu-bar interaction, VoiceOver, and real appearance modes remain unverified unless the user authorizes launching the app.
- Credential or service change: do not use the user's real tokens or logged-in sessions unless explicitly authorized.

## Release Workflow

### GitHub release automation

Prepare each version in a PR by aligning `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and the matching `CHANGELOG.md` entry. After it merges to `main`, run `./scripts/release.sh vX.Y.Z` from a clean checkout whose `HEAD` exactly matches `origin/main`.

The command dispatches `.github/workflows/release.yml`. The workflow accepts stable `vX.Y.Z` tags only; it verifies the project version and Changelog entry, runs the repository test gate, builds the Universal ZIP, DMG, and checksums, then creates an annotated tag and public GitHub Release. Release notes are extracted from the matching Changelog section and receive a generated installation note. The repository must allow the Actions `GITHUB_TOKEN` to use `contents: write`; do not add certificates or authentication material to the repository for this workflow.

The workflow is intentionally not a signing or notarization migration. It continues to create the existing ad-hoc-signed archive.
The release job runs on `macos-26`, selects Xcode 26.6 explicitly, and fails if the macOS SDK is not 26.5. Keep the local development Xcode on the same 26.6 toolchain when visual or packaged-output parity matters.

Run `./scripts/build-release.sh` only when packaging or release verification is in scope. The script currently:

1. Builds a Release app for `arm64` and `x86_64`.
2. Verifies version, build number, bundle identifier, and architectures.
3. Applies an ad-hoc hardened-runtime signature.
4. Creates a versioned ZIP and a fixed-name `AI Usage Meter.dmg`, each with a SHA-256 checksum. The DMG includes an `Applications` shortcut for drag-and-drop installation.
5. Extracts both archives and verifies the packaged application again.

The script writes release artifacts under `dist/` and replaces the version-matching ZIP plus the fixed-name DMG and their checksums. Treat that as a material artifact change and do not run it merely as a generic compile check.

## Distribution Constraints

- Source code is MIT-licensed. Release artifacts are currently ad-hoc signed, without Developer ID notarization.
- Preserve bundle identifier `com.aisen.aiusagemeter` unless an explicit migration covers Keychain and login-item consequences.
- Preserve universal architecture support while the release script promises `arm64 + x86_64`.
- Treat `CHANGELOG.md` as the single checked-in version history. Keep its current entry, README requirements, GitHub Release text, and the script's version metadata aligned when preparing a release; do not add per-version release-note files unless automation requires one.
- Do not claim Gatekeeper, login-item, Keychain persistence, or live-service compatibility from unit tests alone.

## Common Validation Noise

- Xcode may emit local cache or file-event warnings that are unrelated to compilation or test correctness. Evaluate the final test result and actual diagnostics rather than treating every environment warning as a code failure.
- Private Cursor and Codex integrations can fail because the installed client or protocol changed. Separate those compatibility failures from UI or cache-policy regressions.
