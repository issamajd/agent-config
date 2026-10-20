<#
.SYNOPSIS
Installs an APK on the MEmu emulator and keeps the app's settings (server endpoint, last user),
even when the installed copy has a different signature.

.DESCRIPTION
An APK signed with another key (Span-signed Release over a debug-signed Debug, or back) cannot be
installed over the existing app: Android rejects it with INSTALL_FAILED_UPDATE_INCOMPATIBLE. The
only way is to uninstall, which wipes /data/data/<package>, including the shared_prefs that hold
the server endpoint. MEmu's adb shell runs as root, so this script copies shared_prefs out first,
reinstalls, and puts them back owned by the new app user.

Exit codes: 0 installed, 1 install failed.
#>
param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Serial = '127.0.0.1:21503'
)

# adb writes to stderr on success too; results are checked explicitly instead.
$ErrorActionPreference = 'Continue'
$adb = 'C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe'
$buildTools = Get-ChildItem 'C:\Program Files (x86)\Android\android-sdk\build-tools' -Directory |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$badging = & (Join-Path $buildTools.FullName 'aapt.exe') dump badging $Apk 2>&1
$package = [regex]::Match(($badging -join "`n"), "package: name='([^']+)'").Groups[1].Value
if (-not $package) { Write-Output "Cannot read the package name of $Apk"; exit 1 }

function Adb { & $adb -s $Serial @args 2>&1 }

$installed = (Adb shell pm list packages $package) -match "package:$package$"
Adb shell am force-stop $package | Out-Null
$result = Adb install -r $Apk
if ($result -match 'Success') {
    Write-Output "Installed $package over the existing app (same signature)."
    exit 0
}
if (-not $installed -or -not ($result -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE')) {
    $result | Select-Object -Last 3
    exit 1
}

# Different signature: save the settings, reinstall, restore them.
$backup = Join-Path $env:TEMP "memu-prefs-$package-$(Get-Date -Format yyyyMMddHHmmss)"
New-Item -ItemType Directory -Force $backup | Out-Null
Adb pull "/data/data/$package/shared_prefs" $backup | Out-Null
$saved = @(Get-ChildItem $backup -Recurse -File)
Write-Output "Signature differs: saved $($saved.Count) settings file(s) to $backup, reinstalling."

Adb uninstall $package | Out-Null
$result = Adb install $Apk
if (-not ($result -match 'Success')) {
    $result | Select-Object -Last 3
    Write-Output "Install failed after uninstall. The saved settings are in $backup."
    exit 1
}

if ($saved.Count -gt 0) {
    # Start the app once so Android creates its data folder, then restore as the new app user.
    Adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 | Out-Null
    Start-Sleep -Seconds 5
    Adb shell am force-stop $package | Out-Null
    $owner = (Adb shell "stat -c %U /data/data/$package" | Out-String).Trim()
    Adb shell "mkdir -p /data/data/$package/shared_prefs" | Out-Null
    foreach ($file in $saved) { Adb push $file.FullName "/data/data/$package/shared_prefs/" | Out-Null }
    Adb shell "chown -R ${owner}:${owner} /data/data/$package/shared_prefs && chmod 771 /data/data/$package/shared_prefs && chmod 660 /data/data/$package/shared_prefs/*" | Out-Null
    Write-Output "Restored settings for $package (owner $owner)."
}
Write-Output "Installed $package."
exit 0
