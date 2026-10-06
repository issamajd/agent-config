#!/usr/bin/env bash
#
# codex-run.sh — launch and observe a Codex CLI (gpt-6-astra) run.
#
# Every Codex run lives in a predictable directory so that a run can be watched
# from OUTSIDE the process that started it (the caller, a parent agent, or a
# Monitor). This is what makes a long run legible instead of a silent wait.
#
#   $CODEX_RUNS_ROOT/<id>/
#     prompt.md   the prompt that was sent
#     raw.log     streaming reasoning/TUI output (stderr) — the progress signal
#     report.md   Codex's final report  (the deliverable)
#     stdout.log  incidental stdout (exec mode only)
#     started     unix ts of launch
#     meta        mode/repo/timeout
#     status      "exit=<code>" — written ONLY when the run reaches a terminal
#                 state. Its existence is the completion sentinel.
#     summary     the CODEX_* block that `start` printed, for readers who did
#                 not see the launch output
#
# Requires GNU timeout (`timeout`, or `gtimeout` from coreutils on mac). Pass
# an empty CODEX_PROFILE to skip the optional no-superpowers profile.
#
# Usage:
#   codex-run.sh start  --mode exec|review --id ID --prompt FILE [--repo DIR] [--timeout SEC]
#   codex-run.sh watch  --id ID [--interval SEC]     # heartbeat loop, for Monitor
#   codex-run.sh status --id ID                      # one-shot "what's happening?"
#   codex-run.sh list                                # all known runs
#
# `start` blocks until Codex exits — hand it to the Bash tool with
# run_in_background:true so the harness tracks it and fires a completion
# notification. `watch` is the Monitor command; it emits one line per interval
# and exits when the run reaches a terminal state.

set -uo pipefail

# Git Bash on Windows needs the .cmd shim; mac and Linux install a plain binary.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) CODEX_BIN="${CODEX_BIN:-codex.cmd}" ;;
  *)                    CODEX_BIN="${CODEX_BIN:-codex}" ;;
esac
# The model every run is pinned to. Single source of truth: the flags below and
# the CODEX_MODEL check in the summary both read it, so a model rename is a
# one-line change here (override per run with CODEX_MODEL_PIN=...).
CODEX_MODEL_PIN="${CODEX_MODEL_PIN:-gpt-6-astra}"
RUNS_ROOT="${CODEX_RUNS_ROOT:-${TMPDIR:-/tmp}/codex-runs}"
# 1500s keeps timeout + the 120s orphan margin inside the 30-minute cap of the
# Monitor that watches a run, so ORPHANED can still be reported.
DEFAULT_TIMEOUT=1500
DEFAULT_INTERVAL=60
ESC="$(printf '\033')"

die() { echo "codex-run: $*" >&2; exit 2; }

# GNU timeout: /usr/bin/timeout on Linux and Git Bash, gtimeout (coreutils) on mac.
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"

# Optional Codex profile that turns off the "superpowers" plugin for automated
# runs. Profiles live at $CODEX_HOME/<name>.config.toml; the flag is only passed
# when that file exists, so a fresh machine without it still runs.
CODEX_PROFILE="${CODEX_PROFILE:-no-superpowers}"
PROFILE_ARGS=()
if [ -n "$CODEX_PROFILE" ] && [ -f "${CODEX_HOME:-$HOME/.codex}/$CODEX_PROFILE.config.toml" ]; then
  PROFILE_ARGS=(--profile "$CODEX_PROFILE")
fi

# Native path for Windows-side tools (the Read tool cannot open /tmp/...).
win_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}
run_dir() { printf '%s/%s' "$RUNS_ROOT" "$1"; }
now() { date +%s; }

# Last meaningful line of the streaming log. The TUI rewrites lines with \r and
# paints them with ANSI, so split on \r and strip escapes before taking the tail.
last_line() {
  tail -c 4000 "$1" 2>/dev/null \
    | tr '\r' '\n' \
    | sed "s/${ESC}\[[0-9;]*[a-zA-Z]//g" \
    | grep -v '^[[:space:]]*$' \
    | tail -1
}

log_size() { wc -c < "$1" 2>/dev/null || echo 0; }

cmd_start() {
  local mode="" id="" prompt="" repo="$PWD" tmo="$DEFAULT_TIMEOUT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --mode)    mode="$2";   shift 2 ;;
      --id)      id="$2";     shift 2 ;;
      --prompt)  prompt="$2"; shift 2 ;;
      --repo)    repo="$2";   shift 2 ;;
      --timeout) tmo="$2";    shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [ -n "$mode" ]   || die "--mode exec|review is required"
  [ -n "$id" ]     || die "--id is required"
  [ -n "$prompt" ] || die "--prompt FILE is required"
  [ -f "$prompt" ] || die "prompt file not found: $prompt"
  [ -d "$repo" ]   || die "repo dir not found: $repo"
  case "$mode" in exec|review) ;; *) die "--mode must be exec or review" ;; esac
  [ -n "$TIMEOUT_BIN" ] || die "no 'timeout' or 'gtimeout' on PATH (on mac: brew install coreutils)"

  local dir; dir="$(run_dir "$id")"
  mkdir -p "$RUNS_ROOT"
  # Plain mkdir is the atomic claim: a second start with the same id fails here
  # instead of truncating a running or finished run's files. Ids are single-use.
  if ! mkdir "$dir" 2>/dev/null; then
    if [ -f "$dir/status" ]; then die "run '$id' already finished ($(cat "$dir/status")) — use a fresh --id"
    elif [ -f "$dir/started" ]; then die "run '$id' is already running — use a fresh --id"
    else die "run dir $dir already exists — use a fresh --id"
    fi
  fi
  cp "$prompt" "$dir/prompt.md"
  : > "$dir/raw.log"
  : > "$dir/report.md"
  now > "$dir/started"
  printf 'mode=%s\nrepo=%s\ntimeout=%s\n' "$mode" "$repo" "$tmo" > "$dir/meta"

  # `timeout` guarantees a terminal state: without it a wedged Codex waits
  # forever and the caller can never tell "slow" from "dead". -k 30 follows the
  # TERM with a KILL. (Caveat: TERM reaches the cmd.exe shim; a native child can
  # occasionally outlive it. `watch` reports that case as ORPHANED.)
  local rc
  case "$mode" in
    exec)
      "$TIMEOUT_BIN" -k 30 "$tmo" "$CODEX_BIN" ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} -C "$repo" \
        exec -m "$CODEX_MODEL_PIN" -s workspace-write -o "$dir/report.md" - \
        < "$dir/prompt.md" > "$dir/stdout.log" 2> "$dir/raw.log"
      rc=$?
      ;;
    review)
      # `codex review` takes no -m; pin the model with -c. A scope flag and a
      # custom prompt are mutually exclusive, so scope is stated in the prompt.
      # Report goes to stdout (strip the SUCCESS teardown lines); noise to stderr.
      "$TIMEOUT_BIN" -k 30 "$tmo" "$CODEX_BIN" ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} -c "model=\"$CODEX_MODEL_PIN\"" \
        -C "$repo" review - < "$dir/prompt.md" 2> "$dir/raw.log" \
        | grep -v '^SUCCESS: The process' > "$dir/report.md"
      rc=${PIPESTATUS[0]}
      ;;
  esac
  # Record the true duration alongside the exit code: an observer polling on an
  # interval only notices completion up to one interval late, so it must not
  # compute the duration itself.
  local elapsed
  elapsed=$(( $(now) - $(cat "$dir/started") ))
  printf 'exit=%s elapsed=%ss\n' "$rc" "$elapsed" > "$dir/status"

  # Summary block — this is what lands in the completion notification. It is
  # also saved as $dir/summary so an agent that did not see the launch output
  # (a parent reading a runner's result) can still check it.
  {
    echo "CODEX_RUN_ID=$id"
    echo "CODEX_RUN_DIR=$dir"
    echo "CODEX_REPORT=$dir/report.md"
    # Native paths too: $dir is a POSIX path that Windows-side tools (the Read
    # tool) cannot open, and /tmp is NOT C:\tmp.
    echo "CODEX_REPORT_WIN=$(win_path "$dir/report.md")"
    echo "CODEX_RAWLOG_WIN=$(win_path "$dir/raw.log")"
    echo "CODEX_EXIT=$rc"
    echo "CODEX_ELAPSED=${elapsed}s"
    # Guards the silent-model-fallback trap: without -m/-c the CLI silently uses
    # whatever ~/.codex/config.toml defaults to. Matched version-agnostically so
    # a model rename cannot quietly turn this check into "unknown".
    local seen
    seen="$(grep -m1 -oE 'gpt-[0-9][0-9.]*-[a-z]+' "$dir/raw.log" 2>/dev/null)"
    echo "CODEX_MODEL=${seen:-unknown}"
    if [ -n "$seen" ] && [ "$seen" != "$CODEX_MODEL_PIN" ]; then
      echo "CODEX_MODEL_MISMATCH=expected $CODEX_MODEL_PIN — the model pin did not take"
    fi
    if [ "$rc" = "124" ] || [ "$rc" = "137" ]; then
      echo "CODEX_RESULT=TIMED OUT after ${tmo}s — partial log in $dir/raw.log"
    elif [ "$rc" != "0" ]; then
      echo "CODEX_RESULT=FAILED — see $dir/raw.log"
    elif [ ! -s "$dir/report.md" ]; then
      echo "CODEX_RESULT=EMPTY REPORT despite exit 0 — see $dir/raw.log"
    else
      echo "CODEX_RESULT=ok"
    fi
  } | tee "$dir/summary"
  return 0
}

cmd_watch() {
  local id="" interval="$DEFAULT_INTERVAL"
  while [ $# -gt 0 ]; do
    case "$1" in
      --id)       id="$2";       shift 2 ;;
      --interval) interval="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--id is required"
  local dir; dir="$(run_dir "$id")"

  # The monitor is normally armed BEFORE the run starts — a parent watching a
  # child agent arms it first, then spawns. Allow generous startup slack: the
  # child still has to do its baseline checks and write the prompt.
  local waited=0
  while [ ! -f "$dir/started" ] && [ "$waited" -lt 300 ]; do sleep 2; waited=$((waited + 2)); done
  if [ ! -f "$dir/started" ]; then
    echo "[$id] never started after ${waited}s — the start command did not launch"
    exit 1
  fi

  local started tmo prev=0 quiet=0 size elapsed last state limit
  started="$(cat "$dir/started" 2>/dev/null || now)"
  tmo="$(sed -n 's/^timeout=//p' "$dir/meta" 2>/dev/null)"
  limit=$(( ${tmo:-$DEFAULT_TIMEOUT} + 120 ))

  while [ ! -f "$dir/status" ]; do
    sleep "$interval"
    elapsed=$(( $(now) - started ))
    size="$(log_size "$dir/raw.log")"
    last="$(last_line "$dir/raw.log")"
    if [ "$elapsed" -gt "$limit" ]; then
      # Past the timeout with no status file: the wrapper died without writing
      # its sentinel, or a native child outlived the kill. Either way, stop
      # claiming "running" — that is the exact silence this script exists to end.
      echo "[$id] ${elapsed}s ORPHANED — past the ${tmo}s limit with no exit status · check $dir/raw.log"
      exit 1
    fi
    # A run that is wrapping up stops writing for a tick or two, so a single
    # quiet interval is normal — only sustained silence is worth flagging.
    if [ "$size" -eq "$prev" ]; then quiet=$((quiet + 1)); else quiet=0; fi
    prev="$size"
    if [ "$quiet" -ge 2 ]; then state="STALLED(${quiet} quiet ticks)"; else state="running"; fi
    echo "[$id] ${elapsed}s ${state} · ${last:0:140}"
  done
  echo "[$id] finished — $(cat "$dir/status") — report: $dir/report.md"
}

cmd_status() {
  local id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) die "unknown flag: $1" ;;
    esac
  done
  [ -n "$id" ] || die "--id is required"
  local dir; dir="$(run_dir "$id")"
  [ -d "$dir" ] || die "no such run: $id (looked in $dir)"

  [ -f "$dir/started" ] || { echo "[$id] NEVER STARTED — the run dir exists but start did not launch"; return 1; }

  local started elapsed tmo limit
  started="$(cat "$dir/started")"
  elapsed=$(( $(now) - started ))
  tmo="$(sed -n 's/^timeout=//p' "$dir/meta" 2>/dev/null)"
  limit=$(( ${tmo:-$DEFAULT_TIMEOUT} + 120 ))
  if [ -f "$dir/status" ]; then
    echo "[$id] DONE — $(cat "$dir/status")"
    echo "report: $dir/report.md ($(log_size "$dir/report.md") bytes) · $(win_path "$dir/report.md")"
    [ -f "$dir/summary" ] && cat "$dir/summary"
  elif [ "$elapsed" -gt "$limit" ]; then
    # Same rule as watch: past the timeout with no exit status means the wrapper
    # died without its sentinel. Report it as terminal so nobody waits on it.
    echo "[$id] ORPHANED — ${elapsed}s past launch, limit ${tmo:-$DEFAULT_TIMEOUT}s, no exit status · check $(win_path "$dir/raw.log")"
    return 1
  else
    echo "[$id] RUNNING for ${elapsed}s — raw.log $(log_size "$dir/raw.log") bytes"
    echo "last: $(last_line "$dir/raw.log")"
  fi
}

cmd_list() {
  [ -d "$RUNS_ROOT" ] || { echo "no runs under $RUNS_ROOT"; return 0; }
  local dir id
  for dir in "$RUNS_ROOT"/*/; do
    [ -d "$dir" ] || continue
    id="$(basename "$dir")"
    if [ -f "$dir/status" ]; then
      echo "$id  done  $(cat "$dir/status")"
    elif [ ! -f "$dir/started" ]; then
      echo "$id  stale  (never started)"
    else
      echo "$id  running  $(( $(now) - $(cat "$dir/started") ))s"
    fi
  done
}

case "${1:-}" in
  start)  shift; cmd_start  "$@" ;;
  watch)  shift; cmd_watch  "$@" ;;
  status) shift; cmd_status "$@" ;;
  list)   shift; cmd_list   "$@" ;;
  *) die "usage: codex-run.sh {start|watch|status|list} [flags]" ;;
esac
