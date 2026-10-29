#!/bin/zsh
# Records per-process CPU, display and thermal state on a plugged-in iPhone.
# usage: record.sh <output.trace> [time-limit, default 10m]
# Stop early with Ctrl-C (or `pkill -INT -f "xctrace record"`); the trace is still saved.
set -e
out=${1:?usage: record.sh <output.trace> [time-limit]}
limit=${2:-10m}
udid=$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /available/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i}' | head -1)
[[ -n $udid ]] || { echo "No available physical iPhone. Plug it in, unlock it, check Developer Mode." >&2; exit 2; }
rm -rf "$out"
# The stock Power Profiler template fails with --all-processes (its Location
# Energy Model instrument refuses), so the instruments are listed one by one.
exec xcrun xctrace record --device "$udid" --all-processes \
  --instrument 'Power Profiler' --instrument 'Activity Monitor' \
  --instrument 'Display' --instrument 'Thermal State' \
  --time-limit "$limit" --output "$out"
