---
name: smoothit
description: Make a UI interaction feel smooth. Records it, has opus and gpt-6.1-sol judges score it against the motion definition (instant, attached, continuous, physical, no dropped frames), fixes the causes in code, and proves the fix with a second scored recording. Use when the user types /smoothit or says a screen, control or gesture feels dull, laggy, janky, stiff or not smooth. For making it look alive (glass, stretch, magnify), use aliveit.
---

# smoothit

The user named an interaction that feels dull. Make it feel right without changing how it
looks. Read `motion.md` beside this file first: it holds the definition (rules 1 to 5 are this
skill's scope), the score scale, how to capture and how the judges run.

You do not score anything yourself, and gpt-6.1-sol only judges. You, or an opus agent for a
large change, write every fix.

## 1. Pin down the interaction

Name the screen, the control and the gestures (tap, hold, drag, flick, interrupt) in one line,
and find the code that draws it. If the request is vague ("the session screen"), pick the
interaction that matters most and say which.

Check whether the platform already ships the control (the iOS 26 system tab bar, native sheets,
native navigation transitions). A native control beats a recreation on every rule; if one
exists and switching to it changes how the product looks, ask the user before going further.

## 2. Capture before

Capture it as `motion.md` describes: the five gestures with a timeline, then `motion-report.sh`
cropped to the control. When rule 5 matters and the
only honest source is the user's phone, ask them for a recording with the exact gestures, and
carry on with rules 1 to 4 from the simulator meanwhile.

## 3. Score before

Run both judges on rules 1 to 5 and merge the table. This is the baseline.

## 4. Diagnose

For every rule under 8, find the cause in code, not in the symptoms. The usual ones:

- Feedback waits for release: `onPress` where `onPressIn` or a gesture's `onBegin` belongs.
- Motion on the JS thread: `Animated` without the native driver, `setState` per frame, layout
  driven by React renders. Move it to the UI thread (Reanimated worklets and shared values,
  `react-native-gesture-handler`; on web, transforms and opacity only, no layout properties).
- Timers where springs belong: `withTiming` or CSS durations for anything the finger moved.
  Release with `withSpring` carrying the gesture's velocity.
- State that jumps: a value swapped instead of animated, a list that re-keys, a conditional
  mount without an entering animation, a measurement that lands a frame late.
- Work during the gesture: a screen mounting, a query resolving or a large re-render while the
  animation runs. Defer it until the motion settles, or keep the screen mounted.
- Not interruptible: an animation that has to finish before the next gesture registers.
- No gesture at all: each part is its own button, so a drag across the control does nothing.
  That needs one gesture over the whole control, which changes how it behaves; when the user
  asked for smoothness alone, say so and confirm before building it.

## 5. Fix

Change only what the diagnosis found. The interaction must look the same at rest. Run the
project's lint, typecheck and tests.

## 6. Capture and score after

Same gestures, same capture setup, same judges, fresh packet. Done means every rule in scope
scores 8 or higher with **both** judges and the overall is 8 or higher with both. Otherwise go
back to 4 with the judges' notes, at most three rounds, then report what still falls short and
why.

## 7. Report

- The before and after table, both judges' columns, one line per rule.
- What caused each failure and what changed, with `file:line` references.
- The before and after recordings (a side-by-side clip when the project's workflow wants one).
- Anything the simulator could not prove (rule 5) and what the user should check on the phone.
