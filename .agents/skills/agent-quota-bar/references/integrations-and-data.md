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

- If no credential exists and cached Cursor usage exists, keep the cached value available.
- If refresh fails and cached usage exists, retain it and expose a degraded/error connection state.
- If no current or cached usage exists, display disconnected state.

## Codex

Executable discovery checks the installed Codex application, ChatGPT application resources, common package-manager paths, and `PATH`.

Each refresh starts a short-lived `codex app-server` process, initializes the protocol, requests `account/rateLimits/read`, parses the longest quota window, and terminates the process after success, failure, cancellation, or timeout.

Failure policy:

- On any Codex read failure, set `codexUsage` to `.disconnected`.
- Do not show cached Codex quota as though it were current.
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

## Logging

- Log component detection, success, timeout, and coarse error categories.
- Use privacy-aware interpolation for any dynamic value.
- Never log raw `Error` descriptions if an upstream error may include request data, response bodies, paths containing personal information, or authentication details.
