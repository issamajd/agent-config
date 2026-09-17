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

Runs OpenAI Codex CLI (`codex review`, default model **gpt-6-astra**) as an
independent reviewer of a diff, then relays and triages its findings. Codex reads
the repo itself and returns a severity-tagged list of issues — a genuinely
separate model's perspective, useful as a second pass on broad or risky changes.

## When to use this

- The user explicitly asks for Codex / gpt-6-astra / "an independent review" / "a
  second opinion" / "another agent's take."
- A change is broad, subtle, or high-stakes enough that a fresh outside
  perspective is worth the extra minutes.

**When NOT to use:** small, local, or obvious changes. Claude's own
`/code-review` is faster and sufficient there — don't reach for Codex by default.

## Key facts about the tool (verified on this machine)

- **Never invoke `codex.cmd` directly — use `~/.claude/bin/codex-run.sh`.** That
  script owns every CLI quirk below plus the launch/observe pattern (predictable
  run dir, hard timeout, completion sentinel, heartbeat). Calling the CLI by hand
  is how runs end up invisible.
- **A scope flag and a custom prompt are mutually exclusive.** In this version,
  `codex review --uncommitted "…"` / `--base` / `--commit "…"` all error with
  *"cannot be used with [PROMPT]"*. So the rubric goes in via stdin with **no
  scope flag**, and the scope is stated *inside* the prompt (first line). This is
  why step 1 below is "choose the scope line" and not "choose a flag."
- **Report → stdout, noise → stderr.** The clean verdict + `Full review
  comments:` list goes to **stdout** with no ANSI; streaming reasoning goes to
  stderr. `codex-run.sh` splits them into `report.md` and `raw.log` and strips
  the `SUCCESS: The process…` teardown lines that leak into stdout.
- **`codex review` has no `-m` flag** — the model is pinned with
  `-c 'model="gpt-6-astra"'`. The script does this; without it the run silently
  falls back to whatever `~/.codex/config.toml` defaults to.
- **It takes minutes, sometimes many.** Never run it in the foreground. Step 2
  launches it as a tracked background job with a monitor, so a long review
  reports progress instead of going dark.

## Workflow

### 1. Choose the scope line

Exactly one scope, expressed as the **first line** of the prompt (there is no
scope flag — see above):

| User intent | Scope line to prepend |
|---|---|
| Uncommitted work (staged + unstaged + untracked) | `Review the currently uncommitted changes (staged, unstaged, and untracked files) in this repository.` |
| Current branch vs. a base | `Review the changes on the current branch compared to the \`main\` branch (git diff main...HEAD).` |
| A specific commit | `Review the changes introduced by commit \`<sha>\` (git show <sha>).` |

If scope is ambiguous, default to uncommitted when there are local changes,
otherwise the base-branch line. If the user names an area to focus on, append a
sentence like `Focus especially on <area>.` to the prompt.

### 2. Write the prompt, then launch + watch

Pick a short run id (`review-<topic>`, e.g. `review-auth`) — it names the run
directory and every progress line, so make it recognisable.

**a. Write the prompt file** — scope line, blank line, then the rubric from
"## Review Prompt":

```bash
PROMPT=/tmp/codex-review-prompt.md
cat > "$PROMPT" <<'EOF'
Review the currently uncommitted changes (staged, unstaged, and untracked files) in this repository.

Review these changes for bugs, regressions, security issues and requirement mismatches.
Prioritize findings over summary. For each finding include: severity, file and line reference, concrete failure mode and suggested fix direction.
Do not edit files. If there are no substantive findings, say so.
EOF
```

**b. Launch it** — Bash tool with **`run_in_background: true`**. That parameter
is what makes the job harness-tracked, which is what fires the completion
notification:

```bash
~/.claude/bin/codex-run.sh start --mode review --id review-auth \
  --prompt /tmp/codex-review-prompt.md --repo "$PWD" --timeout 1800
```

**c. Immediately arm the heartbeat** — one `Monitor` call, before you do anything
else:

```
Monitor({
  command: '~/.claude/bin/codex-run.sh watch --id review-auth',
  description: 'codex review-auth progress',
  timeout_ms: 2000000,
})
```

You now get a progress line each minute (`running` / `STALLED` / `ORPHANED`) and
a final line with the exit status. **Then end your turn** — do not poll, and do
not sit in a "waiting…" message. Between the monitor events and the background
completion notification you will be woken; either one is a valid resume.

If you are ever asked mid-run "what's it doing?", answer with one cheap call —
`~/.claude/bin/codex-run.sh status --id review-auth` — rather than guessing.

The run leaves `report.md` (the deliverable) and `raw.log` (the full stream) in
its run directory; the launch output prints both paths as `CODEX_REPORT=` and
`CODEX_RUN_DIR=`. A non-zero `CODEX_EXIT` or an empty `report.md` means the run
errored — read `raw.log` and say what happened rather than reporting no findings.

### 3. Read and triage the findings

`report.md` holds a one-paragraph verdict followed by:

```
Full review comments:

- [P1] <title> — <file>:<line>
  <explanation>
- [P2] <title> — <file>:<line>
  ...
```

Severities run `P0`/`P1` (blocking — won't compile, data loss, security) down to
higher `P#` (nits).

### 4. Relay to the user

- Summarize the findings grouped by severity, with clickable `file:line` refs.
- If Codex finds nothing, say so clearly and name the review target it inspected.
- **Codex is an independent model, not ground truth.** Sanity-check each finding
  against the actual code before presenting it as fact — flag any you disagree
  with rather than passing them through blindly.
- Do not auto-apply fixes unless the user asks. If they do, verify each change
  against the real code first.

## Review Prompt

The standard rubric (goes after the scope line in `$PROMPT`):

```
Review these changes for bugs, regressions, security issues and requirement mismatches.
Prioritize findings over summary. For each finding include: severity, file and line reference, concrete failure mode and suggested fix direction.
Do not edit files. If there are no substantive findings, say so.
```
