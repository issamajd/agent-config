---
name: xal-server
description: >-
  Start, stop, restart or check the local XAL application server (server.console)
  of a SPAN repo from an agent shell, without the user clicking the Start button.
  Use whenever a logic DLL was rebuilt and dispatched, a server.config.xml or
  init.xal change needs a restart, a client or test reports "cannot connect",
  or the user says "restart the server", "start the server console", "is the
  server up". Not for the Windows service variant (server.service) or for
  production servers.
---

# XAL server

`BUILD\Start Server Console.bat` opens `server.console.exe`, a borderless
WinForms window with Start, Refresh and Stop buttons. Nothing runs until Start
is clicked, and the window shows no exit code. `XalServer.ps1` beside this file
does the clicking through UI Automation and reports a result you can act on.

## Command

Windows PowerShell 5.1 only (`powershell.exe`, not `pwsh`): the UI Automation
assemblies are .NET Framework.

```powershell
powershell.exe -NoProfile -File "$env:USERPROFILE\.claude\skills\xal-server\XalServer.ps1" -Action <start|stop|restart|status> [-Build <repo>\BUILD]
```

`-Build` defaults to the nearest `BUILD` folder at or above the current
directory, so from inside a repo you can omit it. Exit codes: 0 running (or
stopped, for `stop`), 1 window open but services not started or the service bus
did not answer, 2 not running, 3 a console is running that this shell cannot
drive (see below).

What `start` does: runs the batch file as-is (it sets the environment the
server reads), waits for the window, clicks Start, waits for the button to grey
out (that is `ServiceStartUp.Start()` returning), then probes
`http://localhost:<APPLICATIONSERVERPORT>/<INSTANCENAME>/ServiceBus` from
`SetUserVars.bat` and reports any new `Exception` lines in
`RUNTIME\applications\ServerLogsFromTrace.log`. A healthy start on this
machine takes under ten seconds end to end; the wait for Start to return is
capped at 180 s (`-StartTimeoutSec`).

What `stop` does: clicks Stop, waits for it to grey out, then closes the window
so the process exits cleanly. It kills the process only if the window ignores
the close for 20 s.

## Rules

- Stop before copying DLLs into `RUNTIME\dlls`; the running server holds them.
  Sequence for a logic change: build, `stop`, dispatch or copy, `start`.
- A `WARNING` about the service bus not answering with HTTP 200 means the
  server is up but XAL or the service bus portal failed. Read the window's
  service list (red icon) and the trace log before retrying; do not loop on
  `restart`.
- Exit code 3 means a `server.console` is running elevated (the user started
  it with "Run as administrator"). UI Automation cannot reach it from this
  shell. Ask the user to stop it from its window, then `start` it from here so
  it runs at the same level as this shell. Everything in server.config.xml on
  this machine (Kestrel on 8001, DPAPI secrets) works without elevation.
- One console per BUILD folder. The script only touches the process whose exe
  lives under the given BUILD; another repo's server is left alone.
- `status` opens nothing; it is safe to call any time.
