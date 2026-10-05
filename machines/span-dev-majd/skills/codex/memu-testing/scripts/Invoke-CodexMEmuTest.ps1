<#
  Runs a Codex visual test of a MAUI Android app on MEmu through the memu MCP server next to this script.
  The MCP server is passed with -c flags, so the app's repo needs no .codex\config.toml and no Codex repo trust.

  .\Invoke-CodexMEmuTest.ps1 -Task "<what to test>" -Package com.span.client.mobile.s4assets.maui `
      -ProjectRoot D:\GitProjects\rnds4assets\client\client.mobile.s4assets -Project client.mobile.s4assets.maui.csproj
  Add -CheckOnly to verify the Codex login and the MCP self-test (ADB, package, screenshot) without a model turn.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Task,

    # Android package of the app under test, e.g. com.span.client.mobile.itms.maui.
    [Parameter(Mandatory)]
    [string] $Package,

    # Folder Codex works in and that -Project is relative to. Defaults to the current folder.
    [string] $ProjectRoot = (Get-Location).Path,

    # csproj that deploy_app builds with -t:Run. Without it Codex can only launch an installed app.
    [string] $Project,

    [string] $Serial = "127.0.0.1:21503",

    [switch] $Interactive,
    [switch] $CheckOnly
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$mcpServer = Join-Path $PSScriptRoot "memu-mcp.mjs"
$toml = { param($value) $value.Replace("\", "/") }

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI is not installed or is not on PATH."
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js is not installed or is not on PATH."
}

$env:MEMU_ADB_SERIAL = $Serial
$env:MEMU_PACKAGE_NAME = $Package
$env:MEMU_PROJECT_ROOT = $ProjectRoot
$env:MEMU_PROJECT_PATH = $Project

codex login status
if ($LASTEXITCODE -ne 0) {
    Write-Host "No Codex login was found. Starting ChatGPT sign-in..."
    codex login
    if ($LASTEXITCODE -ne 0) {
        throw "Codex ChatGPT sign-in did not complete."
    }
}

if ($CheckOnly) {
    node $mcpServer --self-test
    if ($LASTEXITCODE -ne 0) {
        throw "The MEmu MCP self-test failed."
    }
    return
}

$deployHint = if ($Project) { "Deploy with deploy_app only when the app is missing or the task needs a fresh build; otherwise use launch_app." }
              else { "The app is already installed; use launch_app. There is no project to deploy." }
$prompt = 'Use $memu-testing to perform this test in MEmu on ' + $Package + ': ' + $Task + `
    " $deployHint Inspect a screenshot after every action, stay inside the app, and return a pass/fail report with reproduction steps for every defect."

$commonArguments = @(
    "-C", $ProjectRoot,
    "--sandbox", "workspace-write",
    "--ask-for-approval", "on-request",
    "-c", 'mcp_servers.memu.command="node"',
    "-c", ("mcp_servers.memu.args=['" + (& $toml $mcpServer) + "']"),
    "-c", "mcp_servers.memu.startup_timeout_sec=15",
    "-c", "mcp_servers.memu.tool_timeout_sec=300",
    "-c", "mcp_servers.memu.enabled=true",
    "-c", ('mcp_servers.memu.env.MEMU_ADB_SERIAL="' + $Serial + '"'),
    "-c", ('mcp_servers.memu.env.MEMU_PACKAGE_NAME="' + $Package + '"'),
    "-c", ('mcp_servers.memu.env.MEMU_PROJECT_ROOT="' + (& $toml $ProjectRoot) + '"')
)
if ($Project) {
    $commonArguments += @("-c", ('mcp_servers.memu.env.MEMU_PROJECT_PATH="' + (& $toml $Project) + '"'))
}

if ($Interactive) {
    & codex @commonArguments $prompt
}
else {
    # Pass the prompt via stdin: a multiline -Task as a positional argument is
    # truncated at the first newline by the codex.cmd shim.
    $prompt | & codex @commonArguments exec -
}

if ($LASTEXITCODE -ne 0) {
    throw "Codex exited with code $LASTEXITCODE."
}
