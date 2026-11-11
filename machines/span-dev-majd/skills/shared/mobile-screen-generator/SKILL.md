---
name: mobile-screen-generator
description: Generates a .NET MAUI mobile screen (metadata SQL, ViewModel, controller, page, constants, DI, route, menu) on the SPAN mobile framework from a screen spec, following the target project's own conventions. Use when the user asks to generate or build a mobile page from a spec, or runs it by name. Not for writing the spec itself (in rnditmscore, itms-mobile-spec does that for ITMS legacy flows).
argument-hint: <spec file path>
---

# Mobile screen generator

Turns one screen spec ([TEMPLATE_Screen_Specification.md](TEMPLATE_Screen_Specification.md)) into a working page. Framework facts and templates are in [REFERENCE.md](REFERENCE.md); read it before generating.

## Rules

- **Build what the spec says, nothing more.** No extra fields, buttons, validations or behaviour.
- **Ask instead of guessing.** A missing field type, filter name, value list source, prompt text or navigation target is a question to the user, listed all at once before generating anything.
- **The project's code is the convention.** When REFERENCE.md and the project's existing pages differ (namespaces, constants, DI style, SQL style), follow the project.
- **Don't touch other screens.** Only add to shared files (constants, DILoader, AppController); never change existing entries.
- **No pattern, no invention.** If the spec needs something neither REFERENCE.md nor an existing page shows, say so and ask how to build it.

## Workflow

### 0. Learn the project

Find the MAUI app project (the csproj with `<UseMaui>`) and read:

1. The csproj: `RootNamespace`, and whether it lists `.cs` files explicitly (`EnableDefaultCompileItems=false` means every new file needs a `<Compile Include>`).
2. `constants/`: which files exist (`ScreenNames`, `PageNames`, `ControllerNames`, `MethodNames`, `BPNames`, `ModelFields*.cs`).
3. `engines/DILoader.cs` and `AppController.cs`: how pages and controllers are registered and routed.
4. The models folder layout (flat or per feature).
5. Two or three existing pages closest to the spec (same display type, tabs, grid, row navigation): their page, controller, ViewModel and `screens-defs-*.sql`. These are the style to copy.
6. How the existing pages tell the user an action worked (rnditmscore: `await this.DisplaySnackbar("... successfully")` after every successful confirm). If the spec says to show nothing where the existing pages show this, ask before following the spec.
7. How the existing menu rows are inserted, if the spec has a menu entry.
8. The screen profile codes already used, so the new one is unique.

Write down the conventions you found in a short list; it goes in the final report.

### 1. Check the spec

Every ⭐ section filled; every field has a type, control and group; every combobox has a value list; every server call (section 9a, wherever it is triggered) lists its arguments and its filters by name, type and value; every prompt has its text; every navigation has a target and what it passes. Ask for whatever is missing, then stop until answered.

If the project has a rule that server calls are tested before the screen (rnditmscore: `tests/test.bpclient`, see its AGENTS.md), check each call in 9a has a test, and say which don't.

### 2. Generate

In this order, writing the files directly:

1. `pages/{Feature}/screens-defs-{Name}Page.sql`: display definition, fields, value lists, appearance rules and overrides, validations, menu row.
2. Constants.
3. ViewModel.
4. Controller.
5. Page.
6. DILoader and AppController entries.
7. `<Compile Include>` entries if the csproj needs them.

### 3. Build

Build the app project for Android (`dotnet build <app>.csproj -f net8.0-android`, or the target framework the csproj uses). Check the project's AGENTS.md for build prerequisites first (rnditmscore needs rndfwcore's Android assemblies built with `BuildMobile.bat`). Fix errors in the generated code until it builds with no new warnings. If the build fails on framework references rather than generated code, report it; don't work around it. Don't run the SQL against a database unless the user asks.

Then check what the build can't:

- `DATADISPLAYNAME` in the SQL equals `nameof(Page)`.
- Every route level is registered, and both the page and the controller are in DI.
- Each `ValidateThenRunAsync` action name equals an `ACTIONNAME` in the SQL.
- Every hand-written button handler runs through `RunExclusiveAsync`, and every `SetBackAction` gets the action itself, not a `RunExclusiveAsync` wrapper (REFERENCE.md, Actions).
- `DataDisplayDataDefParentContainer`, every named group container and `EntityDefParentContainer` exist in `BuildPageLayout` with exactly those names.
- Every filter in a server call matches section 9a by name and type, including its "Sent when" condition.
- If the SQL has control type overrides and the user had it applied: `BPDataPanelControlAppearanceCRUD.Refresh` returns them for the page (an empty result means the database lacks the `DefaultAppearance` row; REFERENCE.md, DATAPANELAPPEARANCEDEFINITION).

When the user asks for a device check, drive MEmu with [memu.sh](memu.sh) (login, waits, screenshots, recordings); REFERENCE.md's last table lists what went wrong on the device before.

### 4. Report

- Files created and changed.
- The conventions followed (from step 0).
- Anything in the spec that had no pattern, and how it was handled after asking.
- What the user does next: apply the SQL, deploy, test on the device.
