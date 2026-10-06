<#
.SYNOPSIS
    Validates RNDSCRIPTS source-dialect SQL files with SQLScriptConverter and
    exits non-zero when any file fails to parse.

.DESCRIPTION
    Wraps "SQLScriptConverter.exe /CHECK <folder> /R", which is read-only but
    always exits 0. This script parses the "Checked N files with M files in
    error" summary and returns M as the exit code, so callers can rely on it.
    Also warns about stray converter outputs (*.sql.MSSQL, *.sql.ORACLE,
    *.sql.POSTGRESQL) left inside the tree, which would be shipped by the
    release build.

.EXAMPLE
    .\Check-RndScripts.ps1 -Path "C:\PROJECTS\RNDSCRIPTS\CURRENT\S4ASSETS\MAIN\Common\Incremental Scripts in Progress"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Converter = "C:\PROJECTS\RNDSCRIPTS\CURRENT\SQLScriptConverter\SQLScriptConverter.exe"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Converter)) { throw "Converter not found: $Converter" }
if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

[string]$folder = $Path
if (Test-Path $Path -PathType Leaf) { $folder = Split-Path $Path -Parent }

[string[]]$stray = Get-ChildItem -Path $folder -Recurse -File -Include *.sql.MSSQL, *.sql.ORACLE, *.sql.POSTGRESQL |
    ForEach-Object { $_.FullName }
foreach ($s in $stray) { Write-Warning "Stray converter output inside the tree (delete it): $s" }

[string[]]$output = & $Converter /CHECK $folder /R 2>&1 | ForEach-Object { [string]$_ }
$output | ForEach-Object { Write-Output $_ }

# Success prints "Checked N files successfully.", failure prints
# "Checked N files with M files in error."
[string]$summary = $output | Where-Object { $_ -match '^Checked\s+\d+\s+files\s+' } | Select-Object -Last 1
if (-not $summary) {
    Write-Error "No summary line from the converter; treat as failure."
    exit 99
}

[int]$errors = 0
[System.Text.RegularExpressions.Match]$m = [regex]::Match($summary, 'with\s+(\d+)\s+files\s+in\s+error')
if ($m.Success) { $errors = [int]$m.Groups[1].Value }
if ($stray.Count -gt 0 -and $errors -eq 0) { $errors = 1 }
exit $errors
