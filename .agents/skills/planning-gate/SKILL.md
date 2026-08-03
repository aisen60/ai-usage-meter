---
name: planning-gate
description: Opt-in Agent Quota Bar planning workflow for reviewed design and implementation plans. Use only when the user explicitly asks for "详细计划", "头脑风暴", "完整计划", "planning gate", or an equivalent deliberate planning phrase. Do not activate automatically from task complexity alone.
---

# Planning Gate

Use this skill only when the user explicitly asks for the planning workflow. Adapt the `brainstorming` and `writing-plans` shape to Agent Quota Bar for reviewed design and execution planning before implementation. Do not create a second long-term knowledge system.

## Activation

Activate when the user says any equivalent of:

- `planning gate`
- `开启 planning gate`
- `详细计划`
- `做详细计划`
- `完整计划`
- `先做计划`
- `头脑风暴`
- `先头脑风暴`
- `进入脑暴计划模式`
- `开启头脑风暴`
- `开启详细计划`
- `开启完整计划`
- `先不要写代码，做完整计划`

Do not activate this skill just because a task looks complex.

## Session State

Once activated, keep it active for later messages in the same conversation until the user clearly exits it.

Exit when the user says any equivalent of:

- `关闭 planning gate`
- `退出脑暴计划模式`
- `回到默认流程`
- `开始实现`
- `按计划执行`
- `不用 planning gate 了`

Planning-gate also tracks one session variable: `artifact language`.

- If `artifact language` is unset, ask once before producing the first saved design or plan:
  `接下来的 design.md 和 plan.md 要用什么语言写？`
- After the user answers, reuse that language for all planning-gate prose, `design.md`, and `plan.md` in this conversation.
- Keep code, commands, paths, API names, type names, env vars, and other exact technical identifiers in their original form.
- Do not infer the language from repo code or from English identifiers.

## State Machine

Track which stage the conversation is in:

1. `brainstorming`: clarify intent, constraints, success criteria, and design direction.
2. `design-review`: present the design in sections and revise it with the user.
3. `spec-review`: write `design.md`, self-review it, and wait for the user to review the written file.
4. `writing-plans`: turn the approved design into an implementation plan.
5. `plan-review`: write `plan.md`, self-review it, and wait for user direction.
6. `ready-to-execute`: the user has approved the plan and can start implementation.

Do not skip directly from `brainstorming` to implementation. If the user asks to start early, summarize the missing stage and ask whether to bypass it.

## Core Rules

- Do not use this skill for worktrees, subagents, mandatory TDD, automated code review, branch finishing, or release workflows. Those remain governed by normal Agent Quota Bar repository rules and task-specific skills.
- Do not write code during `brainstorming`.
- Do not start implementation during `writing-plans`.
- Treat file persistence as required, not optional.
- Every planning-gate task uses this process even if the task looks small.
- Ask exactly one focused question per message when clarification is needed.
- Prefer multiple-choice questions when the answer space is clear.
- Explore only the smallest necessary project context before designing.
- Use YAGNI aggressively.
- If a repo-specific rule conflicts with this skill, follow the repo-specific rule.

## Completion Rule

Planning-gate outputs are incomplete until the corresponding working artifact exists under `.agent-plans/`.

- `brainstorming` is incomplete until `design.md` exists, has been self-reviewed, and the user has been asked to review the written file.
- `writing-plans` is incomplete until `plan.md` exists and has been self-reviewed.
- Mention the saved file path in the response.
- If file creation or update fails, say the stage is blocked and do not pretend the artifact is complete.

## Brainstorming

Use this stage to prevent premature implementation.

### Required Flow

1. Explore project context.
2. Check scope. If the request spans multiple independent subsystems, stop and decompose it first.
3. Run a clarification loop: ask one material question per message until `purpose`, `constraints`, and `success criteria` are clear enough.
4. Separate goals from non-goals.
5. Record assumptions and note which need verification.
6. Identify impact areas: app lifecycle, menu bar UI, controller state, Cursor or Codex integrations, models and parsing, cache or Keychain, tests, docs, packaging, or release behavior.
7. Propose 2-3 approaches with trade-offs.
8. Recommend one approach and explain why it fits Agent Quota Bar's macOS 13 baseline, Swift 5 language mode, dependency policy, privacy boundaries, and product semantics.
9. Present the design in sections.
10. Ask the user to approve or revise each section.
11. Write the validated design to `design.md`, self-review it, and ask the user to review the written file before moving to `writing-plans`.

If the request spans independent tracks such as menu bar UI, Cursor integration, Codex process protocol, credential storage, login items, or distribution, split it before detailed requirement questions. Explain the sub-projects, suggest an order, and only brainstorm the first sub-project through the normal flow.

### Clarification Loop

`brainstorming` is a multi-turn loop, not a single question followed by a design.

- Keep asking one question per message until the high-impact unknowns are answered or explicitly accepted as assumptions.
- If a previous answer exposes a new important unknown, ask the next question before proposing the design.
- Do not exit the loop just because a plausible implementation is obvious.

### Uncertainty Register

Before proposing the design, check these categories:

- objective and non-goals
- user or caller workflow
- failure paths and error handling
- permissions, roles, or ownership boundaries
- data inputs, state changes, and persistence
- compatibility, migration, rollback, or versioning risks
- validation and proof requirements
- affected neighboring modules or systems

If one category is still high-risk and unresolved, continue the clarification loop or mark it as an explicit assumption.

### Design Shape

The saved `design.md` should cover these sections using the chosen artifact language:

- decision
- why
- impact
- architecture
- components
- data flow
- error handling
- testing
- behavior
- non-goals
- risks
- open questions

### Design Self-Review

Before asking the user to review the written spec, fix issues inline:

- ambiguous objective
- hidden product or design choices
- contradictory assumptions
- unclear boundaries
- data-flow gaps
- missing failure handling
- missing validation strategy
- scope too broad for one implementation plan
- placeholder language such as `TBD`, `etc.`, or `handle edge cases`
- likely conflict with Agent Quota Bar docs, skills, product invariants, deployment target, or ownership boundaries

### Written Spec Review Gate

After the user accepts the design sections:

1. Create or update `.agent-plans/<task-id>/design.md`.
2. Put the working-artifact header at the top in the chosen artifact language.
3. Save the validated design there in the chosen artifact language.
4. Re-read the file and fix any language mismatch, placeholder, contradiction, ambiguity, or over-broad scope.
5. Ask the user to review the written file before moving to `writing-plans`.

Do not transition to `writing-plans` until the user approves `design.md`.

## Writing Plans

Use this stage only after the design direction and written spec are approved.

### Scope Check

Before writing the plan, check whether the approved design still spans multiple independent subsystems. If it does, split it into separate plans. Each plan should produce working, testable software on its own.

### File Structure First

Before defining tasks, map the expected files or module boundaries and what each is responsible for.

Use these rules:

- Prefer clear boundaries and well-defined interfaces.
- Follow the existing Agent Quota Bar flow of `App / Views -> QuotaController -> Services -> Models / system APIs` before inventing new structure.
- Keep files and tasks small enough to fit in context.
- Do not restructure large files unless that split clearly reduces risk for this task.

### Plan Shape

The saved `plan.md` should cover these sections using the chosen artifact language:

- objective
- architecture
- tech stack
- assumptions
- affected areas
- file map
- task list
- verification
- risks
- stop conditions

Assume the executor has limited repo and domain context. The plan must be specific enough to execute without guessing the intended behavior, boundary, or proof path.

### Task Rules

Each task should include:

- a concrete goal
- exact expected file path, directory, package, or module boundary when known
- the implementation action
- the verification step for that task or milestone
- any dependency on earlier tasks

Prefer module-level steps over tiny mechanical steps. Split tasks only when it improves reviewability or execution.

Use checkbox syntax for tasks in saved or handoff-ready plans so later execution can track progress.

### Code In Plans

Do not include complete code in `plan.md` by default.

Include code only when the user explicitly asks for a code-level plan, the snippet is the design decision being reviewed, the change is a small isolated function/test/script/config, or the plan must be handed to a low-context executor. Keep snippets scoped to the relevant file or function.

### Plan Self-Review

Before presenting `plan.md` as complete, fix issues inline:

1. Every approved design requirement maps to a task or is explicitly out of scope.
2. No placeholder language remains.
3. Names are consistent across tasks.
4. File paths align with the file map.
5. Verification is concrete and realistic.
6. Each task maps to a focused component, file, or module boundary.

Plans must name real verification signals. Read `.agents/skills/agent-quota-bar/references/validation-and-release.md` and use its focused evidence rules plus the root `xcodebuild test` gate when code changes are planned. Treat GUI launch, live credentials, private service calls, login-item behavior, signing, and Gatekeeper checks as unverified unless the user explicitly authorizes the required runtime work. If verification is manual, describe the concrete manual check.

### No Placeholders

Do not write:

- `TBD`, `TODO`, `implement later`, `fill in details`
- `add appropriate error handling`
- `add validation`
- `handle edge cases`
- `write tests for the above`
- `similar to Task N`
- `run relevant tests`

### Plan Review Gate

Before sending the final plan response:

1. Create or update `.agent-plans/<task-id>/plan.md`.
2. Put the working-artifact header at the top in the chosen artifact language.
3. Save the reviewed plan there in the chosen artifact language.
4. Re-read the file and fix any language mismatch, placeholder, contradiction, ambiguity, or weak verification.
5. Tell the user where the file was saved.

After that, ask:

`Plan ready. Say "按计划执行" or "开始实现" when you want implementation to start, or tell me what to revise.`

Do not dispatch subagents or enter another execution workflow from this skill.

## Persistence Rules

This skill must not create a parallel knowledge base.

- Save working artifacts under `.agent-plans/<YYYY-MM-DD>-<short-task-slug>/`.
- Write the design to `design.md` and the implementation plan to `plan.md`.
- Create the task folder before presenting a completed design or plan in chat.
- Update the existing artifact in place when the user asks for revisions.
- Include a working-artifact notice at the top of each file in the chosen artifact language. The notice must say the file is a working planning artifact, not source of truth, and should not be committed.
- If continuing an existing planning-gate task, reuse the existing task folder.
- Do not commit `.agent-plans/` files.
- Do not create `docs/superpowers/specs` or other long-term spec stores unless the user explicitly asks for them.
- After implementation, update `agent-quota-bar` references only for durable repository learnings under that skill's maintenance rules. Update `macos-menu-bar-app` references only when the work changes reusable macOS menu bar guidance rather than project-specific behavior.

## Default Mode

When this skill is not active, follow the normal project instructions:

- simple requests: output `思路`
- complex requests: output `思路` and `计划`
- after the first analysis, continue execution unless the project rules require asking the user
