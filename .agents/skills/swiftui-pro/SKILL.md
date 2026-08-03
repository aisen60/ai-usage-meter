---
name: swiftui-pro
description: Writes and reviews SwiftUI code for correct data flow, platform-appropriate APIs, maintainability, accessibility, and performance. Use when reading, implementing, refactoring, or reviewing SwiftUI views and observable state on Apple platforms, including macOS menu bar applications.
---

Review Swift and SwiftUI code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems - do not nitpick or invent issues.

Review process:

1. Inspect the project's platform, deployment target, Swift language mode, and existing conventions before recommending API or architecture changes.
1. Check for deprecated or unavailable API using `references/api.md`.
1. Check that views, modifiers, and animations have been written optimally using `references/views.md`.
1. Validate that data flow is configured correctly using `references/data.md`.
1. Ensure navigation is updated and performant using `references/navigation.md`.
1. Ensure the code uses designs that are accessible and compliant with Apple’s Human Interface Guidelines using `references/design.md`.
1. Validate accessibility compliance including Dynamic Type, VoiceOver, and Reduce Motion using `references/accessibility.md`.
1. Ensure the code is able to run efficiently using `references/performance.md`.
1. Quick validation of Swift code using `references/swift.md`.
1. Final code hygiene check using `references/hygiene.md`.

If doing a partial review, load only the relevant reference files.


## Core Instructions

- Treat the checked-in deployment target and Swift language mode as authoritative. Do not raise them or begin a Swift 6 migration unless that work is explicitly in scope.
- Check API availability against the actual target. A newer installed SDK does not make a new API safe for an older deployment target.
- Prefer SwiftUI for shared UI and use the platform framework that owns necessary behavior: AppKit on macOS and UIKit on iOS.
- Do not introduce third-party frameworks without asking first.
- Separate independent public types into focused files. Keep tightly coupled private helper types near their owner when that improves locality.
- Follow the project's existing feature and layer boundaries before proposing a broad restructure.
- Do not require Observation adoption merely because it is newer. Consider deployment availability, Swift language mode, existing bindings, and migration scope.
- When implementing rather than reviewing, apply these rules directly and summarize meaningful decisions; do not emit a review report unless requested.


## Output Format

Organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated (e.g., "Use `foregroundStyle()` instead of `foregroundColor()`").
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.

Example output:

### ContentView.swift

**Line 12: Use `foregroundStyle()` instead of `foregroundColor()`.**

```swift
// Before
Text("Hello").foregroundColor(.red)

// After
Text("Hello").foregroundStyle(.red)
```

**Line 24: Icon-only button is bad for VoiceOver - add a text label.**

```swift
// Before
Button(action: addUser) {
    Image(systemName: "plus")
}

// After
Button("Add User", systemImage: "plus", action: addUser)
```

**Line 31: Avoid `Binding(get:set:)` in view body - use `@State` with `onChange()` instead.**

```swift
// Before
TextField("Username", text: Binding(
    get: { model.username },
    set: { model.username = $0; model.save() }
))

// After
TextField("Username", text: $model.username)
    .onChange(of: model.username) {
        model.save()
    }
```

### Summary

1. **Accessibility (high):** The add button on line 24 is invisible to VoiceOver.
2. **Deprecated API (medium):** `foregroundColor()` on line 12 should be `foregroundStyle()`.
3. **Data flow (medium):** The manual binding on line 31 is fragile and harder to maintain.

End of example.


## References

- `references/accessibility.md` - Dynamic Type, VoiceOver, Reduce Motion, and other accessibility requirements.
- `references/api.md` - updating code for modern API, and the deprecated code it replaces.
- `references/design.md` - guidance for building accessible apps that meet Apple’s Human Interface Guidelines.
- `references/hygiene.md` - making code compile cleanly and be maintainable in the long term.
- `references/navigation.md` - navigation using `NavigationStack`/`NavigationSplitView`, plus alerts, confirmation dialogs, and sheets.
- `references/performance.md` - optimizing SwiftUI code for maximum performance.
- `references/data.md` - data flow, shared state, and property wrappers.
- `references/swift.md` - tips on writing modern Swift code, including using Swift Concurrency effectively.
- `references/views.md` - view structure, composition, and animation.

This project-local adaptation derives from Paul Hudson's SwiftUI Agent Skill and remains subject to the included MIT license.
