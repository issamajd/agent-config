# Machine: span-dev-majd

Windows 11 work PC at SPAN. Notes that apply only to this machine go here.

## Skills

- The `mobile-screen-generator` skill generates.
- The `rndscripts-deliverable` skill turns a working SQL change into RNDSCRIPTS deliverable files (source dialect, schema/component split, converter check, TFVC checkout). Use it for any DB change that has to ship.
- The `xal-server` skill starts, stops, restarts and checks a repo's server.console from an agent shell (`XalServer.ps1`, Windows PowerShell 5.1). Use it instead of asking the user to click Start.

## Commits

- Never add a `Co-Authored-By` trailer for Claude or any other AI to commit messages. This is SPAN company policy and applies in every repo, even when a harness or skill asks for one.

## Shells

- Agent shells are not elevated. Anything that needs admin (writing protected folders, driving a window that runs elevated) goes to the user.
- `NoDefaultCurrentDirectoryInExePath=1` is set: inside `cmd /c`, call tools as `.\tool.exe` or prefix with `set NoDefaultCurrentDirectoryInExePath=&&`.
- Git Bash path conversion mangles `/Switch` arguments and Android device paths. Set `MSYS_NO_PATHCONV=1` for those commands, or run them from PowerShell.
- Never edit CRLF files with Git Bash `sed -i`: it silently rewrites them as LF-only. Use PowerShell raw I/O (`[IO.File]::ReadAllText` / `.Replace()` / `WriteAllText(path, text, New-Object Text.UTF8Encoding($false))`) and check that the CR count equals the LF count.
- `Test-NetConnection` reports false failures here. Probe ports with a real client: `curl -s -o /dev/null -w "%{http_code}\n" --max-time 25 <url>`.

## .NET builds

- The `span.framework` strong-name key container is not visible from agent shells (`CS7028 ... Keyset does not exist`). Build with `-p:KeyContainerName= -p:SignAssembly=true -p:AssemblyOriginatorKeyFile=<repo>\BUILD\keys\span.framework.snk`. It produces the same public key token (`df6ba8a58f791570`); the CS1616 warning is expected.
- Many SPAN csprojs set `EnableDefaultCompileItems=false`. Add a `<Compile Include="..." />` for every new `.cs` file, or the build fails with CS0246.

## XAL framework (rndfwcore) traps

- `DataFilter` fails fast when a value's runtime type disagrees with its declared `DataType` ("DataFilter 'X' is declared as A but the value is B"). Numerics widen into each other, `DataType.Unknown` is skipped, and bools or "0"/"1"/"true"/"false" strings pass for any type. An empty string does not.
- `FiltersHelper.ExtractFilters(DataRow)` types each filter from the SQL column type, so `filters[x].Value = <DateTime>` on a filter that came from an nvarchar column throws. Use `AddOrReplace` with a typed filter, and when this fires check the source tables' column types, not the screen metadata.
- `Filter.GetListFilter(..., params object[])` receives a `ColumnSchema` as an object (the implicit string conversion doesn't apply to `params object[]`). Mixing it with string literals throws "All types must match for the DataFilter". Pass `.Name`.
- `DataHelper.GetString(DBNull)` returns null, not "".

## XAL server (local dev)

- The running server.console loads logic DLLs from `<repo>\BUILD\RUNTIME\dlls\logic`, not from the project's bin folder. To test a logic change: `xal-server` stop, copy the rebuilt DLL there (or run `BUILD\DispatchAllFiles.bat`), `xal-server` start. The server runs fine non-elevated (Kestrel on 8001, DPAPI secrets); only a console the user started with "Run as administrator" is out of reach, and the skill reports that as exit code 3. Any public BL/BP class in a logic DLL is callable by name via reflection; no registration is needed.
- To find which copy of a DLL is live, use a non-destructive lock test: `[IO.File]::Open(path,'Open','ReadWrite','None')` in try/catch. Never `: > file`; it truncates the file to 0 bytes.
- "System Error: Contact admin" on a client is `server.errorfilter.ErrorFilter` masking the real exception. Set the ERRORFILTER module's `ShowErrors` StartUpParameter to true in `BUILD\RUNTIME\applications\server.config.xml` to see it.
- BP/BL exceptions on the mobile path are not written to `master.EVENTLOG` or `APPLICATIONLOG`. Without `ShowErrors` the stack trace only appears in the server.console window. Client-side errors (DataFilter checks, swallowed exceptions) only show in logcat under tag `DOTNET`; add a temporary `Console.WriteLine` in a silent catch to surface one.
- Even with `ShowErrors` the client gets the message without a stack, and the console window's text can't be read through UI Automation (`ServerLogsFromTrace.log` from server.console.dll.config is never written). To get the stack, temporarily make the BL entry method rethrow `new MethodException(ex.ToString())`, then remove it. Put `ShowErrors` back to false afterwards.
- The shared dev databases have one SQL login per schema, passwords in `BUILD\RUNTIME\secrets.json` (`DB_master`, `DB_whs1`, `DB_branch1`, ...). The `master` login cannot read `whs1` tables (SELECT permission denied); query warehouse tables as `whs1`. sqlcmd: `C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe -S 192.168.50.156\DEVSQL2019 -U <login> -C -d <db>` with the password in `SQLCMDPASSWORD`.

## Base runtime replay (pipeline-shared)

- `BUILD\Update-BaseRuntime.ps1` installs the parent versions pinned in `BUILD\baseruntime.lock.json` and never picks up a newer parent by itself. After a parent publishes, run `.\Update-BaseRuntime.ps1 -TargetVersion <new>` (try `-WhatIf` first) in each child's BUILD folder and commit the lock before running that repo's pipeline.
- `-TargetVersion` applies to every parent and fails if one lacks that version. To move a single parent, hand-edit its version in the lock, delete `BUILD\baseruntime\`, and run the script with no arguments. That route skips the changelog review, so check the lock diff for changed `trackedFiles` hashes yourself.
- A local edit to the gitignored `baseruntime\SetUserVars.bat` blocks the replay; `-Force` overwrites it. A `[merge needed]` flag with an empty `.diff` means there is nothing to merge.
- CI runs `git submodule update --remote`, so it always builds with the tip of pipeline-shared main. Don't push to pipeline-shared in the middle of a multi-repo close.

## TFVC and RNDSCRIPTS

- The TFVC client is `%LOCALAPPDATA%\Programs\tf.cmd` (Team Explorer Everywhere). It is not on PATH in agent shells and there is no `TF.exe`, so call it by full path: `& "$env:LOCALAPPDATA\Programs\tf.cmd" <command>`.
- `C:\PROJECTS\RNDSCRIPTS` is a server workspace (`SPAN-DEV-MAJD`, collection `http://devops:8050/rndscripts/`). Files are read-only until `tf checkout`, and `tf checkout` can pull the server copy over an uncommitted local edit, so re-apply edits after checking out. `tf diff` needs `TF_DIFF_COMMAND` (unset); compare with `tf print` instead, redirected through `cmd /c "tf print ... > file"` so the CRs survive.
- Deliverable DB scripts live in RNDSCRIPTS, not in git: `<PRODUCT>\...\Common\<Incremental Scripts version>\<Schema>\<Component>\<ObjectType>.sql`. A repo's `dbscripts\` or `sql\` folder is scratch. `ConvertScripts.cmd` runs object types in this order: Tables, SetupData, Synonyms, OtherDBObjects, Views.
- Write the `Common` scripts in the Oracle-style source dialect: `NVARCHAR2`, `NUMBER(18,0)`, `NVL`, `SYSDATE`, `||`, `MODIFY`, `DROP VIEW` + `CREATE VIEW` instead of `ALTER VIEW`, `--` comments only, no semicolons, and a lone `/` line after every statement. MSSQL idioms (`ISNULL`, `IF EXISTS`, `DECLARE`, `COL_LENGTH`) don't parse.
- `SQLScriptConverter.exe` (ANTLR) has no `EXISTS` and no correlated subqueries; a parse failure produces no output file at all. So scripts carry no idempotency guards: each patch runs once, in `PatchList` order. Provider-specific code goes in a `<Name>.ORACLE` / `<Name>.MSSQL` sibling, which is appended after the converted output.
- A customer's `SetEnvVars.cmd` `PatchList` must list the full MAIN base patches first, then the customer's custom patches. Never trim the base list.
- Run the converter and the `.cmd` launchers from PowerShell: `& ".\Check X Scripts.cmd"` (`cmd /c` mangles spaced names), and validate a single file with `& "C:\PROJECTS\RNDSCRIPTS\CURRENT\SQLScriptConverter\SQLScriptConverter.exe" /CONVERT MSSQL <file>`.

## Android emulator (MEmu)

- adb: `C:\Program Files (x86)\Android\android-sdk\platform-tools\adb`. MEmu: `D:\Program Files\Microvirt\MEmu`, serial `127.0.0.1:21503` (API 28, x86_64, rooted).
- Deploy a MAUI app with `dotnet build <app>.csproj -f net8.0-android -c Debug -t:Run`. A plain build plus `adb install` aborts at startup ("No assemblies found ... Fast Deployment") because Debug APKs leave the assemblies out; for a sideloadable APK add `-p:EmbedAssembliesIntoApk=true`.
- A startup crash loop with a `System.SR` StackOverflow and no app frames means a corrupt fast-deploy base. Fix it with `-t:Run -p:EmbedAssembliesIntoApk=true -p:AndroidFastDeploymentType=`. Don't follow a bare `dotnet build` with an incremental `-t:Run` onto the device.
- Never `adb uninstall`: it wipes the app's connection settings. The server endpoint lives per device in `shared_prefs` and goes stale when the host IP changes. Use `adb reverse tcp:<port> tcp:<port>` and point the app at `127.0.0.1` (force-stop the app before editing `shared_prefs`).
- A Debug Android build that sits idle (no CPU, no child processes, last log line "Found Xamarin.Android ...") is stuck in `GetPrimaryCpuAbi`, waiting on the adb server for the device's ABI. Test adb with a call that reaches the device, under a timeout: `adb -s 127.0.0.1:21503 shell getprop ro.product.cpu.abi`. `adb devices` still lists the emulator as `device` while `shell` hangs, so it proves nothing.
- The cure for a hung adb (a stuck build, or a plain `devices`/`shell` call that hangs): kill the build, `adb kill-server`, `adb start-server`, `adb connect 127.0.0.1:21503` (MEmu doesn't come back on its own), check `shell getprop` answers, then rebuild.
- `adb kill-server` drops every `adb reverse`; the app then fails with "Server Response Error: Connection failure". Run `adb reverse tcp:8001 tcp:8001` again and check `adb reverse --list`.
- `-t:Run` relaunches the app a few seconds after the build reports done, so input sent right away lands in the old process. After a deploy, force-stop and relaunch the app yourself (`am force-stop`, then `monkey -p <package> -c android.intent.category.LAUNCHER 1`) before driving it.
- ITMS app (`com.span.client.mobile.itms.maui`) login, when driving it with `adb shell input`: an "Update Available" screen can come first ("Maybe Later"); the username field keeps the last value (clear it with its x); the keyboard covers Sign In, so send `keyevent 111` (Escape) before tapping it.
- A server.console restart, or the same user logging in from another client (the `tests\test.bpclient` fixture logs in as admin), ends the device session. The app shows nothing until the next page load, which then fails with "Object reference not set to an instance of an object". Don't run BP tests while driving or recording the emulator; restart the app and log in again after a server restart.
- Find tap targets with `uiautomator dump` (`adb shell uiautomator dump /sdcard/ui.xml`, then read the node bounds); each dump takes about 3 seconds. Screenshots: `adb exec-out screencap -p > file.png`.

## Azure DevOps Server

- Web root is `http://devops:8050`. Git remotes look like
  `ssh://devops:22/<Collection>/<Project>/_git/<repo>` (rndfwcore: collection `RNDFWCORE`,
  project `RNDFWCORE`, repo `rndfwcore`); the ssh host and port say nothing about the web port.
- The REST API accepts Windows auth from agent shells: `curl --negotiate -u : <url>`. No PAT is
  needed. Use `api-version=7.0`. Allowed writes: creating a pull request (with its title and
  description) and pull request thread comments. Never merge or complete a PR without Majd's
  explicit consent, and never upload files or attachments or edit work items through it.
- There is no `az` CLI on this machine; use curl. There is no `gh` either: wherever a skill says
  `gh pr ...`, use the PR commands below.

## Azure DevOps pull requests

- Base URL: `http://devops:8050/<Collection>/<Project>/_apis/git/repositories/<repo>/pullRequests/<id>`.
  Collection and project come from the repo's `git remote -v`.
- Diff: there is no diff endpoint. Fetch the PR's merge ref and diff locally:
  `git fetch origin refs/pull/<id>/merge:refs/remotes/origin/pr/<id>` then
  `git diff origin/<target>...origin/pr/<id>`. Source and target branches are in the PR JSON
  (`sourceRefName`, `targetRefName`).
- Create: `POST http://devops:8050/<Collection>/<Project>/_apis/git/repositories/<repo>/pullrequests?api-version=7.0`
  with `{"sourceRefName":"refs/heads/<branch>","targetRefName":"refs/heads/<target>","title":"...",
  "description":"...","isDraft":false}` (Content-Type `application/json; charset=utf-8`). The
  description is capped at 4000 characters. Check first that no PR exists for the branch:
  `GET .../pullrequests?searchCriteria.sourceRefName=refs/heads/<branch>`. The web page is
  `http://devops:8050/<Collection>/<Project>/_git/<repo>/pullrequest/<id>`.
- Comment: `POST <base>/threads?api-version=7.0` with body
  `{"comments":[{"parentCommentId":0,"content":"<markdown>","commentType":1}],"status":1}`.
  Every comment states which model wrote it (the babysit-pr reply header or the review-panel
  header). Reply to an existing thread with `POST <base>/threads/<threadId>/comments`.
- Checks: `GET <base>/statuses?api-version=7.0` and the build for `refs/pull/<id>/merge` under
  `_apis/build/builds?branchName=refs/pull/<id>/merge`. There is no watch command; loop with
  `sleep 60` in a tracked background command until no status is `pending`.
- Threads to resolve: `GET <base>/threads`; a thread is closed by `PATCH <base>/threads/<threadId>`
  with `{"status":4}` (fixed) or `{"status":2}` (won't fix) and a reply saying why.
