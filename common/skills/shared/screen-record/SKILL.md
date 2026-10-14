---
name: screen-record
description: Record a screen recording of an Android emulator, a single desktop window or a browser tab, producing a video file for a PR. Use when the user asks to record, capture or film a test, a screen or a flow.

---

# Screen record

Produce one file, then hand it to the file-upload skill. Pick the recipe by what is being
recorded. Name the output after the flow, such as `login-flow.mp4`; file-upload slugs it.

Before recording, say what you are about to capture and for how long. Keep clips short:
under 30 seconds makes a good GIF preview, and GitHub caps video at 10 MB on free plans.

## Android device or emulator (MEmu is Windows only)

Record on the device, not the desktop. Nothing else on screen gets in, and the window can be
covered. The adb path and device serial come from the machine notes.

```bash
adb -s <serial> shell screenrecord --time-limit 60 /sdcard/<name>.mp4
adb -s <serial> pull /sdcard/<name>.mp4 <local-path>
adb -s <serial> shell rm /sdcard/<name>.mp4
```

From Git Bash on Windows, set `MSYS_NO_PATHCONV=1` first, or `/sdcard/...` is rewritten to a
Windows path and screenrecord fails with "Must specify output file".

Three minutes is the hard cap per call. To stop early, run `adb shell pkill -INT screenrecord`
and the file is still valid. If screenrecord reports a missing encoder, fall back to the
window recipe below.

## One desktop window (Windows)

ffmpeg's `gdigrab` captures a single window by its exact title. Get the title with:

```powershell
Get-Process | Where-Object MainWindowTitle | Select-Object ProcessName, MainWindowTitle
```

```bash
ffmpeg -f gdigrab -framerate 15 -i title="<exact window title>" -t <seconds> \
  -vf "scale=1280:-2" -c:v libx264 -preset veryfast -pix_fmt yuv420p <name>.mp4
```

The window must be in front and not minimised; anything covering it is recorded too.
`-i desktop` records every monitor, so use it only when the user asks for the whole screen.

## Screen region (macOS)

ffmpeg cannot pick a window on macOS. Use the built-in recorder for a timed capture, then crop
to the window's bounds if needed:

```bash
screencapture -v -V <seconds> <name>.mov
ffmpeg -i <name>.mov -vf "crop=<w>:<h>:<x>:<y>" <name>.mp4
```

The window bounds come from `osascript -e 'tell application "System Events" to get {position,
size} of first window of process "<App>"'`. file-upload accepts `.mov` as is, so skip the crop
when the whole screen is fine.

## Browser tab (Claude only)

The Claude in Chrome extension records the tab it is driving and exports a GIF with click
markers, through a browser download the user must approve. Use it when the recording is of
Claude's own actions in a tab; it is a GIF, so it is already embeddable and needs no preview.
For a human's session in a browser, record the browser window with the recipe for the OS.
If the extension is not connected, use the Playwright recipe below instead of asking.

## Browser flow (Playwright, any OS)

Use this for a web app flow when the Chrome extension is not connected, or when the clip
should double as a check. It drives a real headless Chromium, records only the page, works
the same on macOS and Windows, and needs neither ffmpeg nor the extension. Install it in a
scratch directory, never in the project:

```bash
npm init -y && npm i playwright@1.64.1 && npx playwright install chromium
```

```js
import { chromium, expect } from 'playwright/test';
const browser = await chromium.launch();
const viewport = { width: 1280, height: 800 };
const context = await browser.newContext({ viewport, recordVideo: { dir: 'videos', size: viewport } });
const page = await context.newPage();
// Drive the flow and assert each step with expect(); pause ~1s between steps so it reads.
await context.close(); // the video is written on close
await page.video().saveAs('videos/<name>.webm');
await browser.close();
```

- Assert as you go (`await expect(...).toBeVisible()`), so a clip that finishes is also a
  passing run. Fail on `pageerror`, and on any `dialog` (handle it, or the page blocks).
- After a sign-in redirect, wait for a heading or other content rather than `waitForURL`:
  an app that routes client-side after the callback never fires the load it waits for.
- To show states the local data cannot reach, stub the API with `page.route(...)` and put
  "stubbed" in the file name and the PR text so no one mistakes it for live data.
- Seeded test credentials only, and only against a local dev host.
- Video frames do not show you the design. Take a few `page.screenshot()`s of key states
  (both colour schemes, a phone width) and look at them before handing the clip over.
- Output is `.webm`, which GitHub plays inline; no conversion needed.

## Prerequisites

`ffmpeg -version` must work for the window and macOS recipes; the Playwright recipe does not
need it. If it is missing, tell the user
(`winget install Gyan.FFmpeg`, `brew install ffmpeg`) and stop; do not improvise a recorder.
