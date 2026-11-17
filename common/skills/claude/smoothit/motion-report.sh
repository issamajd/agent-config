#!/usr/bin/env bash
#
# motion-report.sh: turn a screen recording into what the smoothness judges
# score: contact sheets of every burst of motion and of every gesture, and a
# frame report.
#
#   motion-report.sh <video> <out-dir> [--crop W:H:X:Y] [--timeline FILE] [--fps N] [--cols N]
#
#   --crop      cut the video down to the control (plus some room around it)
#               before anything else; a 58 pt tab bar is unreadable on a
#               full-screen sheet. Frame timing is kept as recorded.
#   --timeline  one gesture per line, tab-separated: start seconds, end
#               seconds, label (record-mock.mjs writes one). Adds one sheet per
#               gesture, so a gesture that got no visible response still has
#               evidence.
#
# Writes into <out-dir>:
#   control.mp4     the cropped video (only with --crop)
#   frames.tsv      time, gap since the previous frame, motion energy
#   report.txt      motion segments and the hitches inside them
#   sheet-NN.png    one contact sheet per motion segment, frames sampled at
#                   --fps (default 30), read left to right, top to bottom
#   gesture-NN.png  one sheet per timeline gesture, at 10 fps, from 100 ms
#                   before it starts to 600 ms after it ends
#   sheets.txt      which time range, frame rate and gesture each sheet covers
#
# Motion energy is the mean luma difference from the previous frame (0 = the
# frame repeats). A hitch is motion that stops for three or more frames in a
# row, or a gap of 50 ms or more between frames while something moves. A
# two-frame stop is listed as a pause and not counted: in a drag it is usually
# the finger stopping, not the UI. iPhone screen recordings skip frames while
# the screen is still, and the recorder itself repeats a single frame now and
# then even on Apple's own controls, so a single repeated frame is ignored.
#
# Reference: Apple's iOS 26 tab bar (WhatsApp), recorded on an iPhone at 60 fps
# with taps and drags across the tabs, shows 2 hitches and 5 pauses over 10
# segments. The counts are evidence for the judges, not a verdict.

set -euo pipefail

die() { echo "motion-report: $*" >&2; exit 2; }

[ $# -ge 2 ] || die "usage: motion-report.sh <video> <out-dir> [--crop W:H:X:Y] [--timeline FILE] [--fps N] [--cols N]"
video="$1"; out="$2"; shift 2
fps=30; cols=4; crop=""; timeline=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fps)      fps="$2";      shift 2 ;;
    --cols)     cols="$2";     shift 2 ;;
    --crop)     crop="$2";     shift 2 ;;
    --timeline) timeline="$2"; shift 2 ;;
    *) die "unknown flag: $1" ;;
  esac
done
[ -f "$video" ] || die "video not found: $video"
[ -z "$timeline" ] || [ -f "$timeline" ] || die "timeline not found: $timeline"
command -v ffmpeg >/dev/null || die "ffmpeg is not on PATH"
mkdir -p "$out"
rm -f "$out"/sheet-*.png "$out"/gesture-*.png

# Simulator and phone recordings have a variable frame rate. A plain re-encode
# re-times them and every time in the report drifts from the source, so the
# crop passes each frame's timestamp through untouched (passthrough) and keeps
# the source's time base (demux). Without the second, a simulator recording's
# nominal 25/12 fps becomes the encoder's time base and every timestamp is
# rounded to 0.48 s steps.
if [ -n "$crop" ]; then
  ffmpeg -v error -y -i "$video" -vf "crop=$crop" -fps_mode passthrough -enc_time_base demux \
    -c:v libx264 -crf 12 -pix_fmt yuv420p "$out/control.mp4" </dev/null
  video="$out/control.mp4"
fi

# Energy above MOVING counts as motion; below STILL counts as a repeated frame.
MOVING=0.5
STILL=0.15

# One line per frame: time and energy. Downscaling first keeps it fast and
# ignores encoder noise.
ffmpeg -v error -i "$video" \
  -vf "scale=320:-2,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-" \
  -fps_mode passthrough -f null - \
  | paste - - \
  | sed -E 's/.*pts_time:([0-9.]+).*YAVG=([0-9.]+).*/\1 \2/' \
  | awk 'BEGIN{print "time\tgap_ms\tenergy"} {gap = NR == 1 ? 0 : ($1 - p) * 1000; printf "%.3f\t%.0f\t%.2f\n", $1, gap, $2; p = $1}' \
  > "$out/frames.tsv"

# Segments: runs of moving frames, merged across pauses shorter than 150 ms.
# Hitches: inside a segment, 3+ still frames in a row, or a frame gap >= 50 ms
# after the first moving frame (the gap before it is the screen at rest).
awk -v moving="$MOVING" -v still="$STILL" -F'\t' '
  NR == 1 { next }
  { t[++n] = $1; g[n] = $2; e[n] = $3 }
  END {
    nseg = 0
    for (i = 1; i <= n; i++) {
      if (e[i] <= moving) continue
      if (nseg > 0 && t[i] - se[nseg] < 0.15) { se[nseg] = t[i]; sl[nseg] = i }
      else { nseg++; ss[nseg] = t[i]; se[nseg] = t[i]; sf[nseg] = i; sl[nseg] = i }
    }
    printf "segments\t%d\n", nseg > "/dev/stdout"
    total = 0
    for (s = 1; s <= nseg; s++) {
      hitches = ""; count = 0; pauses = 0; run = 0
      for (i = sf[s]; i <= sl[s]; i++) {
        if (i > sf[s] && g[i] >= 50) { hitches = hitches sprintf(" gap %dms@%.3f", g[i], t[i]); count++ }
        if (e[i] < still) { run++ } else {
          if (run >= 3) { hitches = hitches sprintf(" stall %dfr@%.3f", run, t[i - run]); count++ }
          else if (run == 2) { pauses++ }
          run = 0
        }
      }
      total += count; ptotal += pauses
      printf "segment %d\t%.3f-%.3f\t%.0fms\thitches %d%s\tpauses %d\n", s, ss[s], se[s], (se[s] - ss[s]) * 1000, count, hitches, pauses
      printf "%.3f %.3f\n", ss[s], se[s] > "'"$out"'/.segments"
    }
    printf "hitches total\t%d\npauses total\t%d\n", total, ptotal
  }' "$out/frames.tsv" > "$out/report.txt"

# sheet <name> <from-seconds> <to-seconds> <fps> <label>: one contact sheet of
# that window, logged in sheets.txt.
: > "$out/sheets.txt"
sheet() {
  local name="$1" from="$2" to="$3" rate="$4" label="$5" len frames rows
  from=$(awk -v s="$from" 'BEGIN{printf "%.3f", (s < 0 ? 0 : s)}')
  len=$(awk -v f="$from" -v t="$to" 'BEGIN{printf "%.3f", t - f}')
  frames=$(awk -v l="$len" -v r="$rate" 'BEGIN{n = int(l * r + 0.999); print (n < 1 ? 1 : n)}')
  rows=$(( (frames + cols - 1) / cols ))
  ffmpeg -v error -y -ss "$from" -t "$len" -i "$video" \
    -vf "fps=$rate,scale=420:-2,tile=${cols}x${rows}:padding=4:color=red" \
    -frames:v 1 "$out/$name" </dev/null
  printf '%s\t%ss to %ss\t%s frames at %s fps, %s per row\t%s\n' \
    "$name" "$from" "$to" "$frames" "$rate" "$cols" "$label" >> "$out/sheets.txt"
}

# One sheet per motion segment, padded 100 ms either side so the start of the
# motion (the response to the touch) and its settle are both in frame.
k=0
if [ -f "$out/.segments" ]; then
  while read -r start end; do
    k=$((k + 1))
    sheet "$(printf 'sheet-%02d.png' "$k")" \
      "$(awk -v s="$start" 'BEGIN{printf "%.3f", s - 0.1}')" \
      "$(awk -v e="$end" 'BEGIN{printf "%.3f", e + 0.1}')" "$fps" "motion segment $k"
  done < "$out/.segments"
  rm -f "$out/.segments"
fi

# One sheet per gesture, at 10 fps so a long drag still fits on one sheet.
g=0
if [ -n "$timeline" ]; then
  while IFS=$'\t' read -r start end label; do
    case "$start" in ''|\#*) continue ;; esac
    g=$((g + 1))
    sheet "$(printf 'gesture-%02d.png' "$g")" \
      "$(awk -v s="$start" 'BEGIN{printf "%.3f", s - 0.1}')" \
      "$(awk -v e="$end" 'BEGIN{printf "%.3f", e + 0.6}')" 10 "$label"
  done < "$timeline"
fi

cat "$out/report.txt"
echo "sheets: $k motion, $g gesture, in $out"
