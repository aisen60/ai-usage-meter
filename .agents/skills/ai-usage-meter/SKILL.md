---
name: ai-usage-meter
description: Repository map and development workflow for the AI Usage Meter macOS app. Use whenever working in this repository and you need project-specific guidance about code placement, Cursor or Codex quota semantics, local credential handling, menu bar behavior, validation commands, packaging, release constraints, or known integration caveats.
---

# AI Usage Meter

Treat this file as a router. Read only the smallest reference that covers the task, then use the relevant Swift or macOS domain skill for implementation detail.

## Repository Invariants

- Keep Cursor and Codex independently refreshable and independently degradable.
- Preserve the displayed metric semantics: Cursor surfaces usage values; Codex surfaces remaining weekly quota.
- Allow Cursor to retain cached usage when a refresh fails. Never present stale Codex quota as current after a Codex refresh failure.
- Treat Cursor dashboard endpoints and the Codex `app-server` protocol as unstable private integrations. Parse defensively and fail without exposing raw payloads.
- Keep secrets in memory or Keychain only. Never log tokens, cookies, account identifiers, authorization headers, or complete service responses.
- Keep network, process, persistence, and credential logic out of SwiftUI view bodies.
- Prefer Apple frameworks and focused local helpers over new dependencies.
- Respect the checked-in macOS 13 deployment target and Swift 5 language mode unless migration is explicitly in scope.

## Route by Task

| Task | Read first | Then use |
| --- | --- | --- |
| Find the owning file or understand data flow | `references/repo-overview.md` | The narrow domain skill |
| Change Cursor or Codex integration behavior | `references/integrations-and-data.md` | `swift-concurrency-pro` when async/process behavior changes |
| Change menu bar label, popover, cards, or state flow | `references/repo-overview.md` | `swiftui-pro` and `macos-menu-bar-app` |
| Change Keychain, local Cursor state, cache, logging, or privacy | `references/integrations-and-data.md` | `macos-menu-bar-app` |
| Add or change tests | `references/validation-and-release.md` | Preserve XCTest; use `swift-testing-pro` only for explicit Swift Testing work |
| Build, package, sign, or prepare a release | `references/validation-and-release.md` | `macos-menu-bar-app` |
| Diagnose an unexpected local or release-only failure | `references/validation-and-release.md` | Relevant implementation skill |

## Workflow

1. Read the current implementation and project settings before proposing architecture or API modernization.
2. Load the narrowest project reference from the table.
3. State which product behavior must remain invariant before changing integration or presentation logic.
4. Make the smallest coherent change in the owning layer.
5. Add deterministic tests for parsers, state transitions, cancellation, or failure behavior when feasible.
6. Run the relevant focused check and the repository test gate described in `references/validation-and-release.md`.
7. Update a reference only when the task changes durable repository truth; keep references state-based rather than changelog-style.

## Related Skills

- Use `swiftui-pro` for SwiftUI API, view composition, state flow, accessibility, and performance.
- Use `swift-concurrency-pro` for tasks, actors, cancellation, processes, pipes, continuations, and lock-backed sendability.
- Use `macos-menu-bar-app` for menu bar lifecycle, AppKit integration, credential storage, login items, signing, and distribution.
- Use `swift-testing-pro` only when Swift Testing is already being used or the user asks to adopt or migrate to it.
- Use `git-commit` when staging or committing changes. It preserves unrelated work and defaults human-readable commit text to Simplified Chinese unless the user explicitly requests another language.
- Use `planning-gate` only when the user explicitly requests detailed planning, brainstorming, a complete plan, or the planning gate workflow. Do not activate it from task complexity alone.

The vendored `*-pro` skills are project-local adaptations of Paul Hudson's MIT-licensed agent skills. Repository rules and the checked-in toolchain take precedence over their general recommendations.
