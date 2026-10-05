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

## Prerequisites

`ffmpeg -version` must work for the window and macOS recipes. If it is missing, tell the user
(`winget install Gyan.FFmpeg`, `brew install ffmpeg`) and stop; do not improvise a recorder.
