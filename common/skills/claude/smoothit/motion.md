# Motion: definition, capture and judging

Shared by `smoothit` and `aliveit`. Both skills read this file; neither restates it.

## The definition

**Smooth** is how an interaction feels. It is measurable.

1. **Instant**: something visibly changes on the first frame after touch-down (8 to 16 ms),
   not on release.
2. **Attached**: while dragging, what is dragged stays under the finger every frame. No lag
   behind the finger, no snapping between positions mid-gesture.
3. **Continuous**: nothing pops in, pops out or teleports. Every element travels from where it
   was to where it goes.
4. **Physical**: springs, not fixed-duration timers. Release carries the finger's velocity, the
   settle has no hard stop, and an animation grabbed midway continues from where it is.
5. **No dropped frames**: holds the display's full rate (120 Hz on ProMotion) while the next
   screen mounts, data loads or anything else happens behind it.

**Alive** is how it looks while it moves. It is taste.

6. **Alive**: the control reacts like a material: it magnifies, stretches with velocity,
   refracts or flexes, so the motion reads as a physical response to the finger.

Alive is only ever motion during an interaction. Everything comes to rest when the finger
leaves; nothing loops, pulses or shimmers while idle (that pegs the GPU and heats the phone).

The reference is Apple's iOS 26 tab bar as WhatsApp ships it: a glass lens on press that
follows the finger across tabs, magnifies the icon under it, and shrinks back into the
selection pill on release. A simulator capture of Apple's bar through this pipeline scored 9
(opus) and 8 (gpt-6.1-sol), so the pipeline can recognise the real thing.

## Score scale

Each judge scores every rule in scope from 0 to 10 and gives one overall score.

| Score | Means |
| --- | --- |
| 10 | Indistinguishable from Apple's best system controls. |
| 8-9 | Ship it. Nothing a user would notice; a frame-by-frame look finds only nitpicks. |
| 6-7 | Works, but a user feels it: a late start, a visible snap, a timer-shaped settle. |
| 3-5 | Clearly dull or janky: pops, lag behind the finger, hitches during transitions. |
| 0-2 | Broken: no feedback, frozen frames, or motion that fights the finger. |

The overall score is the judge's own judgement, not an average, and it can be no higher than
the lowest rule score plus 1. One bad hitch spoils an otherwise perfect interaction.

**The bar is 8.** Anything shown to the user, and anything called done, needs an overall 8 or
higher from **both** judges.

## Capture

Judges score evidence, never a description. Every capture produces a video, a gesture timeline
and a motion report.

**The gestures**, the same every time so captures compare: a tap, a press and hold, a slow drag,
a fast flick, and an interrupt (grab or tap the control while it is still settling). Write down
when each one starts and ends (a timeline): judges need it, and motion that never happened has
no other trace.

**Getting the app running** is the project's job, not this file's: use the project's run skill
or notes (scratch database, ports, sign-in) and leave other sessions' servers and devices alone.

**Keep the simulator signed in.** Use one dedicated simulator for motion work and reuse it: across
rounds and across runs, never erase it, reinstall the app or sign out. Between rounds, load new
code by reloading the JavaScript bundle (Metro's reload, or reopening the dev URL), not by a cold
reinstall, and confirm the simulator runs the new bundle before recording. When you finish,
shut the simulator down (it keeps its sign-in) and record its name and UDID where the project
keeps such notes, so the next run boots it instead of building a new one. A running simulator
costs the whole machine CPU, and a starved machine records hitches that are not there; check
the load before a capture (`uptime`). With the one-minute load above the machine's core count,
wait or find what is busy; when it is not yours to stop, say so in the judges' packet.

**Sources:**

- **iPhone** (the only source for rule 5): a screen recording made on the device. Ask the user
  to record when the change needs a device; say exactly which gestures to perform. For a hard
  rule 5 number, record the device over the cable with Instruments' Animation Hitches template
  (`xcrun xctrace record --template 'Animation Hitches' --device <udid> --attach <app>`).
- **iOS simulator**: `xcrun simctl io <udid> recordVideo --codec hevc <file>.mp4` while UI
  automation plays the gestures. The h264 encoder fell to about 13 fps on a loaded Mac, below
  what rule 3 needs; hevc kept 60. Trust it for rules 1 to 4 and 6, never for rule 5 (it renders on
  the Mac's GPU). Its limits:
  - The recording shows no touches, so the timeline is the only record of where the finger was.
    Build it from the automation's own timestamps (Maestro: `--debug-output`, `commands.json`).
  - Maestro taps, long-presses and swipes, but cannot press, hold and then drag, and a second
    tap lands well after the first settles, so it cannot interrupt. XCUITest's
    `press(forDuration:thenDragTo:)` can hold then drag. When no tool can interrupt, say so and
    let the judges score interruption from the code.
- **HTML mocks**: `record-mock.mjs` beside this file, run from a directory where Playwright is
  installed. The mock marks its touch targets with `data-target` (added alongside whatever
  attributes the mock already uses), and the recorder plays the five gestures on them, draws a
  touch dot, and writes `video.webm` and `timeline.tsv`. Playwright video runs at about 25 fps:
  good for continuity and look, not for rule 5.

**Report:**

```bash
~/.claude/skills/smoothit/motion-report.sh <video> <out-dir> --crop W:H:X:Y --timeline <timeline.tsv>
```

- `--crop` the control plus some room around it (a tab bar: the bottom 160 pt). A small control
  is unreadable on a full-screen sheet. The crop keeps the recording's own frame timing; a plain
  re-encode of a simulator recording drifts every time in the report.
- `--timeline` takes tab-separated `start  end  label` lines in seconds from the video's start,
  and adds one sheet per gesture (`gesture-NN.png`, 10 fps): a gesture that got no response has
  no motion, so without it the most damning evidence has no sheet.
- It also writes one sheet per burst of motion (`sheet-NN.png`, 30 fps), `sheets.txt` naming the
  window of every sheet, and `report.txt` with the hitches: a gap of 50 ms or more, or 3+ frozen
  frames while something moves. Two-frame pauses are listed but not counted; in a drag they are
  usually the finger. Apple's tab bar shows 2 hitches and 5 pauses over 10 segments, so counts
  are evidence, not a verdict.

## Pre-check before judging

A judging round costs minutes, so do not spend one on work that visibly is not ready. Before
calling the judges on anything you changed (a fix, a build, a revised mock), read `report.txt`
against the timeline and open the frames around every flagged hitch:

- A hitch inside a gesture, or in the 600 ms settle after it, where the frames show **the
  control itself** freezing or jumping: not ready. Fix it and capture again.
- A gesture whose sheet shows no response where the change should give one: not ready.
- A hitch where the control is at rest, or where only the content behind it changes (a screen
  switch under a settled bar): pass it to the judges. Apple's own tab bar shows two of these.

This is a gate, not a score: write down what you saw and why it blocked the round, and never
put a number on it. A blocked round does not count toward the three. After three blocked
captures in a row, call the judges anyway and let their scores say how far off it is.
Baselines and the native control are never pre-checked: they are scored as they are.

## The judges

You never score anything yourself. Two judges score independently, both on high effort,
launched in the same turn so they run in parallel:

- **opus-5.5**: `Agent`, `model: 'opus'`, `effort: 'high'`, label `judge:opus-<topic>`. It reads
  the images itself with the Read tool. The Agent tool takes no schema, so the JSON shape is in
  the prompt; save its reply to a file.
- **gpt-6.1-sol**: `codex-runner`, label `gpt-6.1-sol:judge-<topic>`, `--mode judge
  --effort high`, one `--image FILE` flag per sheet, each written out in full. Check its summary
  says `CODEX_MODEL=gpt-6.1-sol`. If the runner has not handed back after the run finished, read
  the result yourself: `~/.claude/bin/codex-run.sh status --id <id>`, then `report.md` in the run
  directory. gpt-6.1-sol only ever judges in these skills; it never creates a mock, writes a fix
  or edits a file.

Each judge gets the same packet and nothing else: the right prompt below, the sheets,
`sheets.txt`, `report.txt`, the timeline and, when judging code or a mock, the paths of its
source files. Never pass along your own opinion, the creator's reasoning, or the other judge's
scores. A judge that knows the expected answer stops being a judge.

### Prompt for a capture of the app (rules 1 to 6, or the subset in scope)

```
You are judging the motion of a UI interaction you did not build. Score only what the
evidence shows. If something cannot be seen in the frames, say so rather than guessing.

What it is: [one line: the screen and the control]. Captured on [device or simulator, recorder,
frame rate], cropped to [what].
Gestures, in order (times in [timeline file], seconds from the start of the video): [list].
[Anything the capture could not do, such as "the interrupt did not interrupt", and what the
judge should use instead.]
Rules in scope, with the score scale: [paste the rules from "The definition" and "Score scale"].
Evidence: motion sheets sheet-NN.png and gesture sheets gesture-NN.png (sheets.txt gives each
one's window and frame rate; frames read left to right, top to bottom), report.txt,
[source files, if any].

For each rule: a score from 0 to 10, the frames that justify it (sheet and position, or the
time from report.txt), and for any score under 8 the concrete change that would raise it.
Then an overall score (no higher than your lowest rule score plus 1) and one sentence on the
single biggest problem. Do not edit any files.

Reply as JSON only:
{"rules": [{"rule": "instant", "score": 0, "evidence": "", "fix": ""}],
 "overall": 0, "biggest_problem": ""}
```

### Prompt for an HTML mock (rules 3, 4, 6 and fit)

A browser says nothing true about rules 1, 2 and 5, so a mock is scored on continuous,
physical, alive and **fit**: does it look like it belongs to this product, not like a demo of
an effect. Fit is judged against the product itself, so the packet adds a screenshot of the real
screen the control sits on, and the design system's tokens and component catalog when the
project has them.

```
You are judging an interactive HTML motion mock you did not build. Score only what the
evidence shows. If something cannot be seen in the frames, say so rather than guessing.

What it is: a mock of [the control] in [product], at [viewport], recorded in headless Chromium
by Playwright at about 25 fps and cropped to [what]. The red translucent dot is the recorder's
touch indicator, drawn while the pointer is down; it is not part of the mock.
Gestures, in order (times in timeline.tsv): tap; press and hold 1.5 s; slow drag 1.6 s; fast
flick 150 ms; interrupt (drag, reverse, release, tap again while it settles).
Rules in scope: 3 Continuous, 4 Physical, 6 Alive [paste them], and Fit: does it look like it
belongs to the product, judged against [screenshot of the real screen], [tokens file],
[component catalog]. Score scale: [paste "Score scale"].
Evidence: sheet-NN.png and gesture-NN.png (sheets.txt gives each one's window), report.txt,
timeline.tsv, and the mock's source, [mock.html].

[Same scoring paragraph and JSON reply as the capture prompt, with rules "continuous",
"physical", "alive" and "fit".]
```

## Merging the scores

Put both judges side by side; do not average them away.

```md
| Rule | opus | sol | Notes |
| --- | --- | --- | --- |
| Instant | 9 | 8 | |
| Attached | 5 | 6 | both: lens trails the finger by ~3 frames on the fast drag (sheet-03) |
| **Overall** | **6** | **6** | |
```

- The gate uses each judge's own overall score: 8 or higher from both, or it does not pass.
- When the judges differ by 3 or more on a rule, open the frames they cite and say which one
  the evidence supports, without changing either score.
- A fix one judge proposes is a lead, not an instruction. Check it against the code first.
- When work goes back for another round, send both judges' notes. You may add what you see in
  the frames yourself (the cause the judges are circling, say), marked as your observation. That
  is diagnosis, not scoring: you still never give or change a score.
