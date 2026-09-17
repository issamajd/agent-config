---
name: codex-implementation
description: >-
  Ask the Codex CLI (gpt-6-astra) to IMPLEMENT scoped code changes in the current
  repository, then have Claude inspect the resulting diff and verification. This
  is how gpt-6-astra is invoked for implementation work. Use when the user asks
  Claude to delegate implementation to Codex or gpt-6-astra, when the
  model-selection rubric routes the work to gpt-6-astra, or when a bounded task
  would benefit from another coding agent producing a patch. Do NOT use for
  trivial edits Claude can make directly, or for review-only work — prefer
  [[codex-review]] there.
---

# Codex Implementation

Delegates a scoped change to Codex (**gpt-6-astra**) with repo write access, then
reviews what actually landed. This skill owns the **what and when**: scoping the
Goal, the mandatory guardrails, and the review-after policy. The **how** — the
CLI invocation, the timeout, the completion sentinel, the progress heartbeat —
lives in `~/.claude/bin/codex-run.sh` and the `codex-runner` agent. Never
hand-roll the invocation; that is how runs go dark.

## When to use this

- The user explicitly asks to delegate implementation to **Codex / gpt-6-astra**, or
  says "have Codex build/implement/fix this."
- The model-selection rubric routes the task to gpt-6-astra.
- A **bounded, well-scoped** task benefits from another coding agent producing a
  patch that Claude then reviews.

**When NOT to use:** trivial edits Claude can make directly (faster to just do
it), sprawling/underspecified work with no clear success criteria, or
review-only requests — use [[codex-review]] for those.

## Workflow

### 1. Confirm the tree is in a known state

Implementation changes are only reviewable if you can see exactly what Codex
touched. Note the baseline (`git status --short`, `git stash list`). If the tree
already has unrelated uncommitted changes, tell the user — Codex's edits will be
intermingled with them in the diff.

### 2. Write the prompt (Goal / Constraints / Success criteria / Report)

Compose the four sections below into a prompt file. **The Constraints block is
mandatory** — include it verbatim, tighten it for the task, never drop it. See
"## Implementation Prompt" for the template and a worked example.

### 3. Run it

**Default — spawn the `codex-runner` agent.** It owns the launch/observe/verify
loop, keeps the raw log and build output out of this context, and is the only
safe way to run several Codex tasks at once:

- Label the spawn `gpt-6-astra:<short-task>` so the UI shows the real worker.
- Give it the prompt file path, the repo, and a run id.
- For **parallel batches**, spawn one agent per batch with
  `isolation: 'worktree'` so concurrent Codex edits don't collide.
- Before spawning, arm a `Monitor` on the run id yourself (see below) — the
  agent's own progress events are invisible to you and to the user, so the
  parent watching the shared run directory is what keeps a long batch legible.

**Inline alternative — a single small task** where you want the diff directly in
this context. Same two calls [[codex-review]] uses, with `--mode exec`:

```bash
# a. launch — Bash tool with run_in_background: true
~/.claude/bin/codex-run.sh start --mode exec --id impl-parser \
  --prompt /tmp/codex-impl-prompt.md --repo "$PWD" --timeout 1800
```

```
# b. arm the heartbeat immediately, then END YOUR TURN — do not poll
Monitor({
  command: '~/.claude/bin/codex-run.sh watch --id impl-parser',
  description: 'codex impl-parser progress',
  timeout_ms: 2000000,
})
```

Either way: a progress line each minute (`running` / `STALLED` / `ORPHANED`) and
a terminal line with the exit status. If asked mid-run "what's it doing?", run
`~/.claude/bin/codex-run.sh status --id impl-parser` instead of guessing.

Check the launch summary before trusting the result: `CODEX_EXIT=0`,
`CODEX_MODEL=gpt-6-astra` (any other model, or a `CODEX_MODEL_MISMATCH` line,
means the model pin failed), and a
non-empty `CODEX_REPORT`. Anything else — read `raw.log` in the run dir and
report what happened.

### 4. Inspect the diff — do NOT trust the report alone

Look at what actually landed, not just what Codex says it did:

```bash
git -C "$REPO" status --short
git -C "$REPO" diff            # unstaged edits
git -C "$REPO" diff --stat
```

Reconcile the real diff against Codex's "Files changed" list. Flag anything
Codex touched that wasn't in scope, and anything in scope it missed.

### 5. Verify independently

Do not take Codex's "Verification" section on faith — and if you used the
`codex-runner` agent, do not take its verification on faith either. Re-run the
build and the relevant tests yourself (use the project's own verify/run flow).
Confirm the **Success criteria** from the prompt actually hold.

### 6. Review — ALWAYS review after Codex

Codex is a separate model producing a patch; its output is a **draft, not ground
truth**. Never hand a Codex diff back as done without a review pass:

- Run Claude's own `/code-review` (the `code-review` skill) on the resulting
  diff at minimum.
- For broad or high-stakes changes, also get an independent second opinion via
  [[codex-review]].
- Read the changed code yourself for correctness, scope creep, and convention
  fit before presenting it.

### 7. Relay to the user

- Summarize what Codex changed, grouped by file, with clickable `file:line` refs.
- State the verification result plainly: what you ran, and whether it passed. If
  tests failed or a criterion isn't met, say so — do not paper over it.
- Surface any guardrail violations, scope creep, or risks you found in review.
- If the run timed out or errored, say that outright — never present a partial
  or empty Codex run as a completed change.
- Do not commit or push unless the user asks.

## Implementation Prompt

Four sections — **Goal**, **Constraints (guardrails)**, **Success criteria**,
**Report**. Rules:

- **Goal**: one or two sentences. Name the exact behavior and the files/area.
  Keep it bounded — if you can't state it crisply, the task isn't ready for Codex.
- **Constraints**: the guardrails. Always include them; they keep the diff
  scoped, reviewable, and free of git-history and dependency surprises. You may
  add task-specific constraints (e.g. "do not touch the migration files"), never
  remove the defaults.
- **Success criteria**: concrete, checkable outcomes you will verify in steps 5–6.
- **Report**: the structured wrap-up Codex writes as its final message, captured
  to `report.md` in the run directory.

### Template

```
Goal:
<one or two sentences: exactly what to build or fix, and where>

Constraints (guardrails — do not violate):
- Stay strictly within the stated scope. Do not refactor, reformat, or "clean up" unrelated code.
- Do not change public APIs, config, dependencies, or the build system unless the Goal requires it; if it does, call it out explicitly in your report.
- Do not run git commit/push/reset/rebase or otherwise alter git history or the index. Leave changes as uncommitted working-tree edits.
- Do not delete or rewrite files you were not asked to touch. Prefer the smallest, most reviewable diff that satisfies the Goal.
- Match the existing code style, naming, and conventions of the surrounding files.
- Add or update tests where it is reasonable to cover the change.
- Build the project and run the relevant tests. Do not claim success you have not verified.
- If the task is ambiguous, blocked, or would require exceeding these constraints, STOP and report what you found instead of guessing.

Success criteria:
- <concrete, checkable outcomes — e.g. "new function X returns Y for input Z">
- <e.g. "existing tests still pass; a new test covers the added behavior">
- <e.g. "the project builds cleanly">

Report (end your run with this, as your final message):
- Files changed: list each path with a one-line note on what changed and why.
- Behavioral summary: what the code does now that it did not before.
- Verification: the exact build/test commands you ran and their results (pass/fail, key output).
- Assumptions & risks: anything you assumed, skipped, or that a reviewer should double-check.
- Follow-ups: anything out of scope you noticed but did not do.
```

### Worked example (Goal + Success criteria; Constraints/Report verbatim above)

```
Goal:
Add input validation to the log-file parser in src/SystemTraceParser so a malformed
timestamp line is skipped with a warning instead of throwing.

Success criteria:
- A line with an unparseable timestamp is skipped and logged at Warning level; parsing continues.
- A new unit test in tests/UnitTests covers the malformed-line case and passes.
- All existing tests still pass and the solution builds.
```
