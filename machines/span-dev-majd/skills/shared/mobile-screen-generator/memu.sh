# adb helpers for driving and recording the ITMS app on MEmu. Source it from Git Bash:
#   . ~/.claude/skills/mobile-screen-generator/memu.sh
#   restart_app; login; tap 270 797; waitfor "'Assign Key'"; typ ZTC1B; key 111; shot step1
#   rec_start my-flow; ...; rec_stop my-flow          # videos land in $MEMU_OUT
# Coordinates are for MEmu at 720x1280; find a control's bounds with `ui | grep <text>`. A
# TabView's header strip scrolls once a later tab is selected, so re-read tab bounds after that.
# A snackbar stays about 3 s: sleep 5 after the action that shows it, or a recording misses it.
# Traps (machine notes, Android emulator): adb kill-server drops adb reverse; -t:Run relaunches the
# app after the build returns; a server restart or a test-client login ends the device session.

export MSYS_NO_PATHCONV=1
ADB="${ADB:-/c/Program Files (x86)/Android/android-sdk/platform-tools/adb.exe}"
SERIAL="${SERIAL:-127.0.0.1:21503}"
PKG="${PKG:-com.span.client.mobile.itms.maui}"
# adb.exe gets paths unconverted (MSYS_NO_PATHCONV), so MEMU_OUT must be a Windows path (C:/...).
MEMU_OUT="${MEMU_OUT:-$(cygpath -m "${TMPDIR:-/tmp}/memu" 2>/dev/null || echo "${TMPDIR:-/tmp}/memu")}"
MEMU_USER="${MEMU_USER:-admin}"
# The app user's password comes from the caller: export MEMU_PASSWORD=<password> before login.
mkdir -p "$MEMU_OUT"

a() { timeout 30 "$ADB" -s "$SERIAL" "$@"; }
tap() { a shell input tap "$1" "$2"; sleep "${3:-1}"; }
typ() { a shell input text "$1"; sleep 0.5; }
key() { a shell input keyevent "$1"; sleep 0.5; }   # 111 Escape (hides the keyboard), 67 Backspace, 123 End, 4 Back
shot() { a exec-out screencap -p > "$MEMU_OUT/${1:-screen}.png"; echo "$MEMU_OUT/${1:-screen}.png"; }

# Prints every node with text, description or id: class 'text' 'desc' id [x1,y1][x2,y2]. About 3 s per call.
ui() {
  a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  a shell cat /sdcard/ui.xml | python -c "
import sys, re
for m in re.finditer(r'<node [^>]*>', sys.stdin.read()):
    n = m.group(0)
    g = lambda k: re.search(k + r'=\"([^\"]*)\"', n).group(1)
    if g(' text') or g('content-desc') or g('resource-id'):
        print(g('class').split('.')[-1], repr(g(' text')), repr(g('content-desc')), g('resource-id'), g('bounds'))
"
}

# Waits (up to ~60 s) until a node matching the pattern is on screen, e.g. waitfor "'Confirm Case ID'".
waitfor() { for _ in $(seq 1 20); do ui | grep -q "$1" && { sleep 1.5; return 0; }; sleep 1; done; echo "waitfor: $1 not found" >&2; return 1; }

restart_app() {
  a shell am force-stop "$PKG"; sleep 1
  a shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 6
  a reverse --list | grep -q 8001 || a reverse tcp:8001 tcp:8001
}

# Signs in from the login screen and waits for the Operations menu; retries, dismissing the
# "Update Available" screen and error dialogs on the way.
login() {
  [ -n "$MEMU_PASSWORD" ] || { echo "login: set MEMU_PASSWORD first" >&2; return 1; }
  for _ in 1 2 3 4; do
    for _ in $(seq 1 15); do
      d=$(ui)
      echo "$d" | grep -q "'Maybe Later'" && { tap 360 812 2; continue; }
      echo "$d" | grep -q "'Operations'" && return 0
      echo "$d" | grep -q "'Sign In'" && break
      sleep 2
    done
    tap 587 311; tap 400 311; typ "$MEMU_USER"; tap 380 420; typ "$MEMU_PASSWORD"; key 111
    tap 360 1132 10
    for _ in $(seq 1 8); do
      d=$(ui)
      echo "$d" | grep -q "'Maybe Later'" && tap 360 812 2
      echo "$d" | grep -q "'Operations'" && return 0
      sleep 2
    done
    ui | grep -q "'OK'" && tap 563 732
  done
  echo "login failed" >&2; return 1
}

# screenrecord runs on the device (3 minutes at most); rec_stop ends it and pulls the mp4.
rec_start() { a shell rm -f "/sdcard/$1.mp4"; ( timeout 200 "$ADB" -s "$SERIAL" shell screenrecord --bit-rate 4000000 --time-limit 180 "/sdcard/$1.mp4" >/dev/null 2>&1 & ); sleep 2; }
rec_stop() { sleep 2; a shell pkill -INT screenrecord; sleep 3; a pull "/sdcard/$1.mp4" "$MEMU_OUT/$1.mp4" >/dev/null && a shell rm -f "/sdcard/$1.mp4"; echo "$MEMU_OUT/$1.mp4"; }

# One contact sheet (6 x 4 frames) of a recording, to check it without watching it.
sheet() { local d; d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"); ffmpeg -y -loglevel error -i "$1" -vf "fps=24/$d,scale=180:-1,tile=6x4" -frames:v 1 "${1%.mp4}-sheet.png"; echo "${1%.mp4}-sheet.png"; }
