---
name: codex-review
description: >-
  Ask the Codex CLI (gpt-6-astra) for an INDEPENDENT, second-pass code review of
  uncommitted changes, a branch diff, a specific commit, or a described
  implementation. Use WHENEVER the user asks to "have Codex review this," wants
  "a second opinion," "another agent's take," "an independent review," or when a
  change is broad/high-stakes enough that a fresh outside perspective adds value.
  Do NOT use for small local checks — prefer Claude's own /code-review there.
---

# Codex Review

Runs OpenAI Codex CLI (`codex review`, pinned to **gpt-6-astra**) as an
independent reviewer of a diff, then relays and triages its findings. Codex
reads the repo itself and returns a severity-tagged list of issues: a genuinely
separate model's perspective, useful as a second pass on broad or risky changes.

## When to use this

- The user explicitly asks for Codex / gpt-6-astra / "an independent review" /
  "a second opinion" / "another agent's take."
- A change is broad, subtle, or high-stakes enough that a fresh outside
  perspective is worth the extra minutes. `review-panel` includes it on those
  grounds.

**When NOT to use:** small, local, or obvious changes. Claude's own
`/code-review` is faster and sufficient there.

## Workflow

### 1. Choose the scope line

`codex review` rejects a custom prompt combined with a scope flag
(`--uncommitted`, `--base`, `--commit`), so the scope is the **first line of
the prompt** instead. Exactly one:

| User intent | Scope line |
|---|---|
| Uncommitted work (staged + unstaged + untracked) | `Review the currently uncommitted changes (staged, unstaged, and untracked files) in this repository.` |
| Current branch vs. a base | `Review the changes on the current branch compared to the \`main\` branch (git diff main...HEAD).` |
| A specific commit | `Review the changes introduced by commit \`<sha>\` (git show <sha>).` |

If the scope is ambiguous, default to uncommitted when there are local changes,
otherwise the base-branch line. If the user names an area to focus on, append
`Focus especially on <area>.`

### 2. Write the prompt file

Scope line, blank line, then the rubric from "## Review Prompt":

```bash
PROMPT=/tmp/codex-review-prompt.md   # or a file in your scratchpad directory
cat > "$PROMPT" <<'EOF'
Review the currently uncommitted changes (staged, unstaged, and untracked files) in this repository.

Review these changes for bugs, regressions, security issues and requirement mismatches.
Prioritize findings over summary. For each finding include: severity, file and line reference, concrete failure mode and suggested fix direction.
Do not edit files. If there are no substantive findings, say so.
EOF
```

### 3. Run it

Pick a run id, `review-<topic>`, for example `review-auth`. It names the run
directory and every progress line.

**Spawn the `codex-runner` agent** with `--mode review`, the prompt file, the
repo and the run id when you are the top-level session and want the raw log
kept out of your context, or this review is one of several things running.
Name the spawn `gpt-6-astra:review-<topic>` (the Agent tool's `description`, a
Workflow's `label`). It owns the launch, the heartbeat and the never-stall
rules, and returns the summary block and `report.md` verbatim.

**Run it inline** when you are already a subagent (no nesting) or want the raw
log at hand: follow sections 3 to 5 of
`~/.claude/agents/common/codex-runner.md` yourself with `--mode review`. That
is the `start` call and the `Monitor` call from section 3, then end the turn.

Either way the run takes minutes; never run `codex` in the foreground or by
hand. The script's default timeout fits a review. The summary block must show
`CODEX_EXIT=0`, `CODEX_MODEL=gpt-6-astra` and `CODEX_RESULT=ok`; otherwise read
`raw.log` and say what happened rather than reporting no findings.

### 4. Read and triage the findings

`report.md` holds a one-paragraph verdict followed by:

```
Full review comments:

- [P1] <title> — <file>:<line>
  <explanation>
- [P2] <title> — <file>:<line>
  ...
```

Severities run `P0`/`P1` (blocking: won't compile, data loss, security) down to
higher `P#` (nits).

### 5. Relay to the user

- Summarize the findings grouped by severity, with clickable `file:line` refs.
- If Codex finds nothing, say so clearly and name the review target it inspected.
- **Codex is an independent model, not ground truth.** Check each finding
  against the actual code before presenting it as fact, and flag any you
  disagree with rather than passing them through.
- Do not auto-apply fixes unless the user asks. If they do, verify each change
  against the real code first.

## Review Prompt

The standard rubric (goes after the scope line in `$PROMPT`):

```
Review these changes for bugs, regressions, security issues and requirement mismatches.
Prioritize findings over summary. For each finding include: severity, file and line reference, concrete failure mode and suggested fix direction.
Do not edit files. If there are no substantive findings, say so.
```
