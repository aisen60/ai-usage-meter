# Agents

This is **AI Usage Meter**, a native macOS menu bar app for viewing Cursor and Codex quota state.

- For repository structure, ownership, integration behavior, commands, and release caveats, load the `ai-usage-meter` skill.
- For SwiftUI view, state-flow, accessibility, API-modernization, or performance work, also load `swiftui-pro`.
- For `Task`, actor isolation, cancellation, `Process`, pipes, locks, or async test work, also load `swift-concurrency-pro`.
- For `MenuBarExtra`, AppKit bridging, application lifecycle, Keychain, login items, privacy, signing, or distribution work, also load `macos-menu-bar-app`.
- Load `swift-testing-pro` only when writing Swift Testing tests or when the user explicitly requests an XCTest migration. Preserve the existing XCTest suite otherwise.
- For staging changes, drafting commit messages, or creating commits, load `git-commit`. Keep the Conventional Commit type token when useful, and default all human-readable commit subject and body text to Simplified Chinese unless the user explicitly requests another language for that commit.
- Load `planning-gate` only when the user explicitly asks for detailed planning, brainstorming, a complete plan, or the planning gate workflow. Do not activate it automatically from task complexity alone.
- Treat the checked-in Xcode project as authoritative. The current product baseline is macOS 13 and Swift 5 language mode; do not raise the deployment target, change Swift language mode, or enable broad concurrency migrations unless the task requires and validates that change.
- Preserve the product's data semantics: Cursor may display cached data after refresh failure, while Codex must become disconnected rather than presenting stale quota as current.
- Never log, persist outside Keychain, expose, or include in fixtures any token, cookie, account identifier, authentication payload, or complete private API response.
- Do not add a third-party dependency for behavior available through Swift, SwiftUI, AppKit, Security, ServiceManagement, Foundation, or a focused local helper unless the dependency clearly reduces material risk and the user approves it.
- Before claiming a code change is ready, run the narrowest relevant tests and then the repository test gate from the root: `xcodebuild test -project AIUsageMeter.xcodeproj -scheme AIUsageMeter -destination 'platform=macOS' -derivedDataPath /private/tmp/AIUsageMeter-DerivedData`.
- Building code does not authorize launching the app, controlling macOS UI, reading user credentials, or calling live private service endpoints. Perform those checks only when the user explicitly requests them, and state any remaining runtime boundary.
- Keep this file short. Put durable repository details in `.agents/skills/ai-usage-meter/references/` and reusable macOS guidance in `.agents/skills/macos-menu-bar-app/references/`.
- When a change alters a durable workflow, integration invariant, validation command, release rule, or ownership boundary, update the matching skill reference in the same task.
