---
name: html-planning
description: >-
  Render implementation plans as an engaging, readable HTML Artifact instead of a
  wall of markdown. Use this WHENEVER you are about to present a plan of action —
  entering plan mode, calling ExitPlanMode, or any time the user asks you to "plan
  this out," "outline an approach," "propose how you'd do X," "give me a plan," or
  "how would you tackle this." Applies to implementation plans, refactors, migrations,
  and multi-step approaches, even when the user doesn't say the word "plan." If you
  find yourself about to write a numbered list of steps for the user to approve,
  use this skill first.
---

# HTML Planning

Plans presented as a plain wall of markdown are hard to scan and easy to skim past.
This skill turns the plan you were going to write into a polished, theme-aware HTML
**Artifact** the user can actually enjoy reading — the outcome up top, the steps as
clean cards, files and risks where they belong. It does **not** change how you *think*
about the plan or the approval flow; it changes only the surface you present it on.

## When this applies

Any moment you're about to hand the user a plan for sign-off: plan mode
(`ExitPlanMode`), or an informal "here's how I'd approach it." If the change is genuinely
trivial — one obvious edit — a couple of lines of markdown in chat is fine and faster;
use judgment (see the calibration note in `references/plan-anatomy.md`). Everything
larger deserves the artifact.

## Workflow

Do your normal research and thinking to form the plan first — this skill is about
*presentation*, so a good plan still comes from understanding the code. Then:

1. **Load design guidance.** Invoke the `frontend-design` skill (the user specifically
   wants its aesthetic sensibility applied here). It steers you away from generic
   AI-looking output toward something distinctive and considered. The `Artifact` tool
   will separately pull in `artifact-design` for its own constraints — that's expected.

2. **Decide the sections.** Read `references/plan-anatomy.md` and pick the sections this
   particular plan actually needs. Don't fill sections with filler — a plan with an
   honest three sections beats one padded to five.

3. **Build the HTML.** Start from `assets/plan-scaffold.html` — it's body-content only
   and already handles the parts that are easy to get wrong: light/dark theming that
   respects the viewer's toggle, responsiveness with no horizontal page scroll, and a
   fully self-contained page (the Artifact CSP blocks external fonts, scripts, and
   images, so everything stays inline). Treat the scaffold as a **starting point to riff
   on**, not a template to fill mechanically — retune the palette, type, and layout so it
   feels made for this plan, per `frontend-design`. Keep the theming and responsiveness
   mechanics intact. Replace every `{{ placeholder }}` with real content and delete
   sections you don't use.

4. **Render it.** Write the file to your scratchpad directory, then call the `Artifact`
   tool with that file path. Give it a stable `<title>` (the plan title), a one-sentence
   `description`, and a `favicon` (e.g. `"🗺️"` or `"🛠️"`). If you revise the plan after
   feedback, edit the same file and call `Artifact` again with the same path so it
   redeploys to the same URL.

5. **Present it.** In your chat message, keep it to 2–3 lines: link the artifact and give
   the one-sentence gist. The artifact *is* the plan — don't re-dump the whole thing as
   markdown alongside it.
   - **In plan mode:** still call `ExitPlanMode` to get approval, but its markdown can be
     a compact digest (title + the step titles) that points to the artifact for detail.
     The approval gate needs *something*; it doesn't need the full prose twice.
   - **Not in plan mode:** just ask the user to approve or tell you what to change.

## What makes a plan artifact good

The design should serve the reading, not decorate it. Aim for:

- **Outcome-first.** The title names what the user will *have*, not the chore. The intro
  justifies the *shape* of the approach in a sentence — that's what makes a plan feel
  thought-through rather than mechanical.
- **Scannable steps.** Each step is one imperative line plus a short body naming concrete
  files/functions. Surface a rejected alternative in a clause when there was a real fork.
- **Honest risks.** Pull any decision the user should weigh in on into a visible
  Risks/open-questions section, not buried in step prose — so they can veto cheaply.
- **Restraint.** No filler sections, no re-stating the plan in chat, no design flourish
  that doesn't help someone read faster.

See `references/plan-anatomy.md` for the full section-by-section guide and effort
calibration.
