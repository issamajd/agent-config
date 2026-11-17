---
name: aliveit
description: Make a UI interaction look alive: glass, stretch, magnify, a material response to the finger like the iOS 26 tab bar. Checks for a native control first, scores the current interaction with opus and gpt-6.1-sol judges, has opus agents build motion mocks, shows the user only mocks both judges score 8/10 or higher, then builds the pick and scores it again. Use when the user types /aliveit or says something looks flat, static, lifeless or not premium. For lag and jank alone, use smoothit.
---

# aliveit

The user named an interaction that looks flat. Give it a physical, material response to the
finger. Read `~/.claude/skills/smoothit/motion.md` first: it holds the definition (all six rules
apply here), the score scale, how to capture and how the judges run.

When the user asked for `smoothit` as well, this skill's mocks come first: pick the look, then
make it smooth.

You do not score anything yourself. Opus agents create the mocks. gpt-6.1-sol only judges; it
never creates a mock or writes code. Nothing in the real component changes until the user has
picked a mock.

## 1. Pin down the interaction, and check for a native control

Name the screen, the control and the gestures in one line, and find the code that draws it.

Then ask whether the platform already ships this behaviour: the iOS 26+ system tab bar (in Expo,
`expo-router/unstable-native-tabs`), native sheets, native navigation transitions. If it does,
capture the native control and have both judges score it like any capture. Then put the choice
to the user before any mock, with those scores and what native would cost (custom pieces of the
control it cannot keep, the product's own look, Android parity). Mocks are only for the custom
path. If the user already chose, skip the question.

## 2. Capture, score and diagnose

Capture the current interaction as `motion.md` describes and have both judges score rules 1
to 6. This is the baseline.

For every one of rules 1 to 5 under 8, find the cause in code with `smoothit`'s diagnosis list
(step 4 there), but change nothing. A flat control usually fails 2, 3 and 4 because it has no
gesture at all, and the new effect replaces its motion anyway, so the diagnosis goes into the
mock brief and the build instead of into a fix now.

## 3. Mocks

Spawn three opus agents in one turn (`Agent`, `model: 'opus'`), one per direction, each told to
make one distinct take, not a variant of another's. Give each:

- The interaction, the baseline sheets, the judges' notes on rule 6 and the diagnosis.
- The definition from `motion.md`, including the rule that everything rests when idle.
- The project's design system: its tokens and component catalog when it has one. The mock must
  look like the product, not like a demo of an effect. Without one, the user's standing visual
  constraints apply.
- What sits behind the control: a screenshot of the real screen it lives on, used as the mock's
  backdrop. Glass reads differently over a near-white screen than over a photo; judge it where
  it will live.
- The format: one self-contained HTML file at the size the control is seen at (a phone viewport
  for mobile), driven by real pointer events, springs rather than CSS durations, touch targets
  marked `data-target` in order. When the real screen has a constraint the effect must cover,
  such as the time the next screen takes to build, the mock takes a control for it. With it: one line on the gestures that show it off, and a
  native build note (how the build would do the same on the platform, such as a Skia shader for
  a lens). HTML fakes refraction with tricks the build will not use; the note keeps a mock from
  passing on something the build cannot make.

Then judge them:

1. Record every mock with `record-mock.mjs` and run `motion-report.sh` on each, cropped to the
   control, with the timeline (see `motion.md`).
2. Run both judges on each mock with the mock prompt from `motion.md`: rules 3, 4 and 6 plus fit,
   with the real screen's screenshot, the tokens and the catalog as the fit reference, and the
   mock's HTML as its source.
3. A mock with an overall under 8 from either judge goes back to the opus agent that made it,
   with both judges' notes and any observation of your own from the frames (send to the same
   agent so it keeps its context). Record the revision, run the pre-check from `motion.md`, and
   judge it with a fresh packet only once it passes. At most
   three rounds per mock.

**The user only ever sees mocks with an overall of 8 or higher from both judges.** Publish
those with the `html-communication` skill: each mock live and playable, its gestures, and both
judges' tables. A mock that missed may be named with its best scores and what kept it under 8,
never shown playable. Then stop and wait for a pick.

Without the Artifact tool (a headless or scripted run), write the same page as a local folder
(the page plus each mock beside it), give its path, and end the run with the open questions;
whoever started the run publishes it.

If no mock passes after three rounds, do not show any of them. Tell the user none passed, give
each one's best scores and what kept it under 8, and ask whether to try new directions.

## 4. Build the pick

Build it in the real component, on the UI thread, following the mock's native build note and
fixing everything step 2's diagnosis found. Extend the design system's primitive rather than
forking a one-off when the effect belongs to a shared control. Run the project's lint,
typecheck and tests.

## 5. Capture and score the build

Same gestures, on the simulator, and on the phone for rule 5. Run the pre-check from `motion.md`
on every capture, then both judges on all six rules once it passes. Done
means 8 or higher on every rule and overall with **both** judges. A build that loses smoothness
to the effect is not done: fix it with `smoothit`'s diagnosis. At most three rounds, then
report what still falls short.

## 6. Report

- The baseline and final tables, both judges' columns, one line per rule.
- Which mock was built and what changed, with `file:line` references.
- The before and after recordings.
- Anything the simulator could not prove (rule 5) and what the user should check on the phone.
