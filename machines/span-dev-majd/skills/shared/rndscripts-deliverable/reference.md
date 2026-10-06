# RNDSCRIPTS reference

## Repo to product map

| Repo | RNDSCRIPTS product | Level | Customers folder |
| --- | --- | --- | --- |
| rndfwcore | `FW` | `FW` | none |
| rnds4assets | `S4ASSETS` | `APP` | `S4ASSETS\CUSTOM` (empty) |
| rndfamscore | `FAMSv2` | `APP` | `FAMSv2\CUSTOM\{ADIC,MOCA,...}`; no QF, PCFC, QCC or SZGMC folder yet |
| rndfamsintegrationerpcore | `FAMSv3_Integration_ERP\ORACLE_BI` or `ORACLE_UNI` | `APP` | `FAMSv3_Integration_ERP\CUSTOM\QF` |
| rndinventorycore | `INVENTORY` | `APP` | `INVENTORY\CUSTOM` (empty) |
| rndsmcscore, etisalat | `SMCS` | `APP` | `SMCS\CUSTOM\{EKFC,ETISALAT,MONDELEZ}` |
| rndmfscore | `MFS` | `APP` | `MFS\CUSTOM\{BFL,DNP,EKFC,IIG,MONDELEZ,TAMER}` |
| rndptlcore | `PICKTOLIGHT` | `APP` | `PICKTOLIGHT\CUSTOM\...` |
| rndmfsptlintegrationcore | `MFSPTLIntegration` | `APP` | `MFSPTLIntegration\CUSTOM\{BFL,TRILOGI}` |
| rnds4wes, proconnect | `S4WES` | `APP` | `S4WES\CUSTOM\PROCONNECT` |
| rnditmscore | `ITMS` | `APP` | `ITMS\CUSTOM\...` |
| rnddtscore, rnducamcore | `DTS` | `APP` | `DTS\CUSTOM\{BankAudi,Cambridge,RAK}` |

The in-progress folder name varies by product (`Incremental Scripts in
Progress`, `Incremental Scripts In Progress (vs2022)`, `WES Incremental
Scripts in Progress (vs2022)`, `MFS Incremental Scripts In Progress (vs2022)`).
List `<PRODUCT>\MAIN\Common` and match on `In Progress`.

## Folder layout

```
<PRODUCT>\MAIN\Common\<Incremental Scripts ... In Progress>\
  <Schema>\                      Master | Interface | Data | Branch | Warehouse  (see Common\DefineSchemas.cmd)
    <Scope>_<Level><Module>\     Common_APP, Common_APPMobile, Server_APP, Server_APPInterface, Server_APPMobile
      Tables.sql
      OtherDBObjects.sql
      SetupData.sql
      Views.sql
      Synonyms.sql               Common_* only
      Tables.MSSQL / Tables.ORACLE   optional provider-native siblings, appended after the converted file
```

The template zip ships every file empty. Empty files are deleted at release
time, so leave untouched ones alone.

## Loader execution order

`Tools\LoadSchema.cmd` runs, per schema and per patch folder, the loops
`for file in AppSQLFiles / for level in AppLevels / for module in AppModules /
for scope in AppScopes` and executes `<Schema>\<scope>_<level><module>\<file>.sql`
when it exists. `AppSQLFiles` comes from the product's `Tools\SetAppVars.cmd`
and is `Tables, OtherDBObjects, SetupData, Views` for the products (the
framework adds `CrossRefGrants` before `SetupData`). Consequences:

- Every Tables.sql in the patch runs before any SetupData.sql or Views.sql.
- Within one file type, `APP` level runs after `FW`, module `""` runs before
  `Interface` and `Mobile`, and `Common` runs before `Server`.
- Patches run in `PatchList` order from `<PROVIDER>\SetEnvVars.cmd`, each once.

## Accepted statements

The grammar's top level accepts only: `GRANT`, `ALTER`, `CREATE`, `DROP`,
`UPDATE`, `INSERT`, `DELETE`, `TRUNCATE`, separated by a lone `/` line.
Everything else fails with `mismatched input 'X' expecting {...}`. Known
non-starters: `IF`, `BEGIN`, `DECLARE`, `SET`, `EXEC`, `MERGE`, `WITH`,
`PRINT`, `USE`, `GO`, and `EXISTS (...)` anywhere in a predicate
(`no viable alternative at input 'EXISTS ('`).

## Dialect cheat sheet (MSSQL you have -> source you write)

| MSSQL | Source dialect | Converter emits for MSSQL |
| --- | --- | --- |
| `NVARCHAR(50)` | `NVARCHAR2(50)` | `NVARCHAR(50)` |
| `NUMERIC(18,3)`, `INT`, `BIGINT` | `NUMBER(18,3)`, `NUMBER(18,0)` | `NUMERIC(18,3)` |
| `DATETIME` | `DATE` | `DATETIME` |
| `IMAGE`, `VARBINARY(MAX)` | `BLOB` | `IMAGE` |
| `ISNULL(a, b)` | `NVL(a, b)` | `ISNULL(a,b)` |
| `GETDATE()` | `SYSDATE` | `GetDate()` |
| `a + b` (strings) | `a \|\| b` | `a + b` |
| `ALTER TABLE t ALTER COLUMN c ...` | `ALTER TABLE t MODIFY c ...` | `ALTER COLUMN` |
| `ALTER VIEW v AS ...` | `DROP VIEW v` `/` `CREATE VIEW v AS ...` | both statements |
| `;` or `GO` | lone `/` line | `GO` |
| `[Column]` | `COLUMN` (no brackets) | bare identifier |
| `$(P1)` schema parameter | `&1` | `$(P1)` |
| `IF COL_LENGTH(...) IS NULL ALTER TABLE ...` | plain `ALTER TABLE ...`, no guard | n/a |
| `WHERE EXISTS (SELECT ...)` | rewrite as `IN (SELECT ...)` or a join, or move to a `.MSSQL`/`.ORACLE` sibling | n/a |

Verified example. Source:

```sql
ALTER TABLE ASSET ADD NEWCOL NVARCHAR2(50)
/
ALTER TABLE ASSET MODIFY OLDCOL NUMBER(18,0)
/
INSERT INTO VALUELIST (TYPENAME, LISTNAME, ITEMVALUE, CREATEDDATE) VALUES ('T', 'L', 'V', SYSDATE)
/
DROP VIEW VW_TEST
/
CREATE VIEW VW_TEST AS SELECT A.ASSETID, NVL(A.DESCR, 'x') || 'y' AS D FROM ASSET A
/
```

`/CONVERT MSSQL` output:

```sql
ALTER TABLE ASSET ADD NEWCOL NVARCHAR(50)
GO
ALTER TABLE ASSET ALTER COLUMN OLDCOL NUMERIC(18,0)
GO
INSERT INTO VALUELIST (TYPENAME,LISTNAME,ITEMVALUE,CREATEDDATE) VALUES ('T','L','V',GetDate())
GO
DROP VIEW VW_TEST
GO
CREATE VIEW VW_TEST
AS SELECT A.ASSETID, ISNULL(A.DESCR,'x') + 'y' AS D
FROM ASSET AS A
GO
```

Real patch samples for tone and layout:

```sql
-- Data\Server_APP\Tables.sql
ALTER TABLE RETIREMENTREQUESTDETAIL ADD COSTOFSALE NUMBER(18, 3) NULL
/
ALTER TABLE RETIREMENTREQUESTDETAIL ADD RETIREMENTACTION NVARCHAR2(30) NULL
/

-- Master\Server_APP\SetupData.sql  (written once per release close, not per change)
INSERT INTO APPVER (APPLICATION,CUSTOMLEVEL,VERSION,INSTALLDATE,CREATEDBY,CREATEDDATE)
	VALUES ('FAMSv3','-','8.1.7.0',SYSDATE,'admin',SYSDATE)
/
```

## Validation commands

```powershell
# whole patch folder, read-only, prints "Checked N files with M files in error"
& "C:\PROJECTS\RNDSCRIPTS\CURRENT\SQLScriptConverter\SQLScriptConverter.exe" /CHECK "<patch folder>" /R

# one file, writes <file>.MSSQL beside it: only in the scratchpad, never inside RNDSCRIPTS
& "C:\PROJECTS\RNDSCRIPTS\CURRENT\SQLScriptConverter\SQLScriptConverter.exe" /CONVERT MSSQL "<scratch copy>.sql"
```

From Git Bash prefix the call with `MSYS_NO_PATHCONV=1` so `/CHECK` and
`/CONVERT` are not rewritten as paths.

## TFVC commands

```powershell
$tf = "$env:LOCALAPPDATA\Programs\tf.cmd"
& $tf status                                   # pending changes in the workspace
& $tf checkout "<file>"                        # before editing an existing file
& $tf add "<file>"                             # new file
& $tf add /recursive "<new folder>"            # new patch or customer folder
& $tf undo "<file>"                            # drop a pending change
```

`tf diff` needs `TF_DIFF_COMMAND` (unset); compare with `tf print` redirected
through `cmd /c "... > file"` so the CRs survive.
