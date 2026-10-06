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
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans/implementations: fable-5.1 or opus-5.5, optionally gpt-6-astra as an extra independent perspective.
- Never use Haiku.
- Claude models (sonnet-5.5, opus-5.5, fable-5.1) run via the Agent/Workflow model parameter.

Using gpt-6-astra inside workflows and subagents (the model parameter only takes Claude models, so use a wrapper):
- **Prefer the `codex-runner` agent** (`~/.claude/agents/common/codex-runner.md`) over hand-writing a wrapper prompt — it encodes the reliable non-stalling pattern (foreground when short; background-with-sentinel + guaranteed single resume when long) and verifies the result. Spawn it with `subagent_type: 'codex-runner'` and label `gpt-6-astra:<task>`. Only hand-roll a wrapper for one-offs the agent doesn't fit.
- If you do hand-roll: spawn a thin Claude wrapper agent with `model: 'sonnet', effort: 'low'` whose prompt instructs it to write a self-contained codex prompt, run `codex exec` via Bash, and return the report (use `schema` on the wrapper to get structured output back).
- Always label these agents with a `gpt-6-astra:` prefix, e.g. `{label: 'gpt-6-astra:review-auth'}`; the workflow UI shows the wrapper's Claude model, so the label is the only indication the real worker is gpt-6-astra.
- Codex runs can exceed Bash's 10-minute timeout. The reliable long-run pattern: run codex as ONE background Bash command that writes a sentinel on exit (`codex … ; echo done > sentinel`) with `run_in_background`, then END the turn — the single completion notification deterministically resumes the agent. Never emit "waiting…" and keep polling; that is what causes stalls.
- Parallel gpt-6-astra implementation agents must use `isolation: 'worktree'` so codex edits don't collide in the shared checkout.
- Workflow token budgets only count Claude tokens; codex work is free and invisible to `budget.spent()`.