# Repository Overview

## Product Baseline

- Native macOS menu bar application.
- Deployment target: macOS 13 Ventura.
- Xcode project: `AgentQuotaBar.xcodeproj`.
- Main scheme: `AgentQuotaBar`.
- Checked-in Swift language mode: Swift 5.
- No third-party runtime dependencies.
- The app has no normal Dock-window workflow; its primary interface is `MenuBarExtra` with `.window` style.

## Ownership Map

| Area | Owning path | Responsibility |
| --- | --- | --- |
| App entry and lifecycle | `AgentQuotaBar/AgentQuotaBarApp.swift` | `App`, `MenuBarExtra`, AppKit lifecycle bridge, login-item startup |
| Cross-service state | `AgentQuotaBar/Controllers/QuotaController.swift` | Refresh orchestration, connection states, cache policy, automatic refresh |
| Menu bar UI | `AgentQuotaBar/Views/` | Status-bar label, service sections, cards, toolbar, presentation-only formatting |
| Cursor domain model | `AgentQuotaBar/Models/CursorUsage.swift` | Cursor parsing and computed usage values |
| Codex domain model | `AgentQuotaBar/Models/CodexUsage.swift` | Codex quota state and display data |
| Cursor integration | `AgentQuotaBar/Services/CursorAPIClient.swift`, `CursorTokenReader.swift` | Local session discovery, private dashboard requests, plan detection |
| Codex integration | `AgentQuotaBar/Services/CodexIntegration.swift` | Locate Codex executable, run `app-server`, request and parse rate limits, terminate child process |
| Credential storage | `AgentQuotaBar/Services/TokenKeychain.swift` | Manual Cursor token persistence in Keychain |
| Cache and diagnostics | `AgentQuotaBar/Services/UsageCache.swift`, `AppLog.swift` | Non-secret cached usage and privacy-safe logging |
| Login item | `AgentQuotaBar/Services/LaunchAtLoginService.swift` | Release-only registration through ServiceManagement |
| Unit tests | `AgentQuotaBarTests/QuotaParsingTests.swift` | Parser, mapping, clamping, failure, and child-process cleanup behavior |
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

- The status item shows a blue Cursor capsule and a green Codex capsule when connected.
- Disconnected service values fall back to a neutral gray `0%` presentation.
- `.menuBarExtraStyle(.window)` is intentional because `.menu` reinterprets custom SwiftUI content as menu items and breaks the card layout.
- Refresh and quit controls live in the bottom toolbar.
- Preserve compact sizing and avoid window-oriented navigation patterns unless the product direction changes.
