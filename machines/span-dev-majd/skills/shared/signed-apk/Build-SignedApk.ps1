<#
.SYNOPSIS
Builds a Release APK of a SPAN MAUI app (S4Assets, S4WES, ...) signed with the Span keystore,
against a Release build of the framework's Android assemblies.

.DESCRIPTION
1. Runs <rndfwcore>\BUILD\BuildMobile.bat Release, which leaves RUNTIME\dlls\android in Release.
2. Builds the app with -t:SignAndroidPackage and the Span signing properties.
3. Checks the signer certificate is Span's, then copies the APK to a name that records the app
   version and both commits.

The keystore password comes from SPAN_KS_PASS (this process, else the user environment). It is
passed to MSBuild as env:SPAN_KS_PASS and never printed.

Exit codes: 0 signed APK ready, 1 build failed, 2 SPAN_KS_PASS not set, 3 APK not signed by Span.
#>
param(
    # The app's *.maui.csproj, or the app repository root.
    [Parameter(Mandatory = $true)][string]$App,
    # The rndfwcore checkout. Default: rndfwcore next to the app repository, as the app csproj assumes.
    [string]$FwCore,
    # Reuse RUNTIME\dlls\android when it already holds a Release build of the wanted framework commit.
    [switch]$SkipFramework,
    # Optional overrides of the csproj's ApplicationDisplayVersion and ApplicationVersion.
    [string]$DisplayVersion,
    [int]$VersionCode,
    [string]$KeyStore = "$env:LOCALAPPDATA\Xamarin\Mono for Android\Keystore\Span\Span.keystore",
    [string]$KeyAlias = 'Span'
)

# Native tools write progress to stderr; exit codes are checked explicitly instead.
$ErrorActionPreference = 'Continue'
$sdk = 'C:\Program Files (x86)\Android\android-sdk'

function Fail([int]$code, [string]$message) {
    Write-Output "RESULT=failed"
    Write-Output $message
    exit $code
}

function Show-LogTail([string]$log) {
    Get-Content $log | Select-String -Pattern ' error |error [A-Z]+[0-9]+' | Select-Object -Last 15 | ForEach-Object { $_.Line }
    Get-Content $log -Tail 5
}

# The app project.
if (Test-Path $App -PathType Container) {
    $projects = @(Get-ChildItem $App -Recurse -Filter '*.maui.csproj' |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' -and $_.Name -like 'client.mobile.*' })
    if ($projects.Count -ne 1) {
        Fail 1 "Pass the app csproj with -App; found $($projects.Count) candidates: $($projects.FullName -join ', ')"
    }
    $csproj = $projects[0].FullName
} else {
    $csproj = (Resolve-Path $App -ErrorAction Stop).Path
}
$appRepo = (git -C (Split-Path $csproj) rev-parse --show-toplevel).Replace('/', '\')
if (-not $FwCore) { $FwCore = Join-Path (Split-Path $appRepo) 'rndfwcore' }
$FwCore = (Resolve-Path $FwCore -ErrorAction Stop).Path

# The keystore password, from this process or the user environment (setx writes the latter).
if (-not $env:SPAN_KS_PASS) { $env:SPAN_KS_PASS = [Environment]::GetEnvironmentVariable('SPAN_KS_PASS', 'User') }
if (-not $env:SPAN_KS_PASS) {
    Fail 2 "SPAN_KS_PASS is not set. Ask the user to run, in the Claude Code prompt: ! setx SPAN_KS_PASS '<password>'"
}
if (-not (Test-Path $KeyStore)) { Fail 1 "Keystore not found: $KeyStore" }

$logDir = Join-Path $env:TEMP 'signed-apk'
New-Item -ItemType Directory -Force $logDir | Out-Null

# 1. Framework Android assemblies in Release. The strong-name key container is not visible from
# agent shells, so the assemblies are signed from the .snk file (same public key token).
$runtimeConfig = Join-Path $FwCore 'BUILD\RUNTIME\dlls\android\configuration.txt'
if ($SkipFramework) {
    if (-not (Test-Path $runtimeConfig) -or (Get-Content $runtimeConfig -Raw).Trim() -ne 'Release') {
        Fail 1 "-SkipFramework: $runtimeConfig does not say Release. Run without -SkipFramework."
    }
} else {
    $log = Join-Path $logDir 'buildmobile.log'
    Write-Output "Building framework Android assemblies (Release), log $log"
    & (Join-Path $FwCore 'BUILD\BuildMobile.bat') Release '-p:KeyContainerName=' '-p:SignAssembly=true' "-p:AssemblyOriginatorKeyFile=$FwCore\BUILD\keys\span.framework.snk" *> $log
    if ($LASTEXITCODE -ne 0) { Show-LogTail $log; Fail 1 "BuildMobile.bat Release failed (exit $LASTEXITCODE), log $log" }
}

# 2. The app, signed with the Span key. Command-line properties win over the csproj, so this works
# for apps whose csproj has no signing block.
$log = Join-Path $logDir 'app.log'
$properties = @(
    "-p:FwCoreRoot=$FwCore\",
    '-p:AndroidKeyStore=true',
    "-p:AndroidSigningKeyStore=$KeyStore",
    "-p:AndroidSigningKeyAlias=$KeyAlias",
    '-p:AndroidSigningStorePass=env:SPAN_KS_PASS',
    '-p:AndroidSigningKeyPass=env:SPAN_KS_PASS'
)
if ($DisplayVersion) { $properties += "-p:ApplicationDisplayVersion=$DisplayVersion" }
if ($VersionCode) { $properties += "-p:ApplicationVersion=$VersionCode" }
Write-Output "Building $csproj (Release, signed), log $log"
& dotnet build $csproj -c Release -t:SignAndroidPackage @properties *> $log
if ($LASTEXITCODE -ne 0) { Show-LogTail $log; Fail 1 "App build failed (exit $LASTEXITCODE), log $log" }

$apk = Get-ChildItem (Join-Path (Split-Path $csproj) 'bin\Release') -Recurse -Filter '*-Signed.apk' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
# An incremental build that found nothing to do leaves the earlier APK, which still matches the inputs.
if (-not $apk) { Fail 1 "No *-Signed.apk under bin\Release after the build, log $log" }

# 3. Check the signer and read the version.
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $env:JAVA_HOME) {
    $jdk = Get-ChildItem 'C:\Program Files\Microsoft\jdk-*', 'C:\Program Files\Android\jdk\*' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem $_.FullName -Recurse -Filter 'java.exe' -Depth 3 -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = Split-Path (Split-Path $jdk.FullName) }
}
$certs = & (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs $apk.FullName 2>&1
$signer = ($certs | Select-String 'Signer #1 certificate DN: (.*)').Matches.Groups[1].Value
if ($signer -notmatch 'SPAN') { $certs | Select-Object -First 5; Fail 3 "APK is not signed with the Span key (signer: '$signer')" }

$badging = & (Join-Path $buildTools.FullName 'aapt.exe') dump badging $apk.FullName 2>&1
$package = [regex]::Match(($badging -join "`n"), "package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'")
$label = [regex]::Match(($badging -join "`n"), "application-label:'([^']+)'").Groups[1].Value -replace '[^A-Za-z0-9._-]', ''
if (-not $label) { $label = $package.Groups[1].Value }

# A name a tester can match to the code: label, version, app repo and commit, framework commit.
function Commit([string]$repo) {
    $sha = git -C $repo rev-parse --short HEAD
    # Only uncommitted code or project changes count; a local SetUserVars.bat or doc edit does not.
    if (git -C $repo status --porcelain --untracked-files=no -- '*.cs' '*.csproj' '*.xaml' '*.props' '*.targets' '*.json' '*.xml') { $sha += '-dirty' }
    return $sha
}
$repoName = (Split-Path $appRepo -Leaf) -replace '^rnd', ''
$name = "$label-$($package.Groups[3].Value)-$repoName-$(Commit $appRepo)-fwcore-$(Commit $FwCore).apk"
$named = Join-Path $apk.DirectoryName $name
Copy-Item $apk.FullName $named -Force

Write-Output "RESULT=ok"
Write-Output "APK=$named"
Write-Output "PACKAGE=$($package.Groups[1].Value)"
Write-Output "VERSION=$($package.Groups[3].Value) (code $($package.Groups[2].Value))"
Write-Output "SIGNER=$signer"
Write-Output "FRAMEWORK_RUNTIME=Release ($FwCore\BUILD\RUNTIME\dlls\android)"
exit 0
