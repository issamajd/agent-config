---
name: signed-apk
description: >-
  Build a Release APK of a SPAN MAUI app (S4Assets/FATS360, S4WES, ...) signed with the Span
  keystore, from the current rndfwcore and app checkouts, ready to send to testers; optionally
  install it on MEmu without losing the app's server settings. Use when the user asks for a
  "signed APK", "release APK", "an APK for testing/QA/the client", or to install a release build
  on the emulator. Not for Debug deploys while developing (use dotnet build -t:Run).
---

# Signed APK

Two scripts beside this file. Run them with PowerShell 7 (`pwsh`, the default shell here).

## 1. Check the inputs

- **Commits**: the APK is built from whatever is checked out. Confirm with the user which branch of
  each repo they want (usually `dev`), `git fetch`, and report how far behind `origin` each one is.
  Uncommitted changes go into the APK and add `-dirty` to its name.
- **Keystore password**: `Build-SignedApk.ps1` reads `SPAN_KS_PASS` from the process, else from the
  user environment. Never ask for the password in chat and never print it. If it is missing (exit
  code 2), ask the user to run this in the Claude Code prompt (the `!` prefix runs Git Bash, so
  PowerShell syntax fails there; `setx` works from both):

  ```
  ! setx SPAN_KS_PASS '<password>'
  ```

  The keystore is `%LOCALAPPDATA%\Xamarin\Mono for Android\Keystore\Span\Span.keystore`, alias `Span`.
  The JDK 8 on this machine cannot open it (modern PKCS12), so the build's signing step is the
  password check.

## 2. Build

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\skills\signed-apk\Build-SignedApk.ps1" -App D:\GitProjects\rnds4assets-dev
```

- `-App`: the app repo root, or its `*.maui.csproj`.
- `-FwCore`: the rndfwcore checkout; defaults to `rndfwcore` next to the app repo, as the app csproj
  assumes.
- `-SkipFramework`: skip `BuildMobile.bat Release`. Only use it when `RUNTIME\dlls\android` already
  holds a Release build of the wanted framework commit.
- `-DisplayVersion 1.0.1 -VersionCode 2`: optional overrides of the csproj version, for when testers
  need to tell builds apart. Android refuses a lower version code than the one installed.

It takes about 20 minutes: `BuildMobile.bat Release` builds about 24 framework projects twice (Debug,
then Release). The app build takes about 5 minutes. Run it in the background. Logs are in
`%TEMP%\signed-apk\`. On success it prints `RESULT=ok` and the `APK=` path, named
`<label>-<version>-<repo>-<commit>-fwcore-<commit>.apk`, next to the build output. It also prints
the signer, which must be `CN=SPAN, C=AE`; the script fails with exit code 3 otherwise.

Afterwards `rndfwcore\BUILD\RUNTIME\dlls\android` holds Release framework assemblies. Debug app
builds still work against them. Tell the user, and rerun `BUILD\BuildMobile.bat` (Debug) if they want
to debug into the framework.

## 3. Install on MEmu (optional)

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.claude\skills\signed-apk\Install-OnMemu.ps1" -Apk <APK path>
```

A Span-signed APK cannot replace a debug-signed install (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), and
uninstalling wipes the app's server settings. MEmu's `adb shell` runs as root, so the script copies
`shared_prefs` out, uninstalls, installs and restores them. The same applies in reverse: going back
to a Debug deploy also needs this. It keeps the backup in `%TEMP%\memu-prefs-<package>-<time>`.

Then smoke test: launch, sign in, open a screen, use an editor, a lookup and a search. Check that
`adb logcat -d` has no `FATAL EXCEPTION`, `E AndroidRuntime` or `E DOTNET` lines. The server must be
running (`xal-server` skill) and `adb reverse tcp:8001 tcp:8001` must be in place.

## Hand-off

Give the user the APK path, both commits, the version and the signer. Say whether it was installed
and smoke-tested, and that `RUNTIME\dlls\android` is now Release.
