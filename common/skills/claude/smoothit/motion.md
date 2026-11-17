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
selection pill on release.

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

Judges score evidence, never a description. Every capture produces a video and a motion report.

- **iPhone** (the only source for rule 5): a screen recording made on the device. Ask the user
  to record when the change needs a device; say exactly which gestures to perform. For a hard
  rule 5 number, record the device over the cable with Instruments' Animation Hitches template
  (`xcrun xctrace record --template 'Animation Hitches' --device <udid> --attach <app>`).
- **iOS simulator**: `xcrun simctl io booted recordVideo --codec h264 <file>.mp4`, gestures
  driven by the project's UI automation (Maestro, XCUITest). Show touches first, so judges can
  see the touch-down frame: `defaults write com.apple.iphonesimulator ShowSingleTouches 1`,
  then restart Simulator. A simulator runs on the Mac's GPU: trust it for rules 1 to 4 and 6,
  never for rule 5.
- **Browser and HTML mocks**: Playwright's `recordVideo` at the size the page is meant to be
  seen at (a phone viewport for mobile mocks), gestures driven with `page.mouse` down, move in
  small steps, up. Playwright video runs at about 25 fps: good for continuity and look, not for
  rule 5.

Perform the same gestures every time, before and after, so captures compare: a tap, a press
and hold, a slow drag, a fast flick, and a gesture interrupted midway.

Then turn the video into what judges read:

```bash
~/.claude/skills/smoothit/motion-report.sh <video> <out-dir>
```

It writes one contact sheet per burst of motion (`sheet-NN.png`, sampled at 30 fps, read left
to right and top to bottom), `sheets.txt` with the time each sheet covers, and `report.txt`
with every motion segment and the hitches inside it: a gap of 50 ms or more, or 3+ frozen frames
while something moves. Two-frame pauses are listed but not counted; in a drag they are usually
the finger. The reference tab bar shows 2 hitches and 5 pauses over 10 segments, so counts are
evidence, not a verdict.

## The judges

You never score anything yourself. Two judges score independently, both on high effort,
launched in the same turn so they run in parallel:

- **opus-5.5**: `Agent`, `model: 'opus'`, `effort: 'high'`, label `judge:opus-<topic>`. It reads
  the images itself with the Read tool.
- **gpt-6.1-sol**: `codex-runner`, label `gpt-6.1-sol:judge-<topic>`, `--mode judge
  --effort high`, one `--image` per contact sheet. Check its summary says
  `CODEX_MODEL=gpt-6.1-sol`. gpt-6.1-sol only ever judges in these skills; it never creates a
  mock, writes a fix or edits a file.

Each judge gets the same packet and nothing else: the judge prompt below, the contact sheets,
`sheets.txt`, `report.txt`, the rules in scope and, when judging code or a mock, the paths of
its source files. Never pass along your own opinion, the creator's reasoning, or the other
judge's scores. A judge that knows the expected answer stops being a judge.

Judge prompt (fill in the brackets):

```
You are judging the motion of a UI interaction you did not build. Score only what the
evidence shows. If something cannot be seen in the frames, say so rather than guessing.

What it is: [one line: the screen, the control, the gestures performed in the capture].
Rules in scope, with the score scale: [paste "The definition" for the rules in scope, and
"Score scale"].
Evidence: contact sheets [list files] (each covers the times in sheets.txt, frames read left to
right, top to bottom, sampled at 30 fps), the frame report report.txt, [source files, if any].

For each rule: a score from 0 to 10, the frames that justify it (sheet and position, or the
time from report.txt), and for any score under 8 the concrete change that would raise it.
Then an overall score (no higher than your lowest rule score plus 1) and one sentence on the
single biggest problem. Do not edit any files.

Reply as JSON only:
{"rules": [{"rule": "instant", "score": 0, "evidence": "", "fix": ""}],
 "overall": 0, "biggest_problem": ""}
```

Give the opus judge that JSON shape as its `schema`. Ask gpt-6.1-sol for the same JSON in its
report and parse it.

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
