@./agents.md

# Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects what I actually pay (OpenAI is near-free for me due to a deal), not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| Model    | Cost | Intelligence | Taste |
| -------- | ---- | ------------ | ----- |
| gpt-6-astra  | 9    | 8            | 6     |
| sonnet-5.5 | 5    | 5            | 6     |
| opus-5.5 | 4    | 7            | 9     |
| fable-5.1  | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive option.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-6-astra — it's effectively free.
- gpt-6-astra is limited to three jobs: review, mechanical implementation, and computer use when needed. Anything beyond that needs my consent first. It never writes docs (docs repos, READMEs, specs, PR descriptions). It doesn't design or own tricky logic. Treat its code as a draft: read every diff line by line and simplify it before committing.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans/implementations: fable-5.1 or opus-5.5, optionally gpt-6-astra as an extra independent perspective.
- Never use Haiku.
- Claude models (sonnet-5.5, opus-5.5, fable-5.1) run via the Agent/Workflow model parameter.

Using gpt-6-astra inside workflows and subagents (the model parameter only takes Claude models):
- Implementation goes through the `codex-implementation` skill, reviews through `codex-review`. Both run Codex via `~/.claude/bin/codex-run.sh`, which owns the model pin, timeout and completion sentinel, normally from the `codex-runner` agent (`~/.claude/agents/common/codex-runner.md`), inline when the caller is itself a subagent. Never call `codex` by hand and never hand-roll a wrapper agent: a hand-rolled run has no sentinel and goes dark.
- Spawn it with `subagent_type: 'codex-runner'` and a `gpt-6-astra:<task>` label, e.g. `{label: 'gpt-6-astra:review-auth'}`; the workflow UI shows the wrapper's Claude model, so the label is the only indication the real worker is gpt-6-astra.
- After launching, the runner ends its turn and is resumed by the completion notification or the heartbeat. Never emit "waiting…" and keep polling; that is what causes stalls.
- Parallel gpt-6-astra implementation agents must use `isolation: 'worktree'` so codex edits don't collide in the shared checkout.
- Workflow token budgets only count Claude tokens; codex work is free and invisible to `budget.spent()`.