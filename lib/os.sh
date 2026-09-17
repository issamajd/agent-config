# lib/os.sh - the only OS-specific code in agent-config. Sourced by install.sh.
# Works with bash 3.2 (macOS default), Git Bash on Windows, and Linux.

detect_os() {
  case "$(uname -s)" in
    Darwin) echo mac ;;
    Linux) echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}
OS="$(detect_os)"

# Absolute path in the form the tools expect: D:/x/y on Windows, unchanged elsewhere.
native_path() {
  if [ "$OS" = windows ]; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# Create or refresh a directory link at $1 pointing to $2.
# Symlink on mac/linux; junction on Windows (no admin, no Developer Mode).
# Git Bash presents junctions as symlinks, so -L, readlink and rm all behave.
link_dir() {
  local link="$1" target="$2"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$target" ] && return 0
    unlink_dir "$link"
  fi
  if [ "$OS" = windows ]; then
    MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$link")" "$(cygpath -w "$target")" >/dev/null
  else
    ln -sfn "$target" "$link"
  fi
  echo "  linked $link -> $target"
}

# Remove a directory link without touching what it points to.
unlink_dir() {
  rm "$1"
  echo "  removed link $1"
}

# --- optional login job that runs sync.sh -------------------------------------

JOB_NAME="agent-config-sync"

register_login_job() {
  local repo="$1"
  case "$OS" in
    windows)
      local bash_exe; bash_exe="$(cygpath -w "$(command -v bash)")"
      schtasks /Create /F /TN "$JOB_NAME" /SC ONLOGON /RL LIMITED \
        /TR "\"$bash_exe\" -lc \"'$(cygpath -m "$repo")/sync.sh'\"" >/dev/null
      echo "  registered scheduled task $JOB_NAME (at logon)"
      ;;
    mac)
      local plist="$HOME/Library/LaunchAgents/com.$JOB_NAME.plist"
      mkdir -p "$(dirname "$plist")"
      cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.$JOB_NAME</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$repo/sync.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>21600</integer>
  <key>StandardOutPath</key><string>$repo/.sync.log</string>
  <key>StandardErrorPath</key><string>$repo/.sync.log</string>
</dict></plist>
EOF
      launchctl unload "$plist" 2>/dev/null || true
      launchctl load "$plist"
      echo "  registered launchd agent com.$JOB_NAME (at login and every 6h)"
      ;;
    linux)
      if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
        local unit_dir="$HOME/.config/systemd/user"
        mkdir -p "$unit_dir"
        cat >"$unit_dir/$JOB_NAME.service" <<EOF
[Unit]
Description=Pull agent-config and re-install

[Service]
Type=oneshot
ExecStart=/bin/bash $repo/sync.sh
EOF
        cat >"$unit_dir/$JOB_NAME.timer" <<EOF
[Unit]
Description=Run $JOB_NAME at login and every 6h

[Timer]
OnStartupSec=2min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF
        systemctl --user daemon-reload
        systemctl --user enable --now "$JOB_NAME.timer"
        echo "  registered systemd user timer $JOB_NAME"
      else
        local line="@reboot /bin/bash $repo/sync.sh >> $repo/.sync.log 2>&1 # $JOB_NAME"
        { crontab -l 2>/dev/null | grep -v "# $JOB_NAME\$"; echo "$line"; } | crontab -
        echo "  registered crontab @reboot entry $JOB_NAME"
      fi
      ;;
    *) echo "  autosync: unsupported OS" >&2; return 1 ;;
  esac
}

unregister_login_job() {
  case "$OS" in
    windows) schtasks /Delete /F /TN "$JOB_NAME" >/dev/null 2>&1 || true ;;
    mac)
      local plist="$HOME/Library/LaunchAgents/com.$JOB_NAME.plist"
      launchctl unload "$plist" 2>/dev/null || true
      rm -f "$plist"
      ;;
    linux)
      systemctl --user disable --now "$JOB_NAME.timer" 2>/dev/null || true
      rm -f "$HOME/.config/systemd/user/$JOB_NAME".{service,timer}
      crontab -l 2>/dev/null | grep -v "# $JOB_NAME\$" | crontab - 2>/dev/null || true
      ;;
  esac
  echo "  removed login job $JOB_NAME (if it existed)"
}
