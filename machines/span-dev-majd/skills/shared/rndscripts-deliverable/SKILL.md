---
name: rndscripts-deliverable
description: >-
  Turn a working SQL change (a file in a repo's dbscripts/ or sql/ folder, a
  pasted script, or a schema change made while coding) into the deliverable
  form the RNDSCRIPTS TFVC workspace expects: Oracle-style source dialect,
  split by object type into <Schema>/<Component>/<ObjectType>.sql under the
  product's "In Progress" incremental folder, validated with
  SQLScriptConverter, and checked out in TFVC. Use WHENEVER the user says
  "move this SQL to RNDSCRIPTS", "create the incremental script", "add the DB
  patch", "deliver this script", "convert this to the scripts format", or a
  code change needs a table, column, view, index or setup-data change
  delivered. Do NOT use for ad-hoc queries, test data, or scripts that stay in
  the repo.
---

# RNDSCRIPTS deliverable

A repo's `dbscripts/` or `sql/` folder is scratch. The deliverable is a set of
files in `C:\PROJECTS\RNDSCRIPTS\CURRENT\<PRODUCT>\...` written in a
restricted Oracle-style source dialect that `SQLScriptConverter.exe` turns
into MSSQL, Oracle or Postgres at release time. The converter is an ANTLR
grammar: a statement it cannot parse yields no output file and no non-zero
exit code, so validation is a required step, not a nicety.

`reference.md` beside this file has the dialect cheat sheet, the accepted
statement list, the loader execution order, and the repo-to-product map. Read
it once per session before converting anything.

## Fixed facts

- RNDSCRIPTS root: `C:\PROJECTS\RNDSCRIPTS\CURRENT`. TFVC server workspace;
  files are read-only until checked out.
- Converter: `C:\PROJECTS\RNDSCRIPTS\CURRENT\SQLScriptConverter\SQLScriptConverter.exe`.
  `/CHECK <folder> /R` validates without writing; `/CONVERT MSSQL <file>`
  writes `<file>.MSSQL` beside the input. Exit code is 0 even on errors.
- TFVC client: `& "$env:LOCALAPPDATA\Programs\tf.cmd" <command>` from
  PowerShell. Not on PATH, no TF.exe.
- Helper: `Check-RndScripts.ps1 -Path <folder>` in this skill folder runs the
  check and exits non-zero when any file is in error.

## Procedure

1. **Find the destination.** Map the repo to its RNDSCRIPTS product with the
   table in `reference.md`. For a product core use `<PRODUCT>\MAIN\Common`,
   for a customer `<PRODUCT>\CUSTOM\<CUSTOMER>\Common`. Inside, pick the one
   folder whose name contains `In Progress`. If none exists, stop and ask:
   opening a new version folder is a release decision. If the customer has no
   CUSTOM folder yet, say so and ask before creating one from
   `TEMPLATE Custom Incremental Scripts`.

2. **Pick schema and component.** Schemas come from that product's
   `Common\DefineSchemas.cmd` (FAMS and S4Assets: Master, Interface, Data;
   inventory products: Master, Interface, Branch, Warehouse). The component
   folder is `<Scope>_<Level><Module>`, for example `Server_APP`,
   `Common_APP`, `Server_APPInterface`, `Common_APPMobile`; the framework
   uses level `FW`. Do not guess: grep the object name in
   `Full Scripts*` and earlier `Incremental Scripts*` folders of the same
   product and put the change where the object was created. A new object goes
   with the tables it joins to. Say which component you chose and why.

3. **Split by object type.** One file per type inside the component folder,
   appending to an existing file if the template already has it:
   `Tables.sql` (CREATE, ALTER, DROP TABLE and constraints),
   `OtherDBObjects.sql` (indexes, sequences, triggers, procedures, functions),
   `SetupData.sql` (INSERT, UPDATE, DELETE), `Views.sql` (DROP VIEW then
   CREATE VIEW, never ALTER VIEW), `Synonyms.sql` (Common_* components only).
   The loader runs all Tables files first, then OtherDBObjects, SetupData,
   Views, so a view may reference a table added in the same patch but setup
   data may not reference a view.

4. **Rewrite to the source dialect** using the cheat sheet. The hard rules:
   `NVARCHAR2`, `NUMBER(p,s)`, `DATE`, `BLOB`; `NVL`, `SYSDATE`, `||`;
   `ALTER TABLE ... MODIFY`; `--` comments only; no semicolons; a lone `/`
   line after every statement; no `IF`, `EXISTS`, `DECLARE`, `BEGIN`,
   `GO`, `COL_LENGTH`, `ISNULL`, `GETDATE`, square brackets, or correlated
   subqueries. Each patch runs exactly once, in `PatchList` order, so there
   are no idempotency guards by design. Schema parameters are `&1`, `&2`
   (they become `$(P1)` in MSSQL output).

5. **Isolate what the grammar cannot express.** Anything provider-specific
   (a filtered index, a computed column, a MERGE) goes in a sibling named
   after the file with the provider as extension, `Tables.MSSQL` and
   `Tables.ORACLE`, written in that provider's native syntax with `GO` or `/`
   as appropriate. The release build appends the sibling after the converted
   output of the same file. If you write one provider's sibling, write the
   other's too or state why not.

6. **Check out, then edit.** `tf checkout <file>` for every file you will
   change, `tf add <file>` for new ones (`tf add /recursive <folder>` for a
   new patch folder). Checkout can pull the server copy over a local edit, so
   check out first and write second. Never `tf checkin` unless asked.

7. **Validate.** Run `Check-RndScripts.ps1 -Path "<patch folder>"` (or the
   converter's `/CHECK ... /R`) and read the last line, `Checked N files with
   M files in error`. Fix until M is 0. To eyeball the generated SQL, copy the
   file to the scratchpad and run `/CONVERT MSSQL` there; never run `/CONVERT`
   inside RNDSCRIPTS, because stray `*.sql.MSSQL` files in `Common` are copied
   into the release output.

8. **Leave version bookkeeping alone unless asked.** The `APPVER` insert in
   `Master\Server_APP\SetupData.sql` is written once when a version closes,
   not per change. `PatchList` in `<PRODUCT>\...\<PROVIDER>\SetEnvVars.cmd`
   changes only when a new folder is created, and a customer's list keeps the
   full MAIN list first.

9. **Report** the files touched with full paths, the check summary line, the
   component choice and its evidence, and anything that landed in a provider
   sibling. If the original file in the repo should now be deleted or kept as
   scratch, say which.

## Don'ts

- Do not paste MSSQL into a `.sql` file and hope the converter copes; it will
  silently produce nothing.
- Do not add `IF NOT EXISTS` style guards. If a re-run matters, say so and let
  the user decide how to handle it.
- Do not create version folders, rename `In Progress` folders, or edit
  `PatchList` without being asked.
- Do not run `/CONVERT` inside the RNDSCRIPTS tree.
- Do not use `sed -i` on these files; they are CRLF. Write them with
  PowerShell raw I/O and keep CRLF.
