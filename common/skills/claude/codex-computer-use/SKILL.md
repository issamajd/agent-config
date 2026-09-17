---
name: codex-computer-use
description: >-
  Have the Codex CLI (ChatGPT login, no API key, no Claude worker) visually
  test an Android app on the MEmu emulator: Codex drives the screen through the
  repo-local `memu` MCP server (screenshots + tap/swipe/type over ADB). Use
  WHENEVER the user asks to "test this on the emulator/MEmu," "run a
  computer-use test," "click through the app," "visually verify the
  gallery/screens," or wants automated device-level UI verification of a mobile
  build. Mobile/MEmu only for now. Do NOT use for code review (codex-review) or
  implementation (codex-implementation), and not for unit-testable logic — this
  is for what only a screen can show.
---

# Codex Computer Use (MEmu)

Runs the **Codex CLI** (`codex exec`) as a visual tester: a repo-local `memu`
MCP server gives it `screenshot`, `tap`, `swipe`, `type_text`, `key`,
`status`, `deploy_gallery`, `launch_gallery`, `restart_gallery`, and
`recent_logs` tools over ADB, and a repo-local Codex skill (`$memu-testing`)
tells it how to test. Codex looks at real screenshots, acts, and ends with a
pass/fail defect report. Auth is the cached ChatGPT login (`codex login`) — 
**no OpenAI API key anywhere**. Claude composes the task, runs the wrapper
**reliably (no stalls)**, and triages the report — Claude never drives the
screen itself.

Harness location (branch `feature/dx-free-controls` of the dxfree checkout):

- `D:\GitProjects\rndfwcore-dxfree\client\controls.gallery\tools\Invoke-CodexMEmuTest.ps1` (entry point)
- `D:\GitProjects\rndfwcore-dxfree\client\controls.gallery\.agents\skills\memu-testing\` (Codex-side skill + `scripts\memu-mcp.mjs` MCP server; Node built-ins + adb only)
- `D:\GitProjects\rndfwcore-dxfree\client\controls.gallery\.codex\config.toml` (MCP server env: serial, package, csproj)
- Docs: `D:\GitProjects\rndfwcore-dxfree\client\controls.gallery\COMPUTER_USE_TESTING.md`

The old `D:\GitProjects\rndfwcore\client\controls.gallery` copy is dead (stale
`bin/obj` only) — never run from there.

## Key facts (verified on this machine)

- **Wrapper interface:** `.\tools\Invoke-CodexMEmuTest.ps1 -Task "<task>"`
  (`-Task` is mandatory, even with `-CheckOnly`). `-CheckOnly` verifies the
  cached Codex login plus the MCP self-test (ADB, package, screenshot) with
  **no model turn**. `-Interactive` opens the Codex TUI — never use it from
  Claude's shells. Run it from the **PowerShell tool** (the wrapper is PS and
  `codex` resolves there; Git Bash would need `codex.cmd`).
- **Retargeting** (serial / package / csproj) is via the `env` line in
  `.codex\config.toml` (`MEMU_ADB_SERIAL`, `MEMU_PACKAGE_NAME`,
  `MEMU_PROJECT_PATH`) — the wrapper has no flags for it.
- **MEmu is `127.0.0.1:21503`** (stable ADB serial; never the MEmu process id).
  A physical phone is often also on adb — the MCP server pins the serial, but
  any direct adb evidence commands you run must pass `-s 127.0.0.1:21503`.
  Device is Android 9, 720x1280.
- **Codex deploys the app itself when needed** — the wrapper's prompt tells it
  to use `deploy_gallery` (builds `controls.gallery.csproj` with `-t:Run`), so
  a stale/missing install usually needs no manual step. Manual fallback:
  `dotnet build .\controls.gallery.csproj -f net8.0-android -t:Run`.
- **Focus boundary is enforced by the MCP tools**: input tools reject actions
  when focus leaves the package. There is no bypass flag; cross-app testing is
  out of scope for this harness.
- **Model:** the wrapper passes no `-m`; the run banner (stderr log) shows the
  resolved default — verified `gpt-6-astra`, reasoning effort high. Confirm the
  banner if quality matters.
- **Multiline `-Task` is only safe because the wrapper pipes the prompt to
  `codex exec -` via stdin.** Never "simplify" it back to a positional prompt
  argument: the `codex.cmd` shim truncates an argument at its first newline —
  the run then silently executes only the task's first line (verified failure).
- **Report goes to stdout** (the wrapper doesn't use `-o`): `codex exec`
  streams progress and prints the final report last — read the tail of the
  captured stdout. Streaming reasoning/noise goes to stderr; keep it as a log.
- **Runs can exceed 10 minutes** (each MCP call allows up to 300 s; a deploy
  alone can take several minutes). Default to background-with-sentinel.
- **ASCII typing only.** `type_text` can't inject Arabic/unicode — test RTL
  *rendering* visually; don't ask for non-ASCII input. No hover/right-click.
- **One run at a time.** The emulator is a single shared screen; never run two
  tests (or a test plus a manual deploy) concurrently.
- **Repo trust:** the project-local `.codex\config.toml` only loads when Codex
  trusts the repo. If MCP tools mysteriously don't exist in a run, the trust
  prompt is the likely cause — have the user run `codex` once in that
  directory and accept it.

## Workflow

### 1. Preflight (free — no model turn)

```powershell
Set-Location D:\GitProjects\rndfwcore-dxfree\client\controls.gallery
.\tools\Invoke-CodexMEmuTest.ps1 -Task "check" -CheckOnly
```

- ADB/connect failure → MEmu isn't running: ask the user to start it (or
  `adb connect 127.0.0.1:21503` if it's up but disconnected).
- Login failure → the wrapper triggers `codex login`, which needs a browser;
  from Claude's non-interactive shells that hangs/fails — stop and ask the
  user to run `codex login` themselves.
- "not installed" is fine — Codex will deploy during the run.

### 2. Compose the task

One focused area per run (one page, one flow) — not "test everything." Include:

- Concrete navigation and steps ("Open the Editors page from the home menu;
  tap the first text field; type `abc`; …").
- The *expected* behavior, taken from the code/specs, so the tester verifies
  instead of guessing ("the clear icon must appear once text is entered and
  must blank the field when tapped").
- What to report: exact reproduction steps, what was on screen, per-step
  pass/fail.

Do NOT add stay-in-the-app / deploy / screenshot-after-every-action
boilerplate — the wrapper and the `$memu-testing` skill already inject that.

### 3. Run — background with sentinel

The codex-runner "never stall" rules apply verbatim: launch ONE background
command that writes a sentinel on exit, then END YOUR TURN — the completion
notification resumes you. Never poll, never emit "waiting…". (Only a trivial
check-sized run may go foreground with the max 600000 ms timeout.)

```powershell
# run_in_background: true
$art = Join-Path $env:TEMP ("codex-memu-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $art | Out-Null
Set-Location D:\GitProjects\rndfwcore-dxfree\client\controls.gallery
.\tools\Invoke-CodexMEmuTest.ps1 -Task $task 1> (Join-Path $art "report.log") 2> (Join-Path $art "raw.log")
"exit=$LASTEXITCODE" | Set-Content (Join-Path $art "done")
Write-Host "CODEX_MEMU_REPORT=$(Join-Path $art 'report.log')"
```

On resume, read the tail of `report.log` immediately and move to triage. One
run → one resume → finish; if the sentinel is missing on resume, read
`raw.log` to see what happened and report it — do not relaunch.

### 4. Triage — the tester is independent, not ground truth

- Reproduce claimed defects before relaying: check the relevant code (for the
  gallery: `client\client.mobile.controls\dxfree\` in the dxfree checkout),
  and grab evidence directly —
  `adb -s 127.0.0.1:21503 exec-out screencap -p > shot.png` (then Read the
  PNG), `adb -s 127.0.0.1:21503 logcat -d -b crash` after any crash claim.
- If the report says input was rejected because focus left the app, the app
  likely **crashed** — pull the crash logcat; that is a finding, not a harness
  failure.
- If the report says the screen is **blank/white**, do NOT conclude the app is
  broken: dump the view hierarchy first —
  `adb -s 127.0.0.1:21503 shell uiautomator dump /sdcard/ui.xml` then read it.
  Text nodes present → the app renders fine and MEmu's screencap is returning
  blank frames (see failure modes); no nodes → a real app defect.
- If Codex stopped early or skipped steps, report what was and wasn't covered
  and rerun the remainder as a new focused task — don't present partial
  coverage as a pass.
- Relay defects with severity, exact repro steps, and `file:line` refs into
  the code under test. State plainly which checks passed, which failed, and
  which were not reached.

## Failure modes

| Symptom | Meaning / action |
|---|---|
| ADB connect fails / device not ready | MEmu not running — ask the user to start it |
| `codex login` starts / browser prompt | No cached ChatGPT login — user must run `codex login` in their own terminal |
| MCP tools missing in the run (`memu` server absent) | Repo not trusted by Codex — user runs `codex` once there and accepts trust; also check `node` on PATH |
| `The MEmu MCP self-test failed.` | Read its output — ADB, package, or screenshot layer is broken; fix before any model run |
| Input rejected, "focus left" wording in report | App crash or unexpected navigation — `logcat -d -b crash`, treat as finding |
| Wrapper throws `Codex exited with code N` | Read `raw.log` tail — quota, MCP startup timeout, or task refusal |
| Every screenshot is blank white (same byte size, even on the launcher) | MEmu is in DirectX render mode (`graphics_render_mode = 0` in `MEmu.memu`) — screencap can't capture the surface. USER must switch MEmu Settings → Engine → Graphics render mode → OpenGL and restart MEmu; verify with a launcher screenshot before burning a model run |
| Codex reports the task steps were "omitted"/asks for them | The prompt reached it truncated — check the wrapper still pipes via `exec -` stdin (see Key facts) |
