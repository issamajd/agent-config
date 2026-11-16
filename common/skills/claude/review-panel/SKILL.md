---
name: review-panel
description: Independent multi-model review of a diff, with every finding verified against the source. Use when the user asks for a panel review or a second opinion from other models, or when babysit-pr requests one. Do NOT use for small local checks.
---

# Review Panel

Several models review the same diff independently. You run the panel, dedupe,
verify, and report. You do not review the code yourself, and you fix nothing.

## Setup

1. Pick the diff: `git diff HEAD` plus untracked files, `git diff <base>...HEAD`,
   the PR's diff, or on round 2+ `git diff <last-reviewed-sha>...HEAD`. How to
   fetch a PR's diff depends on the git host; the machine notes say how
   (GitHub: `gh pr diff <n>`; Azure DevOps: fetch the PR ref and diff locally).
2. Write `panel-context.md` to the scratchpad: the PR title and description (or
   the user's original request) and the diff. Nothing from the implementer's
   transcript, plan or reasoning. The panel is only useful if it is independent.

## Reviewers

Every panel runs the same two reviewers, both at high effort. Launch them in
one turn so they run in parallel. Each only sees `panel-context.md` and the
repo, so order would add nothing.

- **opus-5.5** (`Agent`, `model: 'opus'`, `effort: 'high'`, label
  `review:opus`).
- **gpt-6.1-sol** (`codex-runner`, label `gpt-6.1-sol:review-<topic>`): follow
  `codex-review` as written, but tell the runner to start with
  `--effort high`. Check that its summary says
  `CODEX_MODEL=gpt-6.1-sol`, then parse its `report.md` into the schema below.

The opus reviewer gets the repo path, `panel-context.md`, this prompt, and a
`schema` of `{ findings: [{ file, line, severity, summary, failure_scenario }] }`:

```
You are reviewing a change you did not write. Read panel-context.md, then read
the real source for anything the diff touches: callers, types, tests.

Look for bugs, regressions, unhandled cases, security issues, mismatches
between the stated goal and the code, and type-safety escapes (any, casts,
non-null assertions).

Findings only: no summary, praise or style nits. Each finding needs file, line,
severity (P0 blocking, P1 should fix, P2 minor), a one-sentence defect and a
concrete failure scenario; without a scenario it is not a finding. An empty
list is a valid result. Do not edit files.
```

## Verify

Merge findings that name the same file and defect; keep the clearer wording
and note which models raised it. Agreement between models only sets the order
you check in, not the verdict.

Open the source for each finding and check its scenario yourself:

- **Confirmed**: the scenario produces the wrong result.
- **Rejected**: the code handles it or the scenario cannot occur. One-line reason.

If you cannot tell, run the code or write a one-off test. Still unsure: confirm
it with a note that it needs a human. Never drop a finding silently.

## Report

With a PR, post one comment per round on the PR, using the host's comment
command from the machine notes (GitHub: `gh pr comment <n>`; Azure DevOps: the
pull request threads API). Without a PR, report the same structure in chat
with clickable `file:line` references.

The comment names every model involved: the reviewers and the model that
verified and posted (you). A reader must be able to tell which model said what.

```md
## Review panel (round N, <short-sha>)
Reviewers: opus-5.5 (high), gpt-6.1-sol (high). Verified and posted by <your model slug>.

### Confirmed
- **P1** `src/auth/session.ts:42` (opus, sol): <summary>. <failure scenario>.

### Rejected
- `src/api/users.ts:17` (sol): <summary>. Rejected: <reason>.
```

No findings: say so and name the SHA. Never post a comment per finding or a
comment saying nothing changed. Record the reviewed SHA for the next round.
