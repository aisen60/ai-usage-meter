# Lifecycle and UI

## Scene Choice

Use `MenuBarExtra` for SwiftUI-first menu bar apps when the deployment target supports it.

- `.menu` fits commands, toggles, and standard menu rows.
- `.window` fits custom cards, progress indicators, toolbars, and richer layout.
- `NSStatusItem` is appropriate when you need lower-level mouse events, custom status-button behavior, or compatibility beyond `MenuBarExtra`.

Changing between these approaches affects focus, dismissal, rendering, keyboard behavior, and lifecycle. Validate the interaction, not only compilation.

## App Lifecycle

- Use the SwiftUI `App` entrypoint as the default owner of scenes.
- Add `NSApplicationDelegateAdaptor` only for app-delegate callbacks or system APIs that do not fit scene modifiers.
- Keep delegate methods thin and forward substantial work to focused services.
- Do not assume a menu bar popover is open when background refresh runs.
- Cancel long-lived work when its owner stops, and make restart behavior explicit.
- Consider sleep/wake, network loss, user logout, client updates, and application termination for polling or child-process integrations.

## State Ownership

- Keep one clear owner for shared menu-bar state.
- Place observable UI state on the main actor.
- Keep parsing, network requests, process IO, Keychain access, and persistence outside view bodies.
- Inject services when doing so creates deterministic tests or isolates unstable system behavior; avoid protocol layers that exist only for ceremony.
- Do not migrate `ObservableObject` to Observation solely because the toolchain supports it. Check deployment compatibility, project language mode, binding call sites, and migration scope first.

## Menu Bar Rendering

- Keep the label fast and side-effect free; macOS may render it independently of the expanded content.
- Give disconnected, stale, loading, and error states distinct semantics even if some share a compact visual fallback.
- Do not rely on color alone. Include accessible labels or values for state and percentage meaning.
- Avoid fixed font sizes when user scaling is expected; if compact status-bar geometry requires fixed sizing, verify legibility and provide complete accessibility labels.
- Use semantic materials and system colors where practical so light, dark, increased-contrast, and tinted appearances remain usable.

## Controls and Accessibility

- Give icon-only buttons explicit accessible names and help text.
- Ensure refresh controls expose busy and disabled state correctly.
- Respect Reduce Motion for nonessential animations.
- Verify keyboard focus for controls inside `.window` style content.
- Check VoiceOver reading order and clarify whether each percentage is used or remaining.

## AppKit Bridging

- Keep AppKit use localized behind small adapters or at the app boundary.
- Use AppKit when it provides necessary macOS behavior; do not treat it as a failure of SwiftUI architecture.
- Interact with `NSApplication`, `NSWorkspace`, windows, and status items from the appropriate actor.
- Avoid retaining windows, delegates, observers, or event monitors longer than their owning feature.
