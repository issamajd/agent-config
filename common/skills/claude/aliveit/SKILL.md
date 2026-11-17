---
name: aliveit
description: Make a UI interaction look alive: glass, stretch, magnify, a material response to the finger like the iOS 26 tab bar. Scores the current interaction with opus and gpt-6.1-sol judges, has opus agents build motion mocks, shows the user only mocks both judges score 8/10 or higher, then builds the pick and scores it again. Use when the user types /aliveit or says something looks flat, static, lifeless or not premium. For lag and jank, use smoothit.
---

# aliveit

The user named an interaction that looks flat. Give it a physical, material response to the
finger. Read `~/.claude/skills/smoothit/motion.md` first: it holds the definition (all six rules
apply here), the score scale, how to capture and how the judges run.

You do not score anything yourself. Opus agents create the mocks. gpt-6.1-sol only judges; it
never creates a mock or writes code.

## 1. Pin down the interaction

Name the screen, the control and the gestures in one line, and find the code that draws it.

## 2. Capture and score now

Capture it as `motion.md` describes, run `motion-report.sh`, and run both judges on rules 1 to
6. This is the baseline.

If any of rules 1 to 5 scores under 8 with either judge, the base is not smooth, and effects on
top of it only make that worse. Say so, run `smoothit` on it first, then continue.

## 3. Mocks

Spawn three opus agents in one turn (`Agent`, `model: 'opus'`), one per direction, each told to
make one distinct take, not a variant of another's. Give each:

- The interaction, the baseline recording's contact sheets, and the judges' notes on rule 6.
- The definition from `motion.md`, including the rule that everything rests when idle.
- The project's design system: its tokens and component catalog when it has one. The mock must
  look like the product, not like a demo of an effect. Without one, the user's standing visual
  constraints apply.
- The format: a single self-contained HTML file at the size the control is seen at (a phone
  viewport for mobile), driven by real pointer events, with springs rather than CSS durations,
  plus one line describing the gestures that show it off.

Then judge them:

1. Record every mock with the same Playwright gesture script (tap, hold, slow drag, fast flick,
   interrupt) and run `motion-report.sh` on each.
2. Run both judges on each mock, scoring rules 3, 4 and 6 (a headless browser says nothing true
   about rules 1, 2 and 5) plus **fit**: does it look like it belongs to this product. Pass the
   mock's HTML path as its source.
3. A mock with an overall under 8 from either judge goes back to the opus agent that made it,
   with both judges' notes, to revise (send to the same agent so it keeps its context). Record
   and judge the revision with a fresh packet. At most three rounds per mock.

**The user only ever sees mocks with an overall of 8 or higher from both judges.** Publish
those with the `html-communication` skill: each mock live and playable, its gestures, and both
judges' tables. Then stop and wait for a pick.

If no mock passes after three rounds, do not show any of them. Tell the user none passed, give
each one's best scores and what kept it under 8, and ask whether to try new directions.

## 4. Build the pick

Build it natively in the real component, on the UI thread, with the platform's native control
where one exists. Extend the design system's primitive rather than forking a one-off when the
effect belongs to a shared control. Run the project's lint, typecheck and tests.

## 5. Capture and score the build

Same gestures, both judges, all six rules. Done means 8 or higher on every rule and overall with
**both** judges. A build that loses smoothness to the effect is not done: fix it with the
`smoothit` diagnosis. At most three rounds, then report what still falls short.

## 6. Report

- The baseline and final tables, both judges' columns, one line per rule.
- Which mock was built and what changed, with `file:line` references.
- The before and after recordings.
- Anything the simulator could not prove (rule 5) and what the user should check on the phone.
