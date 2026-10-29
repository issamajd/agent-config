---
name: ios-energy-profile
description: >-
  Measure why an iOS app heats the phone or drains the battery, on Majd's iPhone over the cable
  with Instruments (per-process CPU, display activity, thermal state), then measure again after a
  fix. Use when the user reports the phone getting hot, battery drain, "the app uses too much
  battery", or asks to measure an app's energy use before and after a change. Not for UI jank on
  its own.
---

# iOS energy profile

The scripts sit beside this file (`~/.claude/skills/ios-energy-profile/`). They worked on
2026-10-29 with Xcode 27.1 against an iPhone 18 Pro Max on iOS 27.

## 1. Measure the phone, not the simulator

The simulator misses what makes a phone hot. It has no push token, no GPU or battery model, and a
different OS version. The coachak push loop used 1.4% CPU in the simulator and ~70% on the phone.
Start on the device; use the simulator only to compare experiments (step 6).

Device prerequisites, once per phone:

1. Plugged in by cable and unlocked. `xcrun devicectl list devices` shows it `available (paired)`.
2. Developer Mode on (Settings → Privacy & Security → Developer Mode, then restart). Without it,
   `devicectl device info ddiServices` errors with "Developer Mode is turned off".
3. xctrace lists it under `== Devices ==`, not `Devices Offline`
   (`xcrun xctrace list devices`). If it is offline or recording says "Waiting for device to
   boot", ask the user to open Xcode → Window → Devices and Simulators (Shift-Cmd-2) and select
   the phone until it mirrors. You cannot click Xcode yourself: osascript has no accessibility
   permission here.

A TestFlight or App Store build is fine. This method samples every process system-wide, so it
needs no debuggable build and no code signing. There is no local signing identity on this Mac, so a
fixed build reaches the phone only through EAS → TestFlight.

## 2. Record a scripted session

Start the recording in the background, then give the user timed steps:

```bash
~/.claude/skills/ios-energy-profile/record.sh <scratchpad>/before.trace 10m
```

Ask the user to (adjust to the app):

1. Open the app on its main screen and leave it **untouched for ~1 min**: idle cost.
2. Use it normally **~1.5 min**: interaction cost.
3. Scroll **Instagram ~1 min**: a reference for what a normal app costs on this phone.
4. Lock the phone and say done.

Then stop it: `pkill -INT -f "xctrace record"`. The trace still saves (the command exits 1 on
interrupt; that is fine). Keep the conditions the same for the after run: notifications
allowed or not, signed in, same screens. Deleting and reinstalling the app resets the
notification permission on iOS, which alone can hide a push bug.

## 3. Read it

```bash
python3 -I ~/.claude/skills/ios-energy-profile/analyze.py <trace> <AppProcessName> securityd backboardd
```

- **Top processes per 10 s.** The CPU is % of one core. `swaps/s` is display surface swaps: 0
  means nothing on screen changed, so app CPU there is work the user cannot see.
- **Named processes.** Watch the app, plus `securityd` (keychain: high when the app reads
  SecureStore in a loop) and `backboardd` (compositor: high with heavy blur, shadows or
  animation). Ignore `cfprefsd`, `MTLCompilerService`, `TGOnDeviceInference*`, `SetStoreUpdate*`;
  they are system noise and show up with every app.
- **Thermal state.** Nominal → Fair → Serious → Critical. The cable charges the phone, which adds
  heat, so compare runs made under the same conditions.

The `ProcessSubsystemPowerImpact` and `SystemPowerLevel` tables export empty or zero over the
cable. Do not rely on them.

## 4. Check the server too

A busy idle app is often a request loop. For coachak, count staging requests per route for the
window:

```bash
ssh stage-vps 'docker logs --since 40m coachak-staging-api-1 2>&1 | grep -o "\"method\":\"[A-Z]*\"},\"route\":\"[^\"]*\"" | sort | uniq -c | sort -rn | head'
```

One route with thousands of calls is the bug. In 2026-10-29's case it was
`PUT /push/installations`, 46,544 in 40 minutes.

## 5. Report before and after

Use the same steps and the same table: app CPU idle and in use, `securityd`, thermal state,
the request count, and Instagram as the reference. Put the table in the PR description.

## 6. Simulator experiments (optional)

For A/B tests of rendering changes (blur, lists, animations) without a TestFlight round trip,
build a Release simulator app and sample CPU over a fixed window:

```bash
~/.claude/skills/ios-energy-profile/sim-cpu.sh <sim-udid> <executable> 30 "label"
```

It reports the app's CPU and the simulator compositor's CPU. Drive the same interaction each
time with Maestro (`JAVA_HOME=/opt/homebrew/opt/openjdk@21 ~/.maestro/bin/maestro --device
<udid> test flow.yaml`). For an Expo app in a pnpm worktree: `npx expo prebuild -p ios
--no-install`, `pod install`, then `xcodebuild -configuration Release -sdk iphonesimulator` with
`NODE_PATH=<repo>/node_modules/.pnpm/node_modules` set, or bundling fails on a missing
`@babel/plugin-transform-react-jsx`. The first build takes ~30 min on this Air. Keep
`-derivedDataPath` outside the repo, so an EAS upload does not include it.
