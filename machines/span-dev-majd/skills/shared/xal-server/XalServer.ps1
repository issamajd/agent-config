<#
.SYNOPSIS
    Start, stop, restart or query the XAL server console of a repo's BUILD folder
    from a non-interactive shell.

.DESCRIPTION
    "Start Server Console.bat" opens server.console.exe, a WinForms window with
    a Start button; the services only run after that button is clicked. This
    script runs the batch file, waits for the window, clicks Start through UI
    Automation, and then probes the service bus URL so a caller gets a
    pass/fail instead of a window. Stop clicks the Stop button and closes the
    window, which lets ServiceStartUp.Stop() run before the process exits.

    Needs Windows PowerShell 5.1 (UIAutomationClient). Run it as
        powershell.exe -NoProfile -File XalServer.ps1 -Action start [-Build <BUILD dir>]
    -Build defaults to the nearest BUILD folder at or above the current directory.

    UI Automation cannot drive a window that runs elevated when this shell is
    not. The script detects that case and tells you to stop that server by hand.

.EXAMPLE
    powershell.exe -NoProfile -File XalServer.ps1 -Action restart -Build D:\GitProjects\adic\BUILD
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Action,
    [string]$Build,
    [int]$StartTimeoutSec = 180
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# ---------------------------------------------------------------- locate the BUILD folder
function Find-BuildDir([string]$Hint) {
    if ($Hint) {
        if (Test-Path (Join-Path $Hint 'Start Server Console.bat')) { return (Resolve-Path $Hint).Path }
        throw "No 'Start Server Console.bat' in $Hint"
    }
    [string]$dir = (Get-Location).Path
    while ($dir) {
        foreach ($candidate in @($dir, (Join-Path $dir 'BUILD'))) {
            if (Test-Path (Join-Path $candidate 'Start Server Console.bat')) { return $candidate }
        }
        $dir = Split-Path $dir -Parent
    }
    throw "No BUILD folder with 'Start Server Console.bat' at or above $((Get-Location).Path); pass -Build."
}

[string]$BuildDir = Find-BuildDir $Build
[string]$AppsDir = Join-Path $BuildDir 'RUNTIME\applications'
[string]$ExePath = Join-Path $AppsDir 'server.console.exe'
if (-not (Test-Path $ExePath)) { throw "server.console.exe not found at $ExePath" }

# Port and instance name come from SetUserVars.bat; the service bus answers at
# http://<server>:<port>/<instance>/ServiceBus once XAL is up.
function Get-BatVar([string]$File, [string]$Name) {
    [string]$line = Select-String -Path $File -Pattern "^\s*SET\s+$Name=(.*)$" | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
    return $line.Trim()
}
[string]$userVars = Join-Path $BuildDir 'SetUserVars.bat'
[string]$port = Get-BatVar $userVars 'APPLICATIONSERVERPORT'
[string]$instance = Get-BatVar $userVars 'INSTANCENAME'
[string]$ProbeUrl = "http://localhost:$port/$instance/ServiceBus"

# ---------------------------------------------------------------- process helpers
function Get-ConsoleProcess {
    # Only the console that belongs to this BUILD folder; other repos may run their own.
    Get-Process -Name 'server.console' -ErrorAction SilentlyContinue |
        Where-Object { try { $_.Path -eq $ExePath } catch { $false } } |
        Select-Object -First 1
}

function Test-Elevated([System.Diagnostics.Process]$Process) {
    # Path and Handle of an elevated process are not readable from a limited shell.
    try { [void]$Process.Handle; return $false } catch { return $true }
}

function Get-OtherConsole {
    # A live console with an unreadable Path is one we cannot inspect: probably
    # elevated. A process that is still tearing down also has no Path; skip it.
    Get-Process -Name 'server.console' -ErrorAction SilentlyContinue |
        Where-Object { -not $_.HasExited } |
        Where-Object { try { $null -eq $_.Path } catch { $true } } |
        Select-Object -First 1
}

# ---------------------------------------------------------------- UI Automation helpers
$AE = [System.Windows.Automation.AutomationElement]

function Get-MainWindow([System.Diagnostics.Process]$Process, [int]$TimeoutSec) {
    [datetime]$deadline = (Get-Date).AddSeconds($TimeoutSec)
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $Process.Id)
    while ((Get-Date) -lt $deadline) {
        $win = $AE::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($win) { return $win }
        Start-Sleep -Milliseconds 500
        if ($Process.HasExited) { throw "server.console exited before its window appeared (exit code $($Process.ExitCode))." }
    }
    throw "server.console window did not appear within ${TimeoutSec}s."
}

function Get-Control($Window, [string]$AutomationId) {
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::AutomationIdProperty, $AutomationId)
    $el = $Window.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
    if (-not $el) { throw "Control '$AutomationId' not found in the server.console window." }
    return $el
}

function Invoke-Control($Control) {
    $pattern = $Control.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $pattern.Invoke()
}

function Wait-Enabled($Window, [string]$AutomationId, [bool]$Enabled, [int]$TimeoutSec, [string]$What) {
    [datetime]$deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $el = Get-Control $Window $AutomationId
        if ($el.Current.IsEnabled -eq $Enabled) { return }
        Start-Sleep -Seconds 1
    }
    throw "Timed out after ${TimeoutSec}s waiting for $What."
}

function Get-ServiceNames($Window) {
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
    $items = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
    [string[]]$names = @()
    foreach ($i in $items) { $names += $i.Current.Name }
    return $names
}

# ---------------------------------------------------------------- probe and logs
function Probe-ServiceBus {
    try {
        $r = Invoke-WebRequest -Uri $ProbeUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        return [int]$r.StatusCode
    } catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    }
}

[string]$TraceLog = Join-Path $AppsDir 'ServerLogsFromTrace.log'
function Get-LogLength { if (Test-Path $TraceLog) { (Get-Item $TraceLog).Length } else { 0 } }
function Get-NewLogErrors([long]$Since) {
    if (-not (Test-Path $TraceLog)) { return @() }
    [System.IO.FileStream]$fs = [System.IO.File]::Open($TraceLog, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -le $Since) { return @() }
        [void]$fs.Seek($Since, 'Begin')
        [System.IO.StreamReader]$sr = New-Object System.IO.StreamReader($fs)
        [string]$text = $sr.ReadToEnd()
    } finally { $fs.Dispose() }
    return @($text -split "`r?`n" | Where-Object { $_ -match 'Exception|Error|failed' } | Select-Object -First 15)
}

# ---------------------------------------------------------------- actions
# Each action prints its progress and sets $script:rc; functions do not use
# `return <n>`, because PowerShell would merge that into the output stream.
[int]$script:rc = 0

function Do-Status {
    $p = Get-ConsoleProcess
    $other = Get-OtherConsole
    if (-not $p) {
        if ($other) {
            Write-Output "NOT MANAGEABLE: a server.console (pid $($other.Id)) is running that this shell cannot inspect; it is probably elevated. Stop it from its own window."
            $script:rc = 3; return
        }
        Write-Output "STOPPED: no server.console running from $AppsDir"
        $script:rc = 2; return
    }
    if (Test-Elevated $p) {
        Write-Output "NOT MANAGEABLE: server.console pid $($p.Id) runs elevated; this shell cannot drive it."
        $script:rc = 3; return
    }
    $win = Get-MainWindow $p 10
    [bool]$started = -not (Get-Control $win 'start').Current.IsEnabled
    [int]$code = Probe-ServiceBus
    if ($started) {
        [string[]]$names = Get-ServiceNames $win
        Write-Output "STARTED: pid $($p.Id), $($names.Count) services listed, $ProbeUrl -> HTTP $code"
        $script:rc = 0; return
    }
    Write-Output "OPEN BUT NOT STARTED: pid $($p.Id), window is up, services not started ($ProbeUrl -> HTTP $code)"
    $script:rc = 1
}

function Do-Start {
    $other = Get-OtherConsole
    if ($other -and -not (Get-ConsoleProcess)) { throw "A server.console (pid $($other.Id)) is already running that this shell cannot inspect, probably elevated. Stop it from its own window first." }
    $p = Get-ConsoleProcess
    [long]$logStart = Get-LogLength
    if (-not $p) {
        [int[]]$before = @(Get-Process -Name 'server.console' -ErrorAction SilentlyContinue | ForEach-Object Id)
        # The batch file sets the environment the server reads and cds into
        # applications before 'start server.console.exe'; run it as-is. Agent
        # shells set NoDefaultCurrentDirectoryInExePath=1, which makes both
        # 'call SetEnvVars.bat' and 'start server.console.exe' fail (the latter
        # with a hidden message box that blocks cmd forever), so drop it.
        Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue
        $cmd = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$BuildDir\Start Server Console.bat`"" -WorkingDirectory $BuildDir -WindowStyle Hidden -PassThru
        if (-not $cmd.WaitForExit(30000)) {
            Stop-Process -Id $cmd.Id -Force -ErrorAction SilentlyContinue
            throw "'Start Server Console.bat' did not finish within 30s; it is probably stuck on a message box. Run it by hand to see why."
        }
        [datetime]$deadline = (Get-Date).AddSeconds(30)
        while (-not $p -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 500
            $p = Get-Process -Name 'server.console' -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Select-Object -First 1
        }
        if (-not $p) { throw "server.console.exe did not start. Run `"$BuildDir\Start Server Console.bat`" by hand to see why." }
        Write-Output "launched server.console pid $($p.Id)"
    } else {
        Write-Output "server.console already running, pid $($p.Id)"
    }
    if (Test-Elevated $p) { throw "server.console pid $($p.Id) runs elevated; this shell cannot click its Start button." }

    $win = Get-MainWindow $p 90
    $start = Get-Control $win 'start'
    if (-not $start.Current.IsEnabled) {
        Write-Output "services already started"
    } else {
        Write-Output "clicking Start..."
        Invoke-Control $start
        # IsStarted flips (and Start greys out) only after ServiceStartUp.Start() returns.
        Wait-Enabled $win 'start' $false $StartTimeoutSec 'the Start button to grey out (ServiceStartUp.Start to return)'
    }
    if ($p.HasExited) { throw "server.console exited during start-up. Check $TraceLog and the Windows event log." }

    [int]$code = 0
    [datetime]$deadline = (Get-Date).AddSeconds(60)
    while ($code -eq 0 -and (Get-Date) -lt $deadline) { $code = Probe-ServiceBus; if ($code -eq 0) { Start-Sleep -Seconds 2 } }
    [string[]]$names = Get-ServiceNames $win
    [string[]]$errors = Get-NewLogErrors $logStart
    Write-Output "STARTED: pid $($p.Id), $($names.Count) services listed, $ProbeUrl -> HTTP $code"
    if ($code -eq 0) { Write-Warning "The service bus did not answer at $ProbeUrl within 60s; the XAL or SERVICEBUSPORTAL service probably failed. Check the window and $TraceLog." }
    if ($errors.Count -gt 0) { Write-Warning "New error lines in $TraceLog since launch:"; $errors | ForEach-Object { Write-Output "  $_" } }
    $script:rc = if ($code -eq 0) { 1 } else { 0 }
}

function Do-Stop {
    $p = Get-ConsoleProcess
    if (-not $p) {
        $other = Get-OtherConsole
        if ($other) { throw "server.console pid $($other.Id) is running but this shell cannot inspect it (probably elevated). Stop it from its own window." }
        Write-Output "already stopped: no server.console running from $AppsDir"
        $script:rc = 0; return
    }
    if (Test-Elevated $p) { throw "server.console pid $($p.Id) runs elevated; this shell cannot stop it. Use its own window." }
    $win = Get-MainWindow $p 10
    $stop = Get-Control $win 'stop'
    if ($stop.Current.IsEnabled) {
        Write-Output "clicking Stop..."
        Invoke-Control $stop
        Wait-Enabled $win 'stop' $false 120 'the Stop button to grey out (ServiceStartUp.Stop to return)'
    }
    # Close the window through UI Automation: the form is borderless and not in
    # the taskbar, so Process.CloseMainWindow() finds no main window. WM_CLOSE
    # runs FormClosing (tray icon disposed), Application.Run returns, the
    # process ends. Services are already stopped here, so a kill is a safe fallback.
    try {
        $wp = $win.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
        $wp.Close()
    } catch {
        Write-Warning "window close via UI Automation failed ($($_.Exception.Message)); killing pid $($p.Id)"
    }
    if (-not $p.WaitForExit(20000)) {
        Write-Warning "window did not close within 20s; killing pid $($p.Id)"
        Stop-Process -Id $p.Id -Force
        [void]$p.WaitForExit(10000)
    }
    Write-Output "STOPPED: server.console pid $($p.Id) exited"
    $script:rc = 0
}

switch ($Action) {
    'status'  { Do-Status }
    'start'   { Do-Start }
    'stop'    { Do-Stop }
    'restart' { Do-Stop; Do-Start }
}
exit $script:rc
