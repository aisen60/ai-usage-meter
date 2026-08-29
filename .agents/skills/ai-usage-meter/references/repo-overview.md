# Repository Overview

## Product Baseline

- Native macOS menu bar application.
- Deployment target: macOS 13 Ventura.
- Xcode project: `AIUsageMeter.xcodeproj`.
- Main scheme: `AIUsageMeter`.
- Checked-in Swift language mode: Swift 5.
- No third-party runtime dependencies.
- The app has no normal Dock-window workflow; its primary interface is `MenuBarExtra` with `.window` style.

## Ownership Map

| Area | Owning path | Responsibility |
| --- | --- | --- |
| App entry and lifecycle | `AIUsageMeter/AIUsageMeterApp.swift` | `App`, `MenuBarExtra`, AppKit lifecycle bridge, login-item startup |
| Cross-service state | `AIUsageMeter/Controllers/QuotaController.swift` | Refresh orchestration, connection states, cache policy, automatic refresh |
| Menu bar UI | `AIUsageMeter/Views/` | Status-bar label, service sections, cards, toolbar, presentation-only formatting |
| Cursor domain model | `AIUsageMeter/Models/CursorUsage.swift` | Cursor parsing and computed usage values |
| Codex domain model | `AIUsageMeter/Models/CodexUsage.swift` | Codex quota state and display data |
| Cursor integration | `AIUsageMeter/Services/CursorAPIClient.swift`, `CursorTokenReader.swift` | Local session discovery, private dashboard requests, plan detection |
| Codex integration | `AIUsageMeter/Services/CodexIntegration.swift` | Locate Codex executable, run `app-server`, request and parse rate limits, terminate child process |
| Credential storage | `AIUsageMeter/Services/TokenKeychain.swift` | Manual Cursor token persistence in Keychain |
| Cache and diagnostics | `AIUsageMeter/Services/UsageCache.swift`, `AppLog.swift` | Non-secret cached usage and privacy-safe logging |
| Login item | `AIUsageMeter/Services/LaunchAtLoginService.swift` | Release-only registration through ServiceManagement |
| Unit tests | `AIUsageMeterTests/` | Parser, mapping, display settings, persistence constraints, failure, and child-process cleanup behavior |
| Packaging | `scripts/build-release.sh` | Universal build, metadata checks, ad-hoc signing, archive and checksum verification |

## Dependency Direction

Keep the dependency flow simple:

`App / Views -> QuotaController -> Services -> Models / system APIs`

- Views render state and emit user intent; they do not read databases, Keychain, environment variables, or service responses.
- `QuotaController` owns UI-facing coordination on the main actor.
- Services own external effects and return domain values or typed errors.
- Models own parsing and derived values when the logic is deterministic and reusable.

Do not force a broad MVVM or repository-layer rewrite. Add a new abstraction only when it creates a real test seam, isolates an unstable integration, or removes duplicated policy.

## Current UI Contract

- The status item shows configurable Cursor Models, Other Models, and Codex weekly-remaining capsules, with at least one value always visible.
- When Cursor has no current or explicitly stale usage to display, its popover section, status-item capsules, and settings rows are hidden without changing the user's saved display preferences.
- Disconnected service values fall back to a neutral gray `0%` presentation.
- Cursor cache remains displayable in an explicit stale state; Codex never presents stale quota as current.
- `.menuBarExtraStyle(.window)` is intentional because `.menu` reinterprets custom SwiftUI content as menu items and breaks the card layout.
- Settings, refresh status, and quit controls live in the segmented bottom toolbar.
- Preserve compact sizing and avoid window-oriented navigation patterns unless the product direction changes.
