# Integrations and Data

## Shared Rules

- Cursor and Codex failures must not block each other.
- Never include secrets or full private responses in logs, errors, tests, screenshots, documentation, or generated fixtures.
- Map raw integration failures into small typed error categories suitable for diagnostics.
- Avoid force unwraps and rigid assumptions in private response parsing.
- Keep live service calls out of ordinary unit tests. Test request construction, parsing, state transitions, and process cleanup with controlled inputs.

## Cursor

Credential resolution order:

1. Manually saved token from Keychain account `cursor-token`.
2. Read-only token discovery from Cursor's local application state.

The dashboard cookie is derived in memory and must never be persisted or logged. Cursor currently uses a private dashboard endpoint, so treat HTTP status, fields, plan names, and payload shape as compatibility boundaries rather than public contracts.

Failure policy:

- If no credential exists and cached Cursor usage exists, keep the cached value available in the explicit `.stale` state.
- If refresh fails and cached usage exists, retain it and expose `.stale` rather than claiming a current connection.
- If no current or cached usage exists, display disconnected state.

## Codex

Executable discovery checks the installed ChatGPT/Codex application bundle first, then common package-manager paths and `PATH`. Inside the bundle it prefers the `codex-cli/codex-package.json` entrypoint, then the known `Contents/Resources/codex-cli/bin/codex` and legacy `Contents/Resources/codex` layouts, so ChatGPT app updates that relocate the CLI do not silently disable Codex reads.

Each refresh starts a short-lived `codex app-server` process, initializes the protocol, requests `account/rateLimits/read`, parses the available 5-hour and/or weekly quota windows by duration, and terminates the process after success, failure, cancellation, or timeout. A plan may return only one non-null window (`secondary` can be `null`); the absent window stays `nil` so the card, settings, and status bar hide that row instead of presenting an invented `0%`.

The status bar keeps user window preferences but resolves them against the windows actually returned: if every enabled ChatGPT window is unavailable, it displays an available window instead, preferring 5 hours over weekly. This fallback is not persisted, so a plan change that restores the preferred window switches back automatically. Disabling the only effective ChatGPT item also clears enabled-but-unavailable window preferences so the fallback does not immediately reappear.

Failure policy:

- On any Codex read failure, set `codexUsage` to `.disconnected`.
- Do not show cached Codex quota as though it were current.
- Do not synthesize a missing quota window; hide the row and its status-bar item instead.
- Preserve the timeout race and guaranteed child-process cleanup when refactoring.

Concurrency notes:

- `AppServerSession` is reference state shared with cancellation handlers. Its `@unchecked Sendable` conformance is acceptable only while all mutable cross-thread state is protected and process/pipe operations remain safe under repeated cancellation.
- Cancellation must be idempotent.
- Drain stderr while the child is running so a full pipe cannot deadlock the process.
- Ensure all file handles and readability handlers are released on every terminal path.

## Cache

- Cache contains displayable usage data, never credentials or raw responses.
- Treat cache timestamps as part of truthfulness: cached data is a fallback, not proof of a successful current refresh.
- Codex deliberately does not load or save quota cache under the current product policy.
- The XCTest host disables controller startup side effects so ordinary unit tests do not read credentials, caches, or live services.

## Logging

- Log component detection, success, timeout, and coarse error categories.
- Use privacy-aware interpolation for any dynamic value.
- Never log raw `Error` descriptions if an upstream error may include request data, response bodies, paths containing personal information, or authentication details.
