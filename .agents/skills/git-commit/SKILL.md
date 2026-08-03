---
name: git-commit
description: Creates or drafts safe, atomic Git commits using diff analysis and Conventional Commit type tokens. Use when the user asks to commit changes, stage and commit, create or improve a commit message, split work into logical commits, or mentions git commit. Stage only intended files and default all human-readable commit subject and body text to Simplified Chinese unless the user explicitly requests another language for that commit.
---

# Git Commit

Create safe, atomic, and traceable Git commits. Derive the commit scope and message from the actual diff rather than guessing from the conversation summary.

## Language Policy

- Write all human-readable commit subject, body, and breaking-change description text in Simplified Chinese by default.
- Use another language only when the user explicitly requests that language for the current commit or commit-message draft.
- Keep Conventional Commit `type`, optional `scope`, filenames, code identifiers, product names, and machine-readable trailers such as `Closes #123` in their conventional form.
- Do not treat the surrounding conversation language as an override. Only an explicit commit-language request overrides the Simplified Chinese default.
- Preserve proper nouns that should not be translated, such as Cursor, Codex, SwiftUI, and Keychain.

Default format:

```text
<type>(<scope>): <Simplified Chinese summary>

[optional Simplified Chinese body]

[optional footer]
```

Omit the entire `(<scope>)` segment when no clear scope exists.

## Workflow

### 1. Confirm authorization and scope

- Create a local commit when the user explicitly asks to commit, create a commit, or perform an equivalent action.
- When the user asks only for a commit message, return a message draft without staging or committing.
- Prefer files actually modified for the current task.
- Do not automatically include pre-existing user changes, another agent's work, or unrelated generated output.
- Stop and explain the exact ambiguity when current-task changes cannot be separated safely from pre-existing work or when one file contains unrelated changes.

### 2. Inspect repository state

At minimum, inspect:

```bash
git status --short
git diff --name-status
git diff --cached --name-status
git diff --stat
git diff --cached --stat
```

Read the complete relevant diff. Inspect recent subjects only when repository convention is unclear:

```bash
git log -5 --pretty=format:%s
```

Do not inspect Git configuration, credential stores, or unrelated history.

### 3. Build an atomic staged set

- Keep one logical change per commit.
- Stage explicit paths with `git add -- <path...>`.
- Stage modifications or deletions for explicit paths with `git add -u -- <path...>` when appropriate.
- Do not use `git add .`, `git add -A`, broad globs, or other commands that might sweep unrelated files by default.
- Even when the user requests all changes, inspect every candidate for secrets, unrelated work, and generated output before staging.
- Never overwrite, revert, discard, move, or stash work that is outside the commit scope.

After staging, inspect again:

```bash
git diff --cached --name-status
git diff --cached --stat
git diff --cached
git diff --cached --check
```

Stop when the staged set is empty, exceeds the intended scope, or contains possible secrets.

### 4. Select type and scope

| Type | Purpose |
| --- | --- |
| `feat` | Add user-visible capability |
| `fix` | Correct defective behavior |
| `docs` | Change only documentation, instructions, or Skills |
| `style` | Change formatting without changing behavior |
| `refactor` | Restructure code without adding a feature or fixing a defect |
| `perf` | Improve performance |
| `test` | Add or change tests |
| `build` | Change build, dependency, or packaging configuration |
| `ci` | Change continuous-integration configuration |
| `chore` | Perform other maintenance work |
| `revert` | Revert an existing commit |

- Infer `type` from the staged diff rather than the file extension alone.
- Omit `scope` unless it is clear, stable, and useful for locating the change.
- Keep the whole subject concise, preferably at most 72 characters, with no trailing period.
- For Chinese output, use clear action phrases such as `添加`, `修复`, `更新`, `移除`, or `重构`.

Default Chinese examples:

```text
docs(skills): 添加中文 Git 提交工作流
fix(codex): 确保超时后终止子进程
feat(menu-bar): 显示额度刷新状态
refactor(cursor): 拆分凭据读取与用量请求
test: 补充套餐映射边界测试
```

Add a Chinese body only when the motivation, risk, or migration behavior needs explanation:

```text
fix(codex): 避免读取失败后显示过期额度

读取失败时立即切换为断开状态，防止用户把缓存额度误认为当前额度。
```

Keep the standard breaking-change marker, but write its description in the selected language:

```text
feat!: 调整配置文件格式

BREAKING CHANGE: 旧版配置需要迁移到新的服务列表结构。
```

If the user explicitly requests English for a commit, a valid override is:

```text
docs(skills): add localized Git commit workflow
```

### 5. Create the commit

- Use one `-m` argument for a subject-only commit.
- Use multiple `-m` arguments for separate subject and body paragraphs; avoid temporary editors and complex shell interpolation.
- Never modify Git configuration.
- Do not use `--amend` unless the user explicitly asks to modify the previous commit.
- Do not use `--no-verify` unless the user explicitly authorizes bypassing hooks after the risk is explained.
- When a hook fails, fix issues caused by the current change and retry. Report unrelated or unsafe-to-fix failures.
- Do not push, force push, rebase, tag, or create a pull request unless the user explicitly requests it.

### 6. Verify and report

After a successful commit, inspect:

```bash
git show --stat --oneline -1
git status --short
```

Report:

- Commit hash.
- Commit subject in the selected language.
- Changed-file count or concise committed scope.
- Remaining uncommitted changes without implying they belong to the new commit.

## Safety Boundaries

- Never commit tokens, cookies, private keys, passwords, authentication responses, `.env` files, or other credential material.
- Scrutinize new binaries, large archives, Derived Data, build directories, and release artifacts; exclude them unless the task explicitly requires them.
- Never run `git reset --hard`, `git checkout -- <path>`, `git clean`, or another data-discarding command.
- Never delete `index.lock`. Wait briefly and retry once; report a persistent lock conflict.

This project-local version is adapted from the `git-commit` Skill in GitHub's `awesome-copilot` repository and remains subject to the included MIT License.
