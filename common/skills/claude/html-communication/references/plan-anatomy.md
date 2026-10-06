# Plan anatomy — what goes in a plan artifact

Read this when deciding what sections a given plan needs. The goal is a plan the
user can skim in 30 seconds and understand fully in a couple of minutes. Default to
the **core** sections below — they're what a thorough plan-mode plan normally
contains. Add the **optional** ones when they carry weight, and cut any section you'd
have to pad with filler; an empty "Risks" is worse than no "Risks."

The bundled `assets/plan-scaffold.html` already lays these out with numbered section
labels (01, 02, …). Renumber after you delete sections so the sequence stays clean.

## Header (always)

- **Title** — the *outcome*, not the task verb. "Real-time log tail with backpressure"
  beats "Implement log tailing." It should read like a PR title you'd be proud of.
- **Lede (1–2 sentences)** — what we're building and, in a clause, *why this approach*.
- **Meta row** — scope (small/medium/large), step count, files touched, rough effort
  estimate. Cheap orientation; keep every value honest.

## Core sections (include by default)

1. **Overview** — the situation and the goal: what exists today, what should exist
   after, and the reasoning behind the chosen approach ("why this way, not that way").
   This is where a plan earns trust — make the rationale explicit rather than leaving
   it implied in the steps.
2. **Steps** — ordered, each an imperative title plus a short body naming the concrete
   files/functions and any decision baked in. For larger plans, group steps under 2–4
   **phase** labels (e.g. Foundation → Wiring → Hardening) so the arc is visible. When
   a step had a real rejected alternative, name it in a clause ("a ring buffer rather
   than a channel, to cap memory") — that's what makes a plan feel thought-through.
3. **Files affected** — a table of path / change type (new·edit·delete) / one phrase on
   what and why. Gives the user the blast radius at a glance.
4. **Testing & verification** — how you'll prove it works: the command to run, the test
   to add, the behavior to observe, the regressions to check. Plan-mode plans that skip
   this feel unfinished.
5. **Risks & open questions** — genuine tradeoffs, assumptions you're making, and forks
   you need the user to confirm *before* proceeding. Pull any real decision here so it's
   vetoable — don't bury it in step prose.

## Optional sections (include when they carry information)

- **Prerequisites & assumptions** — things that must already be true, or assumptions
  that, if wrong, change the plan. Include when the plan depends on non-obvious state.
- **Out of scope** — one or two lines on what you're deliberately *not* doing this pass,
  when there's a plausible expectation you're heading somewhere you aren't.
- **Success criteria / definition of done** — a short checklist of concrete, checkable
  statements. Worth it for larger or fuzzier efforts; skip when the steps already make
  "done" obvious.

## Never do

- Don't invent content to fill a section. Fidelity beats completeness — cut it instead.
- Don't bury a decision the user should weigh in on inside step prose.
- Don't restate the whole plan in the surrounding chat message. The artifact *is* the
  plan; the chat is a 2–3 line pointer to it.

## Calibrating effort (from the artifact-design skill)

Match how many sections you include — and how much design polish — to the plan's weight:

- **Trivial change** (one file, obvious) — you may not need an artifact at all; a few
  lines of markdown in chat respects the user's time. Use judgment.
- **Ordinary feature/fix** — header + the five core sections, real content. Common case.
- **Big/ambiguous effort** — add phases, prerequisites, out-of-scope, and success
  criteria. The plan is a decision document; treat it like one.
