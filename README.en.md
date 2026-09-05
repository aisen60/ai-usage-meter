# AI Usage Meter

[简体中文](README.md)

AI Usage Meter is a local-first macOS menu bar app for monitoring Cursor and ChatGPT usage.

Keep your most important AI quota numbers visible without opening either app. AI Usage Meter reads supported usage data locally and presents it in a compact menu bar panel.

## Features

- Monitor Cursor Models, Other Models, and On Demand usage.
- Track ChatGPT 5-hour and 1-week remaining quota windows.
- Choose which usage items appear in the menu bar.
- Switch the interface between English and Simplified Chinese.
- Launch automatically when you log in.
- Check GitHub Releases and install archives with SHA-256 verification.
- Keep Cursor and ChatGPT integrations independent.
- Store credentials in macOS Keychain and usage data locally.

## Download

Download the latest release from [GitHub Releases](https://github.com/aisen60/ai-usage-meter/releases). AI Usage Meter requires macOS 13 Ventura or later. Install Cursor to view Cursor usage, and install ChatGPT for macOS or Codex CLI to view ChatGPT quota. Either integration can be used on its own.

On macOS, download the ZIP, extract it, and move `AI Usage Meter.app` to `/Applications`. If macOS shows a security warning on first launch, Control-click the app, choose **Open**, and confirm once in **System Settings → Privacy & Security**.

Release archives currently use an ad-hoc signature and are not Developer ID signed or notarized. A first-launch security warning is therefore expected.

## Privacy

AI Usage Meter does not send tokens, cookies, account identifiers, or usage responses to the developer. Cursor and ChatGPT usage is read locally, and update checks request only public repository metadata from GitHub.

See [PRIVACY.md](PRIVACY.md) for data sources, local storage, network requests, and removal instructions. Chinese readers can use [PRIVACY.zh-CN.md](PRIVACY.zh-CN.md).

## Development

The current source targets macOS 13 and uses SwiftUI with no third-party runtime dependencies. Open the project in Xcode:

```bash
open AIUsageMeter.xcodeproj
```

Run the test suite:

```bash
xcodebuild test \
  -project AIUsageMeter.xcodeproj \
  -scheme AIUsageMeter \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/AIUsageMeter-DerivedData
```

Build a Universal release archive with:

```bash
./scripts/build-release.sh
```

The script produces an `arm64 + x86_64` ZIP and its SHA-256 checksum in `dist/`.

## Releases

Prepare a release in a PR by updating Xcode's `MARKETING_VERSION`, build number, and `CHANGELOG.md`. After it has merged to `main`, run this from a clean, synchronized `main` checkout:

```bash
./scripts/release.sh v0.3.2
```

The command manually dispatches GitHub Actions. The workflow validates the version and changelog, runs the full test suite, builds the Universal ZIP and SHA-256 checksum, then creates the matching Git tag and public GitHub Release after every check succeeds. The release body is extracted from the matching `CHANGELOG.md` entry and receives an installation note automatically.

The repository must permit the GitHub Actions `GITHUB_TOKEN` to use `contents: write` so the workflow can create tags and Releases. No certificate or other secret is stored in the repository. This automation still uses ad-hoc signing; Developer ID signing and Apple notarization are not included.

## About

- [Releases](https://github.com/aisen60/ai-usage-meter/releases)
- [Changelog](CHANGELOG.md)
- [Issues](https://github.com/aisen60/ai-usage-meter/issues)
- [MIT License](LICENSE)

MIT © 2026 aisen60
