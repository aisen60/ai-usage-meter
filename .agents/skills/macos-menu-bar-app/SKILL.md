---
name: macos-menu-bar-app
description: Native macOS menu bar application architecture and safety guidance. Use when implementing or reviewing MenuBarExtra or NSStatusItem interfaces, SwiftUI-AppKit bridging, app lifecycle, background refresh, Process integration, Keychain, login items, sandbox and entitlements, accessibility, signing, notarization, updates, or distribution behavior.
---

# macOS Menu Bar App

Use the project's deployment target, Swift language mode, entitlements, and existing architecture as the source of truth. Modernize deliberately; never assume an iOS recommendation or the newest toolchain feature is available to the target application.

## Workflow

1. Inspect the deployment target, Swift language mode, app entrypoint, entitlements, and distribution method.
2. Identify whether the task belongs to UI/lifecycle or security/distribution.
3. Read the matching reference file.
4. Load `swiftui-pro` for SwiftUI implementation and `swift-concurrency-pro` for task, actor, process, or cancellation behavior.
5. Preserve native macOS behavior across menu-bar closed/open states, app termination, sleep/wake, login, and permission failure as relevant.
6. Validate with tests and builds first. Launch or automate the GUI only with user authorization.

## Core Rules

- Prefer `MenuBarExtra` when its scene lifecycle and presentation styles satisfy the product. Use `NSStatusItem` only when lower-level event handling or OS compatibility genuinely requires it.
- Choose `.menu` for conventional menu commands and `.window` for custom SwiftUI layouts. Do not switch styles as a cosmetic refactor; it changes interaction semantics.
- Keep `AppDelegate` narrowly scoped to lifecycle APIs that SwiftUI scenes cannot express cleanly.
- Keep external effects in services or controllers rather than SwiftUI view bodies.
- Make background refresh cancellable, idempotent, and truthful about stale data.
- Use Keychain for credentials. Use `UserDefaults` or files only for non-secret preferences and cache data.
- Avoid recording private identifiers or authentication material in Unified Logging.
- Treat sandbox, entitlements, login items, signing, notarization, auto-update, and distribution as one connected system. A change to one can invalidate the others.
- Prefer Apple frameworks before third-party packages. Ask before adding update, keychain, networking, or architecture frameworks.
- Preserve accessibility for icon-only controls, compact text, color-coded state, keyboard access, VoiceOver, Reduce Motion, contrast, and appearance modes.

## Reference Routing

- Read `references/lifecycle-and-ui.md` for scene choice, popover/window behavior, state ownership, refresh lifecycle, AppKit bridging, and accessibility.
- Read `references/security-and-distribution.md` for Keychain, local client data, logs, sandbox, entitlements, login items, signing, notarization, updates, and release proof.

## Review Standard

Report only behaviorally meaningful issues. Do not demand a fashionable architecture, a Swift-language migration, Observation adoption, or replacement of working AppKit code without showing a concrete correctness, maintainability, accessibility, privacy, or compatibility benefit.
