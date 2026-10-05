# Mobile Screen Creation - Complete Reference Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Screen Layout Structure](#screen-layout-structure)
3. [SQL Metadata Tables Reference](#sql-metadata-tables-reference)
4. [Step-by-Step Screen Creation Process](#step-by-step-screen-creation-process)
5. [Code Templates](#code-templates)
6. [Complete Working Example](#complete-working-example)
7. [Best Practices and Conventions](#best-practices-and-conventions)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Architecture Overview

### Framework: Metadata-Driven Dynamic UI Generation

The mobile application uses a **metadata-driven architecture** where screens are built dynamically from SQL table definitions rather than hard-coded UI elements. This allows rapid development and changes without code recompilation.

### Core Principle: MVC + MVVM Hybrid Pattern

Every screen consists of three components:

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INPUT                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  PAGE (View)                                                     │
│  - Inherits from BaseContentPage                                │
│  - Builds UI layout (metadata-driven + custom)                  │
│  - Handles user interactions                                    │
│  - Calls Controller methods on button clicks                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  CONTROLLER (Business Logic)                                    │
│  - Inherits from BaseController                                 │
│  - Manages ViewModel                                            │
│  - Handles server communication                                 │
│  - Orchestrates navigation                                      │
│  - Wraps operations with IsBusyFor() for loading state          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  VIEWMODEL (Data Binding)                                       │
│  - Inherits from BaseViewModel/DynamicViewModel/GridViewModel   │
│  - Holds form data in DynamicFilters collection                 │
│  - Holds grid data in DataRows collection                       │
│  - Implements INotifyPropertyChanged for UI updates             │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  SQL METADATA                                                    │
│  - DATADISPLAYDEFINITION: Screen type (Panel/CardsGrid/Both)    │
│  - DATADISPLAYDATADEFINITION: Field properties + include flags  │
│  - DATADISPLAYVALUELISTDEFINITION: Dropdown data sources        │
│  - DATAPANELAPPEARANCEDEFINITION: Visibility + control overrides│
│  - DATADISPLAYVALIDATIONDEF: Validation rules                   │
└─────────────────────────────────────────────────────────────────┘
```

### Execution Flow: OnAppearing Method

When a page appears, the following sequence executes:

```
User navigates to screen
    ↓
OnAppearing() triggered
    ↓
InitializePage()
    ├─ BuildPageLayout() - Create static UI structure
    ├─ CreateRootLayout() - Add loading overlay
    └─ GetAllChildControls() - Collect control references
    ↓
RemoveDynamicContainers() - Clear previous dynamic controls
    ↓
BaseController.IsBusyFor() - Show loading overlay
    ↓
BaseController.InitializeAsync() - Custom initialization logic
    ↓
InitDataDisplayDataDefinitions()
    ├─ DataDisplayDefinitionService.GetDataDisplayDefinitionAsync(screenName)
    │   └─ Returns DataDisplayDefinition with DATADISPLAYTYPE (Panel/CardsGrid/PanelAndCardsGrid)
    ├─ If IncludesPanel: DataDisplayDataDefinitionService.GetDataDefinitionForDataDisplayAsync()
    │   ├─ Filters rows by PANELINCLUDE flag
    │   ├─ DataDefinitionBuilder converts rows to DataDefinition objects
    │   └─ Cache in m_DataDefinitions
    ├─ If IncludesCardsGrid: DataDisplayDataDefinitionService.GetCardsGridDataDefinitionsAsync()
    │   ├─ Filters rows by GRIDINCLUDE flag
    │   ├─ DataDefinitionBuilderForCardsGrid builds with [Column] binding paths
    │   └─ Cache in m_CardsGridDataDefinitions
    ↓
InitEntityDefinitions() (if EntityDefTableName set)
    ├─ Query: Entity definition tables with role filtering
    └─ Cache in m_EntityDataDefinitions collection
    ↓
ApplyControlTypeOverridesFromAppearanceAsync()
    ├─ Fetch PanelControlsAppearanceDefinition (DATAPANELAPPEARANCEDEFINITION)
    ├─ Match by DataName against m_DataDefinitions / m_EntityDataDefinitions / m_CardsGridDataDefinitions
    ├─ Override DataDefinition.EntryType if CONTROLTYPE is set
    └─ Apply CONTROLPARAMS (e.g., EntryStyleName, ConverterProfile) to DataDefinition
    ↓
PreparePageControlsAsync()
    ├─ CreateDefinitionsControls() (panel form)
    │   ├─ DataDefinitionControlBuilder.BuildControls()
    │   │   ├─ Group definitions by GroupName
    │   │   └─ Create UIGrid with controls for each group
    │   ├─ InitializeControls() - Apply properties (Mandatory, ReadOnly, etc.)
    │   └─ Globalize() - Translate labels
    ├─ SetDefaultValueIfSetOnDataDefinition() - Apply default values
    ├─ SetDataBindingOnChildControls() - Bind controls to ViewModel.DynamicFilters
    │   └─ For comboboxes: RegisterValueList() + RefreshValueListAsync()
    ├─ BuildCardsGridIfNeeded() (if CardsGridParentContainer set + card defs exist)
    │   ├─ AssignRowIndicesToFields() - compute 8-column row layout
    │   ├─ CreateCardsGridConfiguration() - page overrides for spacing/accent/tap
    │   ├─ DataCardDefinitionControlBuilder.BuildAndAddToParent()
    │   │   ├─ DataCardTemplateBuilder builds DataTemplate per EntryType
    │   │   │   (Label, CaptionValue, InlineCaptionLabel, Chip, Separator)
    │   │   └─ CollectionViewBuilder → UICollectionView added to parent container
    │   └─ Binds ItemsSource via GetCardsGridItemsSourceBinding()
    └─ UpdateChildControlsList() - Refresh ChildControls collection
    ↓
SetInitialControlFocus() - Auto-focus first field
    ↓
ManageControlAppearanceOnContextChangesAsync()
    ├─ Query: DATAPANELAPPEARANCEDEFINITION WHERE DATADISPLAYNAME = screenName
    ├─ UpdateControlsAppearance() - Apply visibility/enabled rules
    └─ Subscribe to ViewModel.PropertyChanged for dynamic updates
    ↓
AfterOnAppearing() - Custom post-initialization logic
    ↓
IsBusyFor() completes - Hide loading overlay
    ↓
Page Ready & Interactive
```

---

## Screen Layout Structure

### Four-Section Layout Pattern

Screens are composed of up to **four optional sections** arranged vertically:

```
┌───────────────────────────────────────────────────────────────┐
│  SECTION 1: FORM FIELDS (Always Present)                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ • Metadata-driven fields from SQL                       │  │
│  │ • Auto-generated: Entry, DatePicker, Combobox, Switch   │  │
│  │ • Bound to ViewModel.DynamicFilters                     │  │
│  │ • Grouped by DATAGROUPNAME                              │  │
│  │ • Sequenced by SEQUENCE column                          │  │
│  └─────────────────────────────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────┤
│  SECTION 2: ATTRIBUTES GRID (Optional)                        │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ • Dynamic entity attributes                             │  │
│  │ • Varies by entity type/role                            │  │
│  │ • Built using CreateAttributesGrid()                    │  │
│  │ • Fetched from entity definition tables                 │  │
│  └─────────────────────────────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────┤
│  SECTION 3: ACTION BUTTONS (Optional)                         │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ • "Search", "Submit", "Save", "Check Details", etc.     │  │
│  │ • Built using UIButtonBuilderHelper                     │  │
│  │ • Calls controller methods on click                     │  │
│  │ • May include validation before action                  │  │
│  └─────────────────────────────────────────────────────────┘  │
├───────────────────────────────────────────────────────────────┤
│  SECTION 4: DATA GRID (Optional)                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ • Search results or line item listings                  │  │
│  │ • Uses UIDataGrid with column definitions               │  │
│  │ • Bound to ViewModel.DataRows                           │  │
│  │ • Can include command columns with icons                │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

### Layout Configuration Examples

#### Simple Form + Buttons (2 Sections)
```csharp
UIGrid contentGrid = new()
{
    RowDefinitions =
    {
        new RowDefinition { Height = GridLength.Star },  // Form (fills space)
        new RowDefinition { Height = GridLength.Auto },  // Buttons (auto-sized)
    }
};

contentGrid.Add(new UIGrid(DataDisplayDataDefParentContainer), 0, 0);  // Form
contentGrid.Add(BuildActionsGridLayout(), 0, 1);                       // Buttons
```

#### Search Screen: Form + Buttons + Grid (3 Sections)
```csharp
UIGrid contentGrid = new()
{
    RowDefinitions =
    {
        new RowDefinition { Height = GridLength.Auto },  // Form (auto-sized)
        new RowDefinition { Height = GridLength.Auto },  // Buttons (auto-sized)
        new RowDefinition { Height = GridLength.Star },  // Grid (fills space)
    }
};

contentGrid.Add(new UIGrid(DataDisplayDataDefParentContainer), 0, 0);  // Form
contentGrid.Add(BuildActionsGridLayout(), 0, 1);                       // Buttons
contentGrid.Add(ResultGrid, 0, 2);                                     // Grid
```

#### Complete Screen: All 4 Sections
```csharp
UIGrid mainLayout = new()
{
    RowDefinitions =
    {
        new RowDefinition { Height = GridLength.Star },  // Form (scrollable)
        new RowDefinition { Height = GridLength.Star },  // Attributes
        new RowDefinition { Height = GridLength.Auto },  // Buttons
        new RowDefinition { Height = GridLength.Star },  // Grid
    }
};

mainLayout.Add(new UIScrollView(DataDisplayDataDefParentContainer), 0, 0);  // Form
mainLayout.Add(CreateAttributesGrid(), 0, 1);                               // Attributes
mainLayout.Add(BuildActionsGridLayout(), 0, 2);                             // Buttons
mainLayout.Add(ResultGrid, 0, 3);                                           // Grid
```

---

## SQL Metadata Tables Reference

### 0. DATADISPLAYDEFINITION

**Purpose**: Declares the screen and its display type. Every screen **must** have a row here.

**Key Columns**:

| Column Name | Data Type | Description | Example Values |
|------------|-----------|-------------|----------------|
| `DATADISPLAYNAME` | nvarchar(50) | Screen identifier (must match `nameof(Page)`) | 'RegistrationSearchResultsPage' |
| `DATADISPLAYTYPE` | nvarchar(50) | What the screen renders | 'Panel', 'CardsGrid', 'PanelAndCardsGrid' |

**Display Type Behavior**:
- `Panel` — `BaseContentPage` loads panel definitions only (`m_DataDefinitions`); form built via `UIDynamicPanelBuilderHelper`.
- `CardsGrid` — loads card definitions only (`m_CardsGridDataDefinitions`); card list built via `DataCardDefinitionControlBuilder` + `DataCardTemplateBuilder`.
- `PanelAndCardsGrid` — both surfaces loaded and built on the same page.

Without this row, `DataDisplayDefinitionService` returns null, `IncludesCardsGrid` is false, and no card list is built.

**Service**: `DataDisplayDefinitionService` / `I_DataDisplayDefinitionService` (BP: `BPDataDisplayDefinitionCRUD`).

---

### 1. DATADISPLAYDATADEFINITION

**Purpose**: Defines which fields appear on a screen and their properties.

**Key Columns**:

| Column Name | Data Type | Description | Example Values |
|------------|-----------|-------------|----------------|
| `DATADISPLAYNAME` | nvarchar(50) | Screen identifier (PRIMARY KEY) | 'RegistrationSearchPage' |
| `SCREENPROFILENAME` | nvarchar(50) | 4-letter screen code (PRIMARY KEY) | 'RSP', 'RRIP', 'RRDP' |
| `DATANAME` | nvarchar(50) | Field identifier (PRIMARY KEY) | 'REGISTRATIONREQUESTKEY' |
| `DATADESCRIPTION` | nvarchar(50) | User-facing label | 'Req. No', 'Product Name' |
| `DATAGROUPNAME` | nvarchar(50) | Group/section name | 'Main', 'Details', 'Filters' |
| `DATATYPE` | nvarchar(50) | Data type | 'String', 'Double', 'DateTime', 'Boolean', 'Unknown' |
| `ISVISIBLE` | char(1) | Initially visible | '1' or '0' |
| `ISMANDATORY` | char(1) | Required field | '1' or '0' |
| `ISREADONLY` | char(1) | Editable or not | '1' or '0' |
| `SEQUENCE` | numeric(18,0) | Display order within group | 1, 2, 3... |
| `WIDTH` | nvarchar(50) | Column span (1-8) | '4' (half), '8' (full) |
| `FILTERTYPE` | nvarchar(50) | Filter type | 'Value', 'List', 'Range' |
| `FILTERDEFAULTVALUES` | nvarchar(50) | Default value | '0', 'Active', NULL |
| `FILTERCOMPARISONTYPE` | nvarchar(50) | Comparison operator | 'Equal', 'Like', 'GreaterOrEqual', 'Range' |
| `VALUELISTDEFINITION` | nvarchar(50) | Reference to dropdown list | 'PRODUCTCODE', 'LOCATIONCODE' |
| `DATAFORMAT` | nvarchar(50) | Display format | 'n3' (3 decimals), 'd' (date) |
| `IMAGENAME` | nvarchar(50) | Icon/image name for field | 'confirmedQty', 'dropId', NULL |
| `PANELINCLUDE` | char(1) | Include field in panel form | '1', '0', or NULL |
| `GRIDINCLUDE` | char(1) | Include field in cards grid | '1', '0', or NULL |
| `GRIDCAPTION` | nvarchar(50) | Label override for cards | Overrides DATADESCRIPTION when set |
| `GRIDISVISIBLE` | char(1) | Visibility override for cards | Overrides ISVISIBLE when set |
| `GRIDSEQUENCE` | numeric | Ordering override for cards | Overrides SEQUENCE when set |
| `GRIDGROUPNAME` | nvarchar(50) | Grouping override for cards | Overrides DATAGROUPNAME when set |
| `CREATEDBY` | nvarchar(50) | Created by user | 'admin' |
| `CREATEDDATE` | datetime | Created date | CURRENT_TIMESTAMP |
| `MODIFIEDBY` | nvarchar(50) | Modified by user | NULL or 'admin' |
| `MODIFIEDDATE` | datetime | Modified date | NULL or timestamp |

**PANELINCLUDE / GRIDINCLUDE Splitting Rules**:
- `PANELINCLUDE = 1` → field included in panel; `GRIDINCLUDE = 1` → field included in cards
- Both NULL → field included on whichever surface the screen's `DATADISPLAYTYPE` requires
- Only sibling flag set (e.g. `GRIDINCLUDE=1`, no `PANELINCLUDE`) → field excluded from the other surface
- Used by `DataDisplayDataDefinitionService` to build separate `m_DataDefinitions` vs `m_CardsGridDataDefinitions`

**Control Type Determination Logic**:
- If `VALUELISTDEFINITION` is set → **Combobox** (dropdown)
- Else if `DATATYPE` = 'DateTime' → **DatePicker**
- Else if `DATATYPE` = 'Boolean' → **Switch** (toggle)
- Else if `DATATYPE` = 'Unknown' → **Label** (text)
- Else → **Entry** (text input)

**Example INSERT Statement**:
```sql
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY, IMAGENAME
) VALUES (
    'RegistrationSearchPage',           -- Screen name
    'Main',                             -- Group name
    'REGISTRATIONREQUESTKEY',           -- Field name
    'Req. No',                          -- Label
    1,                                  -- Visible
    'String',                           -- Data type
    'Value',                            -- Filter type
    NULL,                               -- Default value
    NULL,                               -- No value list (not a dropdown)
    'admin',                            -- Created by
    CURRENT_TIMESTAMP,                  -- Created date
    8,                                  -- Full width
    'Equal',                            -- Comparison type
    'RSP',                              -- Screen profile
    1,                                  -- First in sequence
    0,                                  -- Not readonly
    0,                                  -- Not mandatory
    NULL                                -- No image/icon
);
```

**Example INSERT with IMAGENAME** (for fields with icons):
```sql
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, DATAFORMAT, FILTERTYPE, FILTERCOMPARISONTYPE,
    CREATEDBY, CREATEDDATE, WIDTH, SCREENPROFILENAME, 
    SEQUENCE, ISREADONLY, ISMANDATORY, IMAGENAME
) VALUES (
    'ConfirmPickRequestPage',           -- Screen name
    'User Input',                       -- Group name
    'CONFIRMEDQTY',                     -- Field name
    'Confirmed Qty',                    -- Label
    1,                                  -- Visible
    'Integer',                          -- Data type
    'n0',                               -- Format (no decimals)
    'Value',                            -- Filter type
    'Equal',                            -- Comparison type
    'admin',                            -- Created by
    CURRENT_TIMESTAMP,                  -- Created date
    8,                                  -- Full width
    'CPR',                              -- Screen profile
    8,                                  -- Sequence
    0,                                  -- Not readonly
    1,                                  -- Mandatory
    'confirmedQty'                      -- Image/icon name
);
```

---

### 2. DATADISPLAYVALUELISTDEFINITION

**Purpose**: Defines dropdown lists and their data sources (comboboxes).

**Key Columns**:

| Column Name | Data Type | Description | Example Values |
|------------|-----------|-------------|----------------|
| `VALUELISTDEFINITION` | nvarchar(50) | List name (PRIMARY KEY) | 'PRODUCTCODE', 'LOCATIONCODE' |
| `TABLENAME` | nvarchar(50) | Source table | 'PRODUCT', 'LOCATION', 'VALUELIST' |
| `VALUECOLUMNNAME` | nvarchar(50) | Column with value | 'PRODUCTCODE', 'ITEMVALUE' |
| `DISPLAYCOLUMNNAME` | nvarchar(50) | Column to display | 'PRODUCTNAME', 'DESCRIPTION' |
| `DATACOLUMNS` | nvarchar(2000) | Additional data columns | NULL or comma-separated |
| `ADDBLANKITEM` | nchar(1) | Add blank option | '0' or '1' |
| `PARENTVALUESOURCE` | nvarchar(255) | Parent field filter | 'SUBCATEGORYCODE', NULL |
| `PARENTVALUECOLUMNNAME` | nvarchar(255) | Parent column to filter | 'PRODUCTSUBCATEGORY', NULL |
| `CONSTRAINTS` | nvarchar(2000) | SQL WHERE clause | 'PRODUCTSUBCATEGORY=~SUBCATEGORYCODE~' |
| `SELECTFIRST` | nchar(1) | Auto-select first item | '0' or '1' |
| `SELECTIFSINGLE` | nchar(1) | Auto-select if only one | '0' or '1' |
| `BPNAME` | nvarchar(50) | Business Process to call | 'BPProductCRUD', NULL |
| `METHODNAME` | nvarchar(50) | Method to call | 'Refresh', NULL |
| `SORTCOLUMNS` | nvarchar(50) | Sort columns | 'PRODUCTNAME', NULL |
| `SORTORDER` | nvarchar(50) | Sort order | 'ASC', 'DESC', NULL |
| `ISSEARCHABLE` | nchar(1) | Allow search in dropdown | '1' or '0' |
| `PRELOAD` | nchar(1) | Preload data on page load | '0' or '1' |
| `CREATEDBY` | nvarchar(50) | Created by user | 'admin' |
| `CREATEDDATE` | datetime | Created date | CURRENT_TIMESTAMP |

**Value List Types**:
1. **Main Table Source**: Data from application tables (PRODUCT, LOCATION, DEPARTMENT, etc.)
2. **VALUELIST Table**: Static lookup data (status codes, types, categories)

**Cascading Dropdowns**:
Use `PARENTVALUESOURCE` and `PARENTVALUECOLUMNNAME` to create parent-child relationships.

**Constraint Syntax**:
- Use `~FIELDNAME~` to reference other field values
- Example: `PRODUCTSUBCATEGORY=~SUBCATEGORYCODE~` filters products by selected subcategory

**Example INSERT Statement**:
```sql
INSERT INTO master.DATADISPLAYVALUELISTDEFINITION(
    VALUELISTDEFINITION, TABLENAME, VALUECOLUMNNAME, DISPLAYCOLUMNNAME,
    PARENTVALUESOURCE, PARENTVALUECOLUMNNAME, CONSTRAINTS, ADDBLANKITEM,
    CREATEDBY, CREATEDDATE, SELECTFIRST, SELECTIFSINGLE,
    BPNAME, METHODNAME, ISSEARCHABLE, PRELOAD
) VALUES (
    'PRODUCTCODE',                          -- List name
    'PRODUCT',                              -- Source table
    'PRODUCTCODE',                          -- Value column
    'PRODUCTNAME',                          -- Display column
    'SUBCATEGORYCODE',                      -- Parent field
    'PRODUCTSUBCATEGORY',                   -- Parent column in PRODUCT table
    'PRODUCTSUBCATEGORY=~SUBCATEGORYCODE~', -- Filter constraint
    0,                                      -- No blank item
    'admin',                                -- Created by
    CURRENT_TIMESTAMP,                      -- Created date
    0,                                      -- Don't auto-select first
    0,                                      -- Don't auto-select if single
    'BPProductCRUD',                        -- Business Process
    'Refresh',                              -- Method
    1,                                      -- Searchable
    0                                       -- Don't preload
);
```

---

### 3. DATAPANELAPPEARANCEDEFINITION

**Purpose**: Defines conditional visibility and enabled state for controls based on expressions.

**Key Columns**:

| Column Name | Data Type | Description | Example Values |
|------------|-----------|-------------|----------------|
| `DATADISPLAYNAME` | nvarchar(50) | Screen name (PRIMARY KEY) | 'RegistrationRequestLineDetailsPage' |
| `CONTROLNAME` | nvarchar(50) | Field name (PRIMARY KEY) | 'TAGID', 'CATALOG' |
| `SEQUENCE` | numeric(8,0) | Evaluation order (PRIMARY KEY) | 1, 2, 3... |
| `VISIBLE` | char(1) | Visible when condition true | '1' or '0' |
| `ENABLED` | char(1) | Enabled when condition true | '1' or '0' |
| `READONLY` | char(1) | Readonly when condition true | '1' or '0' |
| `CONDITION` | nvarchar(255) | Expression to evaluate | '~ADDTOASSET~=1', NULL |
| `APPEARANCENAME` | nvarchar(50) | Appearance style reference | 'DefaultAppearance', NULL |
| `CONTROLTYPE` | nvarchar(50) | Override control type (overrides auto-determined type from DataType/FilterType) | NULL, 'CaptionValue', 'InlineCaptionLabel', 'Chip', 'Separator' |
| `CONTROLPARAMS` | nvarchar(50) | Semicolon-separated key='value' pairs for additional customization | NULL, `EntryStyleName='StyleName'` |
| `CREATEDBY` | nvarchar(50) | Created by user | 'admin' |
| `CREATEDDATE` | datetime | Created date | CURRENT_TIMESTAMP |
| `MODIFIEDBY` | nvarchar(50) | Modified by user | NULL |
| `MODIFIEDDATE` | datetime | Modified date | NULL |

**Condition Expression Syntax**:
- Use `~FIELDNAME~` to reference field values from `DynamicFilters`
- Supports: `=`, `!=`, `>`, `<`, `>=`, `<=`
- Supports functions: `isemptyornull(~FIELDNAME~)`
- Logical operators: `||` (OR), `&&` (AND)

**Evaluation Order**:
Rules are applied in `SEQUENCE` order. Later rules can override earlier rules.

**Re-evaluation Trigger**:
Rules are automatically re-evaluated whenever any field in `ViewModel.DynamicFilters` changes.

**Example INSERT Statement (Conditional Visibility)**:
```sql
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestLineDetailsPage',   -- Screen name
    'TAGID',                                -- Field to control
    1,                                      -- Visible
    1,                                      -- Enabled
    0,                                      -- Not readonly
    '~ADDTOASSET~=1',                       -- Show when ADDTOASSET checkbox is checked
    1,                                      -- Sequence
    'DefaultAppearance',                    -- Appearance
    'admin',                                -- Created by
    CURRENT_TIMESTAMP,                      -- Created date
    NULL,                                   -- Not modified
    NULL,                                   -- No modified date
    NULL,                                   -- No control type override
    NULL                                    -- No control params
);
```

**Example INSERT Statement (Control Type Override)**:
```sql
-- Override REQUESTKEY to display as InlineCaptionLabel with custom style
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestInfoPage',          -- Screen name
    'REQUESTKEY',                           -- Field to control (raw data name, NOT prefixed EntryName)
    1,                                      -- Visible
    1,                                      -- Enabled
    0,                                      -- Not readonly
    NULL,                                   -- No condition (always applies)
    1,                                      -- Sequence
    'DefaultAppearance',                    -- Appearance
    'admin',                                -- Created by
    CURRENT_TIMESTAMP,                      -- Created date
    NULL,                                   -- Not modified
    NULL,                                   -- No modified date
    'InlineCaptionLabel',                   -- Override: display as inline caption + value
    'EntryStyleName=''ThemeStyleNames.Label.ListSubDetailData'''  -- Custom style param
);

-- Override STATUSCODE to display as a display-only Chip with color converters
-- NOTE: READONLY must be 0 — ReadOnly=1 causes DevExpress to force default styling,
--       overriding any color bindings from converters.
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestInfoPage',
    'STATUSCODE',
    1, 1, 0,                                -- READONLY = 0 (required for Chip color bindings)
    NULL, 2, 'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL,
    'Chip',                                 -- Override: display-only chip/badge
    'ConverterProfile=''LineStatus'''       -- Converter profile for text/background/text-color
);

-- Override DIVIDER1 to display as a Separator line
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestInfoPage',
    'DIVIDER1',
    1, 1, 0,
    NULL, 3, 'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL,
    'Separator',                            -- Override: horizontal separator line
    NULL
);
```

**CONTROLTYPE Override Behavior**:
- When `CONTROLTYPE` is set to a valid `ControlTypeName` enum value, it overrides the auto-determined control type (which is based on `DATATYPE` in `DATADISPLAYDATADEFINITION`).
- The override is applied in `BaseContentPage.ApplyControlTypeOverridesFromAppearanceAsync()` **before** controls are built.
- Matching is done by `CONTROLNAME` against `DataDefinition.DataName` (the raw column name), NOT the prefixed `EntryName`.
- Available override types: `ChipGroup` (editable multi-select, requires ValueList), `Chip` (display-only badge), `CaptionValue`, `InlineCaptionLabel`, `Separator`.
- **⚠️ Chip + ReadOnly caveat**: When overriding to `Chip`, the `READONLY` column in `DATAPANELAPPEARANCEDEFINITION` (and `ISREADONLY` in `DATADISPLAYDATADEFINITION`) **must be 0**. Setting ReadOnly to 1 causes the DevExpress Chip control to enforce its own default styling (grey text, white background), which overrides any color bindings from converters. Use `InputTransparent = true` (already set by `UIChipBuilderHelper`) instead of ReadOnly to make the chip non-interactive.

**CONTROLPARAMS Format**:
- Semicolon-separated `key='value'` pairs: e.g., `EntryStyleName='MyStyle';Prop2='value2'`
- Parsed in `BaseContentPage.ParseControlParams()` and applied via `ApplyControlParams()` to the `DataDefinition` before control building.
- Currently supported parameters:
  - `EntryStyleName` — Overrides the control's style name on the `DataDefinition`
  - `ConverterProfile` — Name of a registered `ChipConverterRegistry` profile to apply text, background-color and text-color converters when the control is rendered as a display-only Chip (e.g., `ConverterProfile='LineStatus'`). Profiles are registered at startup in `DILoader.cs` via `ChipConverterRegistry.Register()`.

**Common Patterns**:
```sql
-- Show field when checkbox is checked
CONDITION = '~ADDTOASSET~=1'

-- Hide field when another field is empty
CONDITION = 'isemptyornull(~PRODUCTCODE~)=false'

-- Show field when value meets criteria
CONDITION = '~EXPECTEDQTY~>0'

-- Complex condition with OR
CONDITION = '~ADDTOASSET~=1||~CAPTURECATALOG~!=1'

-- Complex condition with AND
CONDITION = '~ADDTOASSET~=1&&isemptyornull(~CATALOG~)=false'
```

---

### 4. DATADISPLAYVALIDATIONDEF

**Purpose**: Defines validation rules with custom expressions and error messages.

**Key Columns**:

| Column Name | Data Type | Description | Example Values |
|------------|-----------|-------------|----------------|
| `DATADISPLAYNAME` | nvarchar(50) | Screen name (PRIMARY KEY) | 'RegistrationRequestLineDetailsPage' |
| `ACTIONNAME` | nvarchar(100) | Action trigger (PRIMARY KEY) | 'AssetRegistration', 'Submit' |
| `SEQUENCE` | numeric(18,0) | Evaluation order (PRIMARY KEY) | 1, 2, 3... |
| `VALIDATIONNAME` | nvarchar(50) | Validation rule name | 'CatalogCheck', 'QtyCheck' |
| `VALIDATIONTYPE` | nvarchar(50) | Validation type | 'Condition' |
| `VALIDATIONMESSAGE` | nvarchar(255) | Error message to display | 'Catalog is required.' |
| `EXPRESSION` | nvarchar(255) | Expression to evaluate | '~ADDTOASSET~=1||isemptyornull(~CATALOG~)=false' |
| `CREATEDBY` | nvarchar(50) | Created by user | 'admin' |
| `CREATEDDATE` | datetime | Created date | CURRENT_TIMESTAMP |
| `MODIFIEDBY` | nvarchar(50) | Modified by user | NULL |
| `MODIFIEDDATE` | datetime | Modified date | NULL |

**Expression Logic**:
- Expression must evaluate to `true` for validation to **PASS**
- If expression evaluates to `false`, validation **FAILS** and message is shown
- Use same syntax as appearance conditions: `~FIELDNAME~`, operators, functions

**Triggering Validation**:
In Page code, the standard path is the base-class helper — it validates for the
action, shows validation errors, runs the controller call under one busy scope,
and shows the error modal if the call fails:
```csharp
await ValidateThenRunAsync("ActionName", MyPageController.CallMyActionAsync);
```
Only when the flow needs custom branching between validation and the action
(extra checks, success snackbars, multi-outcome results) fall back to the manual
form:
```csharp
ValidationResult validationResult = await this.ValidatePageAsync("ActionName");

if (validationResult.IsValid)
{
    // Proceed with action
}
else
{
    // Show validation errors
    await this.DisplayValidationErrorsAsync(validationResult);
}
```

**Example INSERT Statement**:
```sql
INSERT INTO master.DATADISPLAYVALIDATIONDEF (
    DATADISPLAYNAME, ACTIONNAME, SEQUENCE, VALIDATIONNAME,
    VALIDATIONTYPE, VALIDATIONMESSAGE, EXPRESSION,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE
) VALUES (
    'RegistrationRequestLineDetailsPage',   -- Screen name
    'AssetRegistration',                    -- Action that triggers validation
    1,                                      -- Sequence
    'CatalogCheck',                         -- Validation name
    'Condition',                            -- Type
    'Catalog is required.',                 -- Error message
    '~ADDTOASSET~=1||~CAPTURECATALOG~!=1||isemptyornull(~CATALOG~)=false', -- Expression
    'admin',                                -- Created by
    CURRENT_TIMESTAMP,                      -- Created date
    NULL,                                   -- Not modified
    NULL                                    -- No modified date
);
```

**Expression Breakdown**:
```
~ADDTOASSET~=1                     -- If NOT adding to asset, skip this validation
||                                 -- OR
~CAPTURECATALOG~!=1                -- If catalog capture is disabled, skip
||                                 -- OR
isemptyornull(~CATALOG~)=false     -- Catalog field has a value (validation passes)
```

---

### 5. DATAAPPEARANCEDEFINITION

**Purpose**: Lookup table for visual style definitions (fonts, colors, gradients, images).

**Usage**: Reference from `DATAPANELAPPEARANCEDEFINITION.APPEARANCENAME` column.

**Common Practice**: Use `'DefaultAppearance'` or `NULL` for standard styling. Only create custom appearances for special visual requirements.

**Note**: This table can be ignored for standard screen development.

---

### CardsGrid Build Pipeline (services and classes)

When `DATADISPLAYTYPE` includes `CardsGrid`, the following pipeline executes during `PreparePageControlsAsync → BuildCardsGridIfNeeded`:

| Step | Class / Method | Responsibility |
|------|----------------|----------------|
| 1 | `DataDisplayDefinitionService.GetDataDisplayDefinitionAsync` | Reads `DATADISPLAYDEFINITION` → `DataDisplayDefinition.IncludesCardsGrid` |
| 2 | `DataDisplayDataDefinitionService.GetCardsGridDataDefinitionsAsync` | Filters by `GRIDINCLUDE`, uses `DataDefinitionBuilderForCardsGrid` (binding path: `[COLUMN]`) |
| 3 | `PanelAppearanceService` + `ApplyControlTypeOverridesFromAppearanceAsync` | Applies `CONTROLTYPE` / `CONTROLPARAMS` to card `DataDefinition`s too |
| 4 | `UIDynamicPanelBuilderHelper.AssignRowIndicesToFields` | 8-column row layout from `Sequence` + `EditorColumnSpan` |
| 5 | `DataCardDefinitionControlBuilder.BuildCardsGrid` | Builds `DataCardConfiguration` → `DataCardTemplateBuilder` → `CollectionViewBuilder` → `UICollectionView` |
| 6 | `DataCardTemplateBuilder.BuildFieldView` | Switches on `EntryType`: Label, CaptionValue, InlineCaptionLabel, Chip, Separator |

**Key binding difference**: Panel fields bind to `DynamicFilters[FIELDNAME].Value`; card fields bind to `[FIELDNAME]` (DataRow bracket notation). The builder classes handle this automatically.

**Page code (not DB)**: `CardsGridParentContainer`, `GetCardsGridItemsSourceBinding()`, `GetCardsGridTapAction()`, `GetCardsGridEmptyViewText()`, `CreateCardsGridConfiguration()`.

---

## Step-by-Step Screen Creation Process

### Overview Checklist

- [ ] Step 1: Analyze specification and plan structure
- [ ] Step 2: Create SQL metadata scripts
- [ ] Step 3: Create constants (ScreenNames, BPNames, MethodNames, **ModelFields**)
- [ ] Step 4: Create ViewModel class
- [ ] Step 5: Create Controller class (uses centralized ModelFields)
- [ ] Step 6: Create Page class
- [ ] Step 7: Register in DILoader
- [ ] Step 8: Register navigation in AppController
- [ ] Step 9: Test and validate

---

### Step 1: Analyze Specification

**Input**: Specification document describing the screen requirements.

**Questions to Answer**:

1. **Screen Purpose**:
   - What is the main function? (Search, Details, Data Entry, etc.)
   - What user actions are supported? (Search, Submit, Save, Navigate, etc.)

2. **Screen Layout**:
   - [ ] Section 1: Form Fields (always present)
   - [ ] Section 2: Attributes Grid (optional - check if needed)
   - [ ] Section 3: Action Buttons (optional - list buttons)
   - [ ] Section 4: Data Grid (optional - for results/listings)

3. **Fields List**:
   For each field, determine:
   - Field name (database column name)
   - Label (user-facing text)
   - Data type (String, Double, DateTime, Boolean)
   - Control type (Entry, DatePicker, Combobox, Switch, Label)
   - Is it visible initially?
   - Is it mandatory?
   - Is it readonly?
   - Default value (if any)
   - Display format (for numbers/dates)
   - Column width (4 = half width, 8 = full width)
   - Sequence order within group
   - Group name

4. **Dropdowns/Comboboxes**:
   For each dropdown:
   - Value list name
   - Source table or VALUELIST table
   - Value column
   - Display column
   - Parent dependency (for cascading dropdowns)
   - Constraints/filters
   - Searchable? Preload?

5. **Conditional Visibility**:
   - Which fields have conditional visibility?
   - What are the conditions? (e.g., show TAGID when ADDTOASSET=1)
   - Evaluation sequence/priority

6. **Validation Rules**:
   - What actions require validation? (Submit, Save, etc.)
   - For each action, what validations are needed?
   - What are the validation expressions?
   - What error messages to show?

7. **Navigation**:
   - Where does this screen fit in the hierarchy?
   - What screen navigates to this screen?
   - What screens does this screen navigate to?
   - What data needs to be passed between screens?

8. **Business Logic**:
   - What server operations are needed? (search, save, update, delete)
   - What Business Processes (BP) and Methods to call?
   - What data transformations are needed?

---

### Step 2: Create SQL Metadata Scripts

Create a SQL file: `pages/screens-defs-{ScreenName}.sql`

#### 2.1: DATADISPLAYDATADEFINITION Entries

**Template**:
```sql
-- ========================================
-- Screen: {ScreenName}
-- Purpose: {Brief description}
-- Profile Code: {4-letter code}
-- ========================================

-- Field: {FieldName}
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME,        -- Screen identifier
    DATAGROUPNAME,          -- Group name (e.g., 'Main', 'Details')
    DATANAME,               -- Field name (database column)
    DATADESCRIPTION,        -- User-facing label
    ISVISIBLE,              -- 1 = visible, 0 = hidden
    DATATYPE,               -- String, Double, DateTime, Boolean, Unknown
    FILTERTYPE,             -- Value, List, Range
    FILTERDEFAULTVALUES,    -- Default value or NULL
    VALUELISTDEFINITION,    -- Value list name or NULL
    CREATEDBY,
    CREATEDDATE,
    WIDTH,           -- 4 = half width, 8 = full width
    FILTERCOMPARISONTYPE,   -- Equal, Like, GreaterOrEqual, Range, etc.
    SCREENPROFILENAME,      -- 4-letter screen code
    SEQUENCE,               -- Display order
    ISREADONLY,             -- 1 = readonly, 0 = editable
    ISMANDATORY             -- 1 = mandatory, 0 = optional
) VALUES (
    '{ScreenName}',         -- e.g., 'RegistrationSearchPage'
    '{GroupName}',          -- e.g., 'Main'
    '{FieldName}',          -- e.g., 'REGISTRATIONREQUESTKEY'
    '{Label}',              -- e.g., 'Req. No'
    {Visible},              -- 1 or 0
    '{DataType}',           -- 'String', 'Double', 'DateTime', 'Boolean'
    '{FilterType}',         -- 'Value' or 'List'
    {DefaultValue},         -- NULL or 'value'
    {ValueList},            -- NULL or 'VALUELISTNAME'
    'admin',
    CURRENT_TIMESTAMP,
    {Width},                -- 4 or 8
    '{ComparisonType}',     -- 'Equal', 'Like', etc.
    '{ProfileCode}',        -- e.g., 'RSP'
    {Sequence},             -- 1, 2, 3...
    {ReadOnly},             -- 0 or 1
    {Mandatory}             -- 0 or 1
);
```

**Example - Full Screen Definition**:
```sql
-- ========================================
-- Screen: RegistrationSearchPage
-- Purpose: Search for registration requests
-- Profile Code: RSP
-- ========================================

-- Field 1: Request Number (text input)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'RegistrationSearchPage', 'Main', 'REGISTRATIONREQUESTKEY', 'Req. No',
    1, 'String', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 8, 'Equal',
    'RSP', 1, 0, 0
);

-- Field 2: PO Number (text input)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'RegistrationSearchPage', 'Main', 'PONUMBER', 'PO No',
    1, 'String', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 8, 'Like',
    'RSP', 2, 0, 0
);

-- Field 3: Status (dropdown)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'RegistrationSearchPage', 'Main', 'STATUS', 'Status',
    1, 'String', 'List', NULL, 'REGISTRATIONREQUESTSTATUS',
    'admin', CURRENT_TIMESTAMP, 8, 'Equal',
    'RSP', 3, 0, 0
);

-- Field 4: From Date (date picker)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'RegistrationSearchPage', 'Main', 'FROMDATE', 'From Date',
    1, 'DateTime', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 4, 'GreaterOrEqual',
    'RSP', 4, 0, 0
);

-- Field 5: To Date (date picker)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'RegistrationSearchPage', 'Main', 'TODATE', 'To Date',
    1, 'DateTime', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 4, 'LessOrEqual',
    'RSP', 5, 0, 0
);
```

#### 2.2: DATADISPLAYVALUELISTDEFINITION Entries

**Template**:
```sql
-- Value List: {ValueListName}
-- Source: {TableName}
-- Description: {Brief description}
INSERT INTO master.DATADISPLAYVALUELISTDEFINITION(
    VALUELISTDEFINITION,        -- List name
    TABLENAME,                  -- Source table
    VALUECOLUMNNAME,            -- Value column
    DISPLAYCOLUMNNAME,          -- Display column
    PARENTVALUESOURCE,          -- Parent field or NULL
    PARENTVALUECOLUMNNAME,      -- Parent column or NULL
    CONSTRAINTS,                -- Filter constraint or NULL
    ADDBLANKITEM,               -- 0 or 1
    CREATEDBY, CREATEDDATE,
    SELECTFIRST,                -- 0 or 1
    SELECTIFSINGLE,             -- 0 or 1
    BPNAME,                     -- Business Process or NULL
    METHODNAME,                 -- Method or NULL
    ISSEARCHABLE,               -- 0 or 1
    PRELOAD                     -- 0 or 1
) VALUES (
    '{ValueListName}',          -- e.g., 'PRODUCTCODE'
    '{TableName}',              -- e.g., 'PRODUCT'
    '{ValueColumn}',            -- e.g., 'PRODUCTCODE'
    '{DisplayColumn}',          -- e.g., 'PRODUCTNAME'
    {ParentField},              -- NULL or 'SUBCATEGORYCODE'
    {ParentColumn},             -- NULL or 'PRODUCTSUBCATEGORY'
    {Constraint},               -- NULL or 'COLUMN=~FIELD~'
    {BlankItem},                -- 0 or 1
    'admin', CURRENT_TIMESTAMP,
    {SelectFirst},              -- 0 or 1
    {SelectIfSingle},           -- 0 or 1
    {BPName},                   -- NULL or 'BPName'
    {MethodName},               -- NULL or 'Refresh'
    {Searchable},               -- 0 or 1
    {Preload}                   -- 0 or 1
);
```

**Example - Simple Value List**:
```sql
-- Value List: REGISTRATIONREQUESTSTATUS
-- Source: VALUELIST table (static lookup data)
INSERT INTO master.DATADISPLAYVALUELISTDEFINITION(
    VALUELISTDEFINITION, TABLENAME, VALUECOLUMNNAME, DISPLAYCOLUMNNAME,
    PARENTVALUESOURCE, PARENTVALUECOLUMNNAME, CONSTRAINTS, ADDBLANKITEM,
    CREATEDBY, CREATEDDATE, SELECTFIRST, SELECTIFSINGLE,
    BPNAME, METHODNAME, ISSEARCHABLE, PRELOAD
) VALUES (
    'REGISTRATIONREQUESTSTATUS', 'VALUELIST', 'ITEMVALUE', 'DESCRIPTION',
    NULL, NULL, NULL, 1,
    'admin', CURRENT_TIMESTAMP, 0, 0,
    NULL, NULL, 0, 0
);
```

**Example - Cascading Value List**:
```sql
-- Value List: PRODUCTCODE (depends on SUBCATEGORYCODE)
INSERT INTO master.DATADISPLAYVALUELISTDEFINITION(
    VALUELISTDEFINITION, TABLENAME, VALUECOLUMNNAME, DISPLAYCOLUMNNAME,
    PARENTVALUESOURCE, PARENTVALUECOLUMNNAME, CONSTRAINTS, ADDBLANKITEM,
    CREATEDBY, CREATEDDATE, SELECTFIRST, SELECTIFSINGLE,
    BPNAME, METHODNAME, ISSEARCHABLE, PRELOAD
) VALUES (
    'PRODUCTCODE', 'PRODUCT', 'PRODUCTCODE', 'PRODUCTNAME',
    'SUBCATEGORYCODE', 'PRODUCTSUBCATEGORY',
    'PRODUCTSUBCATEGORY=~SUBCATEGORYCODE~', 0,
    'admin', CURRENT_TIMESTAMP, 0, 0,
    'BPProductCRUD', 'Refresh', 1, 0
);
```

#### 2.3: DATAPANELAPPEARANCEDEFINITION Entries

**Template (Conditional Visibility)**:
```sql
-- Appearance Rule: {Description}
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    '{ScreenName}',         -- Screen name
    '{FieldName}',          -- Field to control (raw data name)
    {Visible},              -- 1 or 0
    {Enabled},              -- 1 or 0
    {ReadOnly},             -- 1 or 0
    '{Condition}',          -- Expression or NULL
    {Sequence},             -- Priority order
    'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL, NULL, NULL
);
```

**Template (Control Type Override)**:
```sql
-- Control Type Override: Render {FieldName} as {ControlType}
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    '{ScreenName}',         -- Screen name
    '{FieldName}',          -- Field to control (raw data name, NOT prefixed EntryName)
    1,                      -- Visible
    1,                      -- Enabled
    0,                      -- Not readonly
    NULL,                   -- No condition (always applies)
    {Sequence},             -- Priority order
    'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL,
    '{ControlType}',        -- e.g., 'CaptionValue', 'InlineCaptionLabel', 'Chip', 'Separator'
    {ControlParams}         -- NULL or 'EntryStyleName=''StyleName''' (semicolon-separated key=value pairs)
);
```

**Example - Conditional Visibility**:
```sql
-- Show TAGID field only when ADDTOASSET checkbox is checked
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestLineDetailsPage', 'TAGID', 1, 1, 0,
    '~ADDTOASSET~=1', 1, 'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL, NULL, NULL
);

-- Hide CATALOG field when ADDTOASSET is checked
INSERT INTO master.DATAPANELAPPEARANCEDEFINITION (
    DATADISPLAYNAME, CONTROLNAME, VISIBLE, ENABLED, READONLY,
    CONDITION, SEQUENCE, APPEARANCENAME,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE, CONTROLTYPE, CONTROLPARAMS
) VALUES (
    'RegistrationRequestLineDetailsPage', 'CATALOG', 0, 1, 0,
    '~ADDTOASSET~=1', 2, 'DefaultAppearance',
    'admin', CURRENT_TIMESTAMP, NULL, NULL, NULL, NULL
);
```

#### 2.4: DATADISPLAYVALIDATIONDEF Entries

**Template**:
```sql
-- Validation: {ValidationName} for action {ActionName}
INSERT INTO master.DATADISPLAYVALIDATIONDEF (
    DATADISPLAYNAME, ACTIONNAME, SEQUENCE, VALIDATIONNAME,
    VALIDATIONTYPE, VALIDATIONMESSAGE, EXPRESSION,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE
) VALUES (
    '{ScreenName}',         -- Screen name
    '{ActionName}',         -- Action trigger (e.g., 'Submit', 'Save')
    {Sequence},             -- Priority order
    '{ValidationName}',     -- Validation identifier
    'Condition',            -- Type
    '{ErrorMessage}',       -- Message to display on failure
    '{Expression}',         -- Expression (must be true to pass)
    'admin', CURRENT_TIMESTAMP, NULL, NULL
);
```

**Example - Field Required Validation**:
```sql
-- Validation: Catalog is required when adding to asset
INSERT INTO master.DATADISPLAYVALIDATIONDEF (
    DATADISPLAYNAME, ACTIONNAME, SEQUENCE, VALIDATIONNAME,
    VALIDATIONTYPE, VALIDATIONMESSAGE, EXPRESSION,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE
) VALUES (
    'RegistrationRequestLineDetailsPage', 'AssetRegistration', 1,
    'CatalogCheck', 'Condition', 'Catalog is required.',
    '~ADDTOASSET~=1||~CAPTURECATALOG~!=1||isemptyornull(~CATALOG~)=false',
    'admin', CURRENT_TIMESTAMP, NULL, NULL
);

-- Validation: Quantity must be greater than zero
INSERT INTO master.DATADISPLAYVALIDATIONDEF (
    DATADISPLAYNAME, ACTIONNAME, SEQUENCE, VALIDATIONNAME,
    VALIDATIONTYPE, VALIDATIONMESSAGE, EXPRESSION,
    CREATEDBY, CREATEDDATE, MODIFIEDBY, MODIFIEDDATE
) VALUES (
    'RegistrationRequestLineDetailsPage', 'AssetRegistration', 2,
    'QtyCheck', 'Condition', 'Quantity to register must be greater than zero.',
    '~QTYTOREGISTER~>0',
    'admin', CURRENT_TIMESTAMP, NULL, NULL
);
```

---

### Step 3: Create Constants

**Files to Update**:
- `constants/ScreenNames.cs`
- `constants/BPNames.cs`
- `constants/MethodNames.cs` (if adding new methods)
- `constants/ModelFields.cs` (if adding new common fields)
- `constants/ModelFields.{FeatureName}.cs` (create or update for feature-specific fields)

#### 3.1: Add to ScreenNames.cs

**Location**: `/constants/ScreenNames.cs`

**Template**:
```csharp
public class ScreenNames : client.mobile.constants.ScreenNames
{
    // ... existing constants

    public const string {ScreenName} = "{ScreenName}";
}
```

**Example**:
```csharp
public class ScreenNames : client.mobile.constants.ScreenNames
{
    public const string Registration = "Registration";
    public const string RegistrationSearch = "RegistrationSearch";
    public const string RegistrationRequestInfo = "RegistrationRequestInfo";
    public const string RegistrationRequestLines = "RegistrationRequestLines";
    public const string RegistrationRequestLineDetails = "RegistrationRequestLineDetails";
    public const string AssetRegistration = "AssetRegistration";
}
```

#### 3.2: Add to BPNames.cs

**Location**: `/constants/BPNames.cs`

**Template**:
```csharp
public class BPNames : client.mobile.constants.BPNames
{
    // ... existing constants

    public const string {BusinessProcessName} = "{BusinessProcessName}";
}
```

**Example**:
```csharp
public class BPNames : client.mobile.constants.BPNames
{
    public const string BPRegistrationRequestCRUD = "BPRegistrationRequestCRUD";
    public const string BLRegisterAgainstRequest = "BLRegisterAgainstRequest";
    public const string BLAddToAssetAgainstRequest = "BLAddToAssetAgainstRequest";
    public const string BVRegistrationRequestSummary = "BVRegistrationRequestSummary";
    public const string BVRegistrationRequestLinesSummary = "BVRegistrationRequestLinesSummary";
}
```

#### 3.3: Add to MethodNames.cs (if needed)

**Location**: `/constants/MethodNames.cs`

**Template**:
```csharp
public class MethodNames : client.mobile.constants.MethodNames
{
    // ... existing constants (GetDetails, Refresh, etc.)

    public const string {MethodName} = "{MethodName}";
}
```

**Example**:
```csharp
public class MethodNames : client.mobile.constants.MethodNames
{
    // Inherited from base
    // public const string GetDetails = "GetDetails";
    // public const string Refresh = "Refresh";

    public const string Register = "Register";
    public const string Execute = "Execute";
    public const string GetActiveEmployees = "GetActiveEmployees";
}
```

#### 3.4: Add Model Field Constants (IMPORTANT - Centralized Pattern)

**IMPORTANT**: Field constants MUST be added to the centralized `ModelFields` partial class files, NOT as nested classes in controllers. This ensures:
- Single source of truth for all field names
- No duplication across controllers
- Easy maintenance and refactoring
- Consistent naming across the application

**File Structure**:
- `constants/ModelFields.cs` - Base partial class with Common fields shared across features
- `constants/ModelFields.{FeatureName}.cs` - Feature-specific fields (e.g., `ModelFields.PickRequest.cs`, `ModelFields.Registration.cs`)

**Step 1**: Check if `ModelFields.cs` base file exists. If not, create it:

**Location**: `/constants/ModelFields.cs`

```csharp
namespace client.mobile.s4wes.constants
{
    /// <summary>
    /// Centralized model field constants organized by domain.
    /// This is a partial class - add feature-specific fields in separate files
    /// named ModelFields.{FeatureName}.cs
    /// </summary>
    public static partial class ModelFields
    {
        /// <summary>Common fields shared across multiple models</summary>
        public static class Common
        {
            public const string PAGEDESCLBL = "PAGEDESCLBL";
            public const string REFERENCEKEY = "REFERENCEKEY";
            public const string REFERENCETYPE = "REFERENCETYPE";
            public const string PRODUCTCODE = "PRODUCTCODE";
            public const string PRODUCTNAME = "PRODUCTNAME";
            public const string OWNERCODE = "OWNERCODE";
            // Add new common fields here when needed
        }
    }
}
```

**Step 2**: Create or update a feature-specific file for your screen:

**Location**: `/constants/ModelFields.{FeatureName}.cs`

**Template**:
```csharp
namespace client.mobile.s4wes.constants
{
    public static partial class ModelFields
    {
        /// <summary>{FeatureName} specific fields</summary>
        public static class {FeatureName}
        {
            public const string {FIELDNAME} = "{FIELDNAME}";
            public const string {ANOTHERFIELD} = "{ANOTHERFIELD}";
            // ... more fields specific to this feature
        }

        /// <summary>Optional: Additional domain classes for logical grouping</summary>
        public static class {DomainName}
        {
            public const string {FIELDNAME} = "{FIELDNAME}";
        }
    }
}
```

**Example** (`ModelFields.PickRequest.cs`):
```csharp
namespace client.mobile.s4wes.constants
{
    public static partial class ModelFields
    {
        /// <summary>Pick request quantity and status fields</summary>
        public static class PickRequest
        {
            public const string PICKREQUESTID = "PICKREQUESTID";
            public const string QTYTOPICK = "QTYTOPICK";
            public const string PICKEDQTY = "PICKEDQTY";
            public const string CONFIRMEDQTY = "CONFIRMEDQTY";
            public const string TOTALQTYTOPICK = "TOTALQTYTOPICK";
            public const string TOTALPICKEDQTY = "TOTALPICKEDQTY";
            public const string PENDINGPICKREQUESTS = "PENDINGPICKREQUESTS";
            public const string TOTALPICKREQUESTS = "TOTALPICKREQUESTS";
        }

        /// <summary>Location and section fields</summary>
        public static class Location
        {
            public const string SECTIONID = "SECTIONID";
            public const string SECTIONCODE = "SECTIONCODE";
            public const string LOCATIONCODE = "LOCATIONCODE";
            public const string SECTIONLOC_LOCATIONCODE = "SECTIONLOC_LOCATIONCODE";
        }

        /// <summary>Drop ID and box-related fields</summary>
        public static class DropId
        {
            public const string DROPID = "DROPID";
            public const string DROPIDISFULLLBL = "DROPIDISFULLLBL";
            public const string CLOSEBOX = "CLOSEBOX";
            public const string ASSIGNLOCATIONWITHDROPIDONLY = "ASSIGNLOCATIONWITHDROPIDONLY";
        }
    }
}
```

**Example** (`ModelFields.Registration.cs`):
```csharp
namespace client.mobile.s4wes.constants
{
    public static partial class ModelFields
    {
        /// <summary>Registration request fields</summary>
        public static class Registration
        {
            public const string REGISTRATIONREQUESTKEY = "REGISTRATIONREQUESTKEY";
            public const string PONUMBER = "PONUMBER";
            public const string STATUS = "STATUS";
            public const string EXPECTEDQTY = "EXPECTEDQTY";
            public const string REGISTEREDQTY = "REGISTEREDQTY";
            public const string QTYTOREGISTER = "QTYTOREGISTER";
        }

        /// <summary>Asset-related fields</summary>
        public static class Asset
        {
            public const string ADDTOASSET = "ADDTOASSET";
            public const string TAGID = "TAGID";
            public const string CATALOG = "CATALOG";
        }
    }
}
```

**Rules for Field Organization**:
1. **Common fields** (used across 2+ features): Add to `ModelFields.Common` in `ModelFields.cs`
2. **Feature-specific fields**: Create `ModelFields.{FeatureName}.cs` with feature-specific nested class
3. **Domain grouping**: Group related fields into logical classes (Location, Asset, etc.)
4. **Avoid duplication**: Always check existing files before adding a new field
5. **Naming**: Use UPPERCASE for field constant values (matching database column names)

**Usage in Controllers**:
```csharp
using static client.mobile.s4wes.constants.ModelFields;

// Then use directly:
FiltersHelper.ExtractFilters(filters, [
    Common.REFERENCEKEY,
    PickRequest.QTYTOPICK,
    Location.LOCATIONCODE
]);

// Or for filter access:
var value = DynamicFilters[Common.PRODUCTCODE].Value;
```

---

### Step 4: Create ViewModel Class

**Location**: `/models/{feature}/{ScreenName}ViewModel.cs`

**Base Classes to Choose From**:
- **`BaseViewModel`**: Base class with IsBusy support
- **`DynamicViewModel`**: Extends BaseViewModel, adds `DynamicFilters` collection
- **`GridViewModel`**: Extends DynamicViewModel, adds `DataRows` for grid data

**Decision Guide**:
- Use **`GridViewModel`** for screens with data grids (search results, listings)
- Use **`DynamicViewModel`** for form screens without grids
- Use **`BaseViewModel`** only if you need custom property management

#### 4.1: Simple ViewModel Template (GridViewModel)

```csharp
using client.mobile.engines;
using client.mobile.models;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for {ScreenName}.
    /// Purpose: {Brief description of screen purpose}
    /// </summary>
    public class {ScreenName}ViewModel : GridViewModel
    {
        // Minimal implementation - all functionality from base class
        // GridViewModel provides:
        // - DynamicFilters: XalIndexedObjectCollection<Filter> (form field data)
        // - DataRows: ObservableCollection<IDictionary<string, object>> (grid data)
        // - IsBusy: bool (loading state)
    }
}
```

**Example**:
```csharp
using client.mobile.engines;
using client.mobile.models;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for RegistrationSearchPage.
    /// Purpose: Holds search filters and result grid data.
    /// </summary>
    public class RegistrationSearchViewModel : GridViewModel
    {
    }
}
```

#### 4.2: ViewModel with Navigation Parameters

If the screen receives data from navigation, use `[QueryProperty]`:

```csharp
using client.mobile.engines;
using client.mobile.models;
using shared.dataquery.objects;
using shared.xal.objects.collections;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for {ScreenName}.
    /// Purpose: {Brief description}
    /// </summary>
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]
    public class {ScreenName}ViewModel : DynamicViewModel, I_ContextDataExtractor
    {
        // DynamicViewModel provides:
        // - DynamicFilters: XalIndexedObjectCollection<Filter>
        // I_ContextDataExtractor allows passing data to next screen
    }
}
```

**Example**:
```csharp
using client.mobile.engines;
using client.mobile.models;
using shared.dataquery.objects;
using shared.xal.objects.collections;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for RegistrationRequestLineDetailsPage.
    /// Purpose: Holds line item details and allows registration.
    /// </summary>
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]
    public class RegistrationRequestLineDetailsViewModel : DynamicViewModel, I_ContextDataExtractor
    {
    }
}
```

#### 4.3: ViewModel with Custom Properties

Add custom properties when you need additional data beyond `DynamicFilters`:

```csharp
using client.mobile.engines;
using client.mobile.models;
using shared.dataquery.objects;
using shared.xal.objects.collections;

namespace client.mobile.s4wes.models
{
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]
    public class {ScreenName}ViewModel : DynamicViewModel, I_ContextDataExtractor
    {
        // Custom collection for tracking items
        internal List<XalIndexedObjectCollection<Filter>> {CollectionName} = [];

        // Custom property with binding support
        private int {fieldName};
        public int {PropertyName}
        {
            get => {fieldName};
            set
            {
                {fieldName} = value;
                OnPropertyChanged(nameof({PropertyName}));  // CRITICAL: Notify UI
            }
        }
    }
}
```

**Example**:
```csharp
using client.mobile.engines;
using client.mobile.models;
using shared.dataquery.objects;
using shared.xal.objects.collections;

namespace client.mobile.s4wes.models
{
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]
    public class ReceiptLineViewModel : DynamicViewModel, I_ContextDataExtractor
    {
        // Track registered assets
        internal List<XalIndexedObjectCollection<Filter>> RegisteredAssets = [];

        // Track image count with UI binding
        private int imagesCount;
        public int ImagesCount
        {
            get => imagesCount;
            set
            {
                imagesCount = value;
                OnPropertyChanged(nameof(ImagesCount));  // Update UI when changed
            }
        }
    }
}
```

---

### Step 5: Create Controller Class

**Location**: `/pages/{feature}/{ScreenName}PageController.cs`

**IMPORTANT**: Do NOT create nested Field Constants classes in controllers. Use the centralized `ModelFields` pattern (see Step 3.4).

**Structure**:
1. ~~Field constants class~~ → Use centralized `ModelFields.{FeatureName}.cs` instead
2. ViewModel reference
3. Constructor
4. InitializeAsync() override
5. Internal action methods (Call{Action}Async)
6. Private helper methods
7. Private server communication methods

#### 5.1: Controller Template

```csharp
using client.mobile.controller;
using client.mobile.engines;
using client.mobile.engines.app;
using client.mobile.models;
using client.mobile.s4wes.constants;
using static client.mobile.s4wes.constants.ModelFields;  // <-- IMPORTANT: Import centralized ModelFields
using client.mobile.s4wes.models;
using shared.dataquery.objects;
using shared.xal.objects;
using shared.xal.objects.collections;
using System.Data;
using maui.client.mobile.viewmodels;
using common.modules.dal;
using common.data;
using client.mobile.helpers;
using client.mobile.objects;

namespace client.mobile.s4wes.pages.{feature}
{
    /// <summary>
    /// Controller for {ScreenName}.
    /// Purpose: {Brief description of responsibilities}
    /// </summary>
    public class {ScreenName}PageController : BaseController
    {
        // NOTE: Field constants are centralized in constants/ModelFields.{FeatureName}.cs
        // Use: Common.FIELDNAME, {FeatureName}.FIELDNAME, Location.FIELDNAME, etc.

        #region ViewModel

        internal {ScreenName}ViewModel {ScreenName}Model = new();
        public override BaseViewModel ViewModel => this.{ScreenName}Model;

        #endregion

        #region Constructor

        public {ScreenName}PageController(I_NavigationService NavigationService)
            : base(NavigationService)
        {
        }

        #endregion

        #region Initialization

        public override Task InitializeAsync()
        {
            // Initialize ViewModel filters
            InitViewModelValues();

            // Perform calculations
            CalculateDerivedValues();

            // No artificial delays here; if the body gains awaits, make the
            // method async and drop this return.
            return Task.CompletedTask;
        }

        private void InitViewModelValues()
        {
            // Add filters with default values
            // Use centralized ModelFields: Common.FIELD, {FeatureName}.FIELD, etc.
            AddOrReplaceFilter(Common.{Field}, DataType.{Type}, this.{ScreenName}Model.DynamicFilters, {DefaultValue});
            // or for feature-specific fields:
            AddOrReplaceFilter({FeatureName}.{Field}, DataType.{Type}, this.{ScreenName}Model.DynamicFilters, {DefaultValue});
            // ... more fields
        }

        private void CalculateDerivedValues()
        {
            // Calculate derived field values
            // Example: amount = qty * price
        }

        #endregion

        #region Internal Action Methods

        /// <summary>
        /// {Action description}
        /// </summary>
        internal async Task<Result> Call{Action}Async()
        {
            Result result = null;
            await IsBusyFor(async () =>
            {
                try
                {
                    // Business logic here
                    DataSet dsResult = await {ServerMethod}Async();

                    if (DataHelper.IsEmptyResult(dsResult))
                    {
                        result = Result.Failure("No data found", ErrorType.SystemError);
                    }
                    else
                    {
                        // Process result
                        this.{ScreenName}Model.SetModelData(dsResult.Tables[0]);
                        result = Result.Success();
                    }
                }
                catch (Exception methodEx)
                {
                    result = Result.Failure(methodEx.Message, ErrorType.SystemError);
                }
            });
            return result;
        }

        /// <summary>
        /// Navigate to {TargetScreen}
        /// </summary>
        internal Task CallGoTo{TargetScreen}Async()
        {
            string navigationRoute = Build{TargetScreen}NavigationRoute();
            Dictionary<string, object> navigationParameters = Build{TargetScreen}NavigationParameters();

            return IsBusyFor(() =>
                this.NavigationService.NavigateToAsync(navigationRoute, navigationParameters));
        }

        #endregion

        #region Private Helper Methods

        private string Build{TargetScreen}NavigationRoute()
        {
            return $"//Main/Operation/{ScreenNames.{Parent}}/" +
                   $"{ScreenNames.{Current}}/{ScreenNames.{Target}}";
        }

        private Dictionary<string, object> Build{TargetScreen}NavigationParameters()
        {
            return new Dictionary<string, object>
            {
                { nameof({TargetScreen}ViewModel.DynamicFilters),
                  this.{ScreenName}Model.DynamicFilters }
            };
        }

        #endregion

        #region Server Communication

        private Task<DataSet> {ServerMethod}Async()
        {
            // Build filters
            XalIndexedObjectCollection<Filter> filters =
                this.{ScreenName}Model.DynamicFilters;

            // Call server
            return mobile.factory.ModelIO.Instance.ExecuteActionAsync<DataSet>(
                BPNames.{BusinessProcess},
                MethodNames.{Method},
                filters,
                new XalIndexedObjectCollection<Filter>());
        }

        #endregion
    }
}
```

#### 5.2: Example - Search Screen Controller

```csharp
using client.mobile.controller;
using client.mobile.engines;
using client.mobile.engines.app;
using client.mobile.helpers;
using client.mobile.s4wes.constants;
using client.mobile.s4wes.models;
using client.mobile.s4wes.models.receipt;
using common.data;
using common.modules.dal;
using maui.client.mobile.viewmodels;
using shared.dataquery.objects;
using shared.helpers;
using shared.xal.objects.collections;
using System.Data;
using client.mobile.objects;

namespace client.mobile.s4wes.pages.receipt
{
    /// <summary>
    /// Controller for RegistrationSearchPage.
    /// Purpose: Search for open registration requests.
    /// </summary>
    public class RegistrationSearchPageController : BaseController
    {
        #region Field Constants

        public class RegistrationSearchPageModelFields
        {
            public const string RegistrationRequestKey = "REGISTRATIONREQUESTKEY";
            public const string PONumber = "PONUMBER";
            public const string Status = "STATUS";
            public const string FromDate = "FROMDATE";
            public const string ToDate = "TODATE";
        }

        #endregion

        #region ViewModel

        internal RegistrationSearchViewModel RegistrationSearchModel = new();
        public override BaseViewModel ViewModel => this.RegistrationSearchModel;

        #endregion

        #region Constructor

        public RegistrationSearchPageController(I_NavigationService NavigationService)
            : base(NavigationService)
        {
        }

        #endregion

        #region Internal Action Methods

        /// <summary>
        /// Search for registration requests based on filter criteria.
        /// </summary>
        internal async Task<Result> CallGetRegistrationRequestsAsync()
        {
            Result result = null;            
            await IsBusyFor(async () =>
            {
                try
                {
                    DataSet dsResult = await GetRegistrationRequestsSummaryAsync();

                    if (DataHelper.IsEmptyResult(dsResult))
                    {
                        result = Result.Failure("No open request(s) found", ErrorType.SystemError);
                    }
                    else
                    {
                        this.RegistrationSearchModel.SetModelData(dsResult.Tables[0]);
                        result = Result.Success();
                    }
                }
                catch (Exception methodEx)
                {
                    result = Result.Failure(methodEx.Message, ErrorType.SystemError);
                }
            });
            return result;
        }

        /// <summary>
        /// Navigate to RegistrationRequestInfoPage for selected request.
        /// </summary>
        internal Task CallGoToRegistrationRequestInfoAsync(IDictionary<string, object> SelectedRow)
        {
            string navigationRoute = BuildRegistrationRequestInfoNavigationRoute();
            Dictionary<string, object> navigationParameters =
                BuildRegistrationRequestInfoNavigationParameters(SelectedRow);

            return IsBusyFor(() =>
                this.NavigationService.NavigateToAsync(navigationRoute, navigationParameters));
        }

        #endregion

        #region Private Helper Methods

        private string BuildRegistrationRequestInfoNavigationRoute()
        {
            return $"//Main/Operation/{ScreenNames.Registration}/" +
                   $"{ScreenNames.RegistrationRequestInfo}";
        }

        private Dictionary<string, object> BuildRegistrationRequestInfoNavigationParameters(
            IDictionary<string, object> SelectedRow)
        {
            XalIndexedObjectCollection<Filter> navigationFilters = [];

            // Pass selected request key
            navigationFilters.Add(Filter.GetValueFilter(
                RegistrationSearchPageModelFields.RegistrationRequestKey,
                DataType.String,
                SelectedRow[RegistrationSearchPageModelFields.RegistrationRequestKey]));

            return new Dictionary<string, object>
            {
                { nameof(RegistrationRequestInfoViewModel.DynamicFilters), navigationFilters }
            };
        }

        #endregion

        #region Server Communication

        private Task<DataSet> GetRegistrationRequestsSummaryAsync()
        {
            // Add status filter for confirmed but not closed requests
            var confirmedButNotClosedRangedFilter = Filter.GetRangeFilter(
                "Status",
                DataType.String,
                CodeLists.RegistrationRequestStatus.Confirmed,
                (DataHelper.GetInt(CodeLists.RegistrationRequestStatus.ClosedUnRegistered) - 1).ToString());

            // Merge with user-entered filters
            XalIndexedObjectCollection<Filter> allFilters =
                FiltersHelper.MergeFilters(
                    this.RegistrationSearchModel.DynamicFilters,
                    [confirmedButNotClosedRangedFilter]);

            // Call server
            return mobile.factory.ModelIO.Instance.ExecuteActionAsync<DataSet>(
                BPNames.BVRegistrationRequestSummary,
                MethodNames.Refresh,
                allFilters,
                new XalIndexedObjectCollection<Filter>());
        }

        #endregion
    }
}
```


---

### Step 6: Create Page Class

**Location**: `/pages/{feature}/{ScreenName}Page.cs`

**Structure**:
1. Class definition and constructor
2. Lifecycle methods (BeforeOnAppearing, AfterOnAppearing)
3. BuildPageLayout() - Main UI builder
4. Section builders (BuildActionsGridLayout, etc.)
5. Grid column definitions (if grid section present)
6. Event handlers
7. Helper methods

#### 6.1: Page Template

```csharp
using client.mobile.controls;
using client.mobile.engines;
using client.mobile.helpers;
using client.mobile.helpers.uibuilders;
using client.mobile.objects;
using client.mobile.pages;
using client.mobile.pages.basepages;
using client.mobile.s4wes.constants;
using client.mobile.s4wes.models;
using shared.dataquery.objects;
using common.collections;


namespace client.mobile.s4wes.pages.{feature}
{
    /// <summary>
    /// Page for {ScreenName}.
    /// Purpose: {Brief description of screen purpose}
    /// Layout: {Describe sections: Form + Buttons, Form + Buttons + Grid, etc.}
    /// </summary>
    public class {ScreenName}Page : BaseContentPage
    {
        #region Controller Reference

        protected {ScreenName}PageController {ScreenName}PageController
            => ({ScreenName}PageController)this.BaseController;

        #endregion

        #region Fields

        // Declare references to controls that need to be accessed later
        UIDataGrid? ResultGrid;  // For grids
        UIButton? SubmitButton;  // For buttons

        #endregion

        #region Constructor

        public {ScreenName}Page({ScreenName}PageController {ScreenName}PageController)
            : base({ScreenName}PageController, "{Screen Title}", nameof({ScreenName}Page))
        {
            // Root screens hide the back button:
            HideShellBackButton();

            // Screens where back must run logic (skip/complete/reset) instead wire it
            // once for BOTH the toolbar arrow and the hardware back button:
            // SetBackAction(MyBackActionAsync);
        }

        #endregion

        #region Lifecycle Methods

        protected override void BeforeOnAppearing()
        {
            // Called BEFORE metadata is loaded and controls are built
            // Use for: Resetting state, clearing selections

            base.BeforeOnAppearing();

            // Reset ViewModel values if needed
            if (m_ContextDataExtractor != null)
                this.BaseController.ResetModelValues(
                    m_ContextDataExtractor.GetContextData(),
                    m_DataDefinitions, m_EntityDataDefinitions);

            // Clear grid selection
            if (ResultGrid != null)
                ResultGrid.SelectedItem = null;
        }

        protected override void AfterOnAppearing()
        {
            // Called AFTER metadata is loaded and controls are built
            // Use for: Adding event handlers, customizing controls

            base.AfterOnAppearing();

            // Add event handlers
            SetupEventHandlers();

            // Customize controls
            CustomizeControls();
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.{SectionHeight} },  // Section 1
                    new RowDefinition { Height = GridLength.{SectionHeight} },  // Section 2
                    // ... more sections
                }
            };

            // Section 1: Metadata-driven form fields
            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);

            // Section 2: Action buttons (if needed)
            contentGrid.Add(BuildActionsGridLayout(), 0, 1);

            // Section 3: Data grid (if needed)
            // contentGrid.Add(ResultGrid, 0, 2);

            return contentGrid;
        }

        #endregion

        #region Section Builders

        private UIGrid BuildActionsGridLayout()
        {
            UIButton btnAction = UIButtonBuilderHelper.BuildButton(
                "ActionBtn",
                "Action Label",
                string.Empty,
                string.Empty);

            btnAction.Clicked += async (s, e) =>
                await this.{ScreenName}PageController.Call{Action}Async();

            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(
                btnAction, LayoutOptions.End);
        }

        #endregion

        #region Event Handlers

        private void SetupEventHandlers()
        {
            // Get control references
            I_UIControl? control = GetControl("FieldName");
            if (control == null)
                return;

            // Add event handler based on control type
            if (control is UISwitch switchControl)
            {
                switchControl.Toggled += OnFieldToggled;
            }
            else if (control is UIButton buttonControl)
            {
                buttonControl.Clicked += OnButtonClicked;
            }
        }

        private void OnFieldToggled(object? sender, ToggledEventArgs e)
        {
            // Handle toggle event
            ApplyConditionalVisibility(e.Value);
        }

        private async void OnButtonClicked(object? sender, EventArgs e)
        {
            // Validation + controller call + error modal in one helper.
            // Use RunControllerActionAsync(...) instead when no validation applies.
            await ValidateThenRunAsync("ActionName", {ScreenName}PageController.Call{Action}Async);
        }

        #endregion

        #region Helper Methods

        private void CustomizeControls()
        {
            // Customize control properties beyond metadata
        }

        private void ApplyConditionalVisibility(bool condition)
        {
            // Manually control visibility based on logic
            this.ChildControls["FieldName"].IsVisible = condition;
        }

        #endregion
    }
}
```

#### 6.2: Example - Simple Form Page

```csharp
using client.mobile.controls;
using client.mobile.helpers;
using client.mobile.helpers.uibuilders;
using client.mobile.pages.basepages;


namespace client.mobile.s4wes.pages.receipt
{
    /// <summary>
    /// Page for RegistrationRequestInfoPage.
    /// Purpose: Display registration request details.
    /// Layout: Form fields + Check Details button
    /// </summary>
    public class RegistrationRequestInfoPage : BaseContentPage
    {
        #region Controller Reference

        protected RegistrationRequestInfoPageController RegistrationRequestInfoPageController
            => (RegistrationRequestInfoPageController)this.BaseController;

        #endregion

        #region Constructor

        public RegistrationRequestInfoPage(
            RegistrationRequestInfoPageController RegistrationRequestInfoPageController)
            : base(RegistrationRequestInfoPageController,
                   "Request Info",
                   nameof(RegistrationRequestInfoPage))
        {
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.Star },  // Form fills space
                    new RowDefinition { Height = GridLength.Auto },  // Button auto-sized
                }
            };

            // Metadata-driven form fields
            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);

            // Action button
            contentGrid.Add(BuildActionsGridLayout(), 0, 1);

            return contentGrid;
        }

        private UIGrid BuildActionsGridLayout()
        {
            UIButton btnCheckDetails = UIButtonBuilderHelper.BuildButton(
                "GetDetails",
                "Check Details",
                string.Empty,
                string.Empty);

            btnCheckDetails.Clicked += async (s, e) =>
                await this.RegistrationRequestInfoPageController
                    .CallGoToRegistrationLineAsync();

            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(
                btnCheckDetails, LayoutOptions.End);
        }

        #endregion
    }
}
```

#### 6.3: Example - Search Page with Grid

```csharp
using client.mobile.controls;
using client.mobile.helpers;
using client.mobile.helpers.uibuilders;
using client.mobile.objects;
using client.mobile.pages.basepages;
using common.collections;
using DevExpress.Maui.DataGrid;

namespace client.mobile.s4wes.pages.receipt
{
    /// <summary>
    /// Page for RegistrationSearchPage.
    /// Purpose: Search for open registration requests.
    /// Layout: Search filters + Search button + Results grid
    /// </summary>
    public class RegistrationSearchPage : BaseContentPage
    {
        #region Controller Reference

        protected RegistrationSearchPageController RegistrationSearchPageController
            => (RegistrationSearchPageController)this.BaseController;

        #endregion

        #region Fields

        UIDataGrid? ResultGrid;

        #endregion

        #region Constructor

        public RegistrationSearchPage(
            RegistrationSearchPageController RegistrationSearchPageController)
            : base(RegistrationSearchPageController,
                   "Register Assets",
                   nameof(RegistrationSearchPage))
        {
            HideShellBackButton();
        }

        #endregion

        #region Lifecycle Methods

        protected override void BeforeOnAppearing()
        {
            // Reset state on page appearance
            if (m_ContextDataExtractor != null)
                this.BaseController.ResetModelValues(
                    m_ContextDataExtractor.GetContextData(),
                    m_DataDefinitions, m_EntityDataDefinitions);

            if (ResultGrid != null)
                ResultGrid.SelectedItem = null;
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            // Build result grid
            ResultGrid = BuildDataGrid(nameof(RegistrationSearchPageController.RegistrationSearchViewModel.DataRows),
    DetailsGridColumnDefinitions());

            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.Auto },  // Search filters
                    new RowDefinition { Height = GridLength.Auto },  // Button
                    new RowDefinition { Height = GridLength.Star },  // Results grid fills space
                }
            };

            // Search filters from metadata
            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);

            // Search button
            contentGrid.Add(BuildActionsGridLayout(), 0, 1);

            // Results grid
            contentGrid.Add(ResultGrid, 0, 2);

            return contentGrid;
        }

        private UIGrid BuildActionsGridLayout()
        {
            UIButton btnSearch = UIButtonBuilderHelper.BuildButton(
                "SearchBtn",
                "Search",
                string.Empty,
                string.Empty);

            btnSearch.Clicked += async (s, e) =>
                await this.RegistrationSearchPageController.CallGetRegistrationRequestsAsync();

            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(btnSearch, LayoutOptions.End);
        }

		private UIDataGrid BuildDataGrid(string bindingPath, IndexedObjectCollection<DataDefinition> columnDefinitions)
		{
			return UIDataGridBuilderHelper.BuildStandardDataGrid(
				Guid.NewGuid().ToString(),
				bindingPath,
				columnDefinitions,
				async (s, e) =>
				{
					if (e.Item != null)
					{
						RegistrationSearchPageController.SetSelectedRegistrationKey(e.Item);
						await RegistrationSearchPageController.GoToRegistrationRequestLineAsync();
					}
				}
			);
		}
        #endregion

        #region Grid Column Definitions

        private IndexedObjectCollection<DataDefinition> DetailsGridColumnDefinitions()
        {

            return [
                // Command column with icon
                new DataDefinition()
                {
                    DataName = "Actions",
                    BindingPath = RegistrationSearchPageController.RegistrationSearchPageModelFields.RegistrationRequestKey,
                    Caption = "More Info",
                    EntryType = ControlTypeName.Command,
                    Commands = {
                        new CommandDefinition(new Command(async (obj) =>
                        {
                            if(obj is CellData cellData)
                            {
                                await this.RegistrationSearchPageController
                                    .CallGoToRegistrationRequestInfoAsync(
                                        (IDictionary<string, object>)cellData.Item);
                            }
                        }), CommandIcon: "Eyeicon128")
                    }
                },

                // Data columns
                new DataDefinition()
                {
                    DataName = RegistrationSearchPageController.RegistrationSearchPageModelFields.RegistrationRequestKey,
                    BindingPath = RegistrationSearchPageController.RegistrationSearchPageModelFields.RegistrationRequestKey,
                    Caption = "Req. No."
                },
                new DataDefinition()
                {
                    DataName = RegistrationSearchPageController.RegistrationSearchPageModelFields.PONumber,
                    BindingPath = RegistrationSearchPageController.RegistrationSearchPageModelFields.PONumber,
                    Caption = "PO No"
                },
                new DataDefinition()
                {
                    DataName = RegistrationSearchPageController.RegistrationSearchPageModelFields.Status,
                    BindingPath = RegistrationSearchPageController.RegistrationSearchPageModelFields.Status,
                    Caption = "Status"
                }
            ];
        }

        #endregion
    }
}
```

#### 6.4: Example - Complex Page with Event Handlers

```csharp
using client.mobile.controls;
using client.mobile.controls.baseuicontrols;
using client.mobile.engines;
using client.mobile.pages;
using client.mobile.s4wes.constants;
using client.mobile.s4wes.models;
using shared.dataquery.objects;
using static client.mobile.s4wes.pages.receipt.RegistrationRequestLineDetailsPageController;

namespace client.mobile.s4wes.pages.receipt
{
    /// <summary>
    /// Page for RegistrationRequestLineDetailsPage.
    /// Purpose: View and edit registration request line item details.
    /// Layout: Form fields + Two action buttons (conditional visibility)
    /// </summary>
    public class RegistrationRequestLineDetailsPage : BaseContentPage
    {
        #region Controller Reference

        protected RegistrationRequestLineDetailsPageController RegistrationRequestLineDetailsPageController
            => (RegistrationRequestLineDetailsPageController)this.BaseController;

        #endregion

        #region Constructor

        public RegistrationRequestLineDetailsPage(
            RegistrationRequestLineDetailsPageController RegistrationRequestLineDetailsPageController)
            : base(RegistrationRequestLineDetailsPageController,
                   "Line Details",
                   nameof(RegistrationRequestLineDetailsPage))
        {
        }

        #endregion

        #region Lifecycle Methods

        protected override void AfterOnAppearing()
        {
            base.AfterOnAppearing();
            SetupAddToAssetToggleHandler();
            AddEditProductButtonToGrid();
        }

        #endregion

        #region Event Handlers Setup

        private void SetupAddToAssetToggleHandler()
        {
            I_UIControl? control = GetControl(
                RegistrationRequestLineDetailsModelFields.AddToAsset);
            if (control == null)
                return;

            UISwitch addToAssetSwitch = (UISwitch)control;
            bool? addToAssetFlag =
                this.RegistrationRequestLineDetailsPageController.GetAddToAssetFlag();

            if (addToAssetFlag == true)
            {
                // Can't uncheck once added to asset
                addToAssetSwitch.IsEnabled = false;
            }
            else
            {
                addToAssetSwitch.Toggled += OnAddToAssetToggled;
            }

            this.ApplyAddToAssetVisualAppearance(addToAssetFlag == true);
        }

        private void OnAddToAssetToggled(object? sender, ToggledEventArgs e)
        {
            ApplyAddToAssetVisualAppearance(e.Value);
        }

        private void ApplyAddToAssetVisualAppearance(bool AddToAssetChecked)
        {
            // Toggle button visibility based on checkbox state
            this.ChildControls["StartRegistrationBtn"].IsVisible = !AddToAssetChecked;
            this.ChildControls["AddToAssetBtn"].IsVisible = AddToAssetChecked;
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.Star },
                    new RowDefinition { Height = GridLength.Auto },
                }
            };

            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);
            contentGrid.Add(BuildActionsGridLayout(), 0, 1);

            return contentGrid;
        }

        private UIGrid BuildActionsGridLayout()
        {
            UIButton startRegistrationBtn = BuildStartRegistrationButton();
            UIButton addToAssetBtn = BuildAddToAssetButton();

            return ActionGridBuilderHelper.BuildVerticalButtonActionGrid(
                startRegistrationBtn, addToAssetBtn);
        }

        private UIButton BuildStartRegistrationButton()
        {
            UIButton startRegistrationBtn = UIButtonBuilderHelper.BuildButton(
                "StartRegistrationBtn", "Start Registration", null, string.Empty);

            startRegistrationBtn.Clicked += async (s, e) =>
                await ValidateThenRunAsync("AssetRegistration",
                    RegistrationRequestLineDetailsPageController.CallGoToAssetRegistrationPageAsync);

            return startRegistrationBtn;
        }

        private UIButton BuildAddToAssetButton()
        {
            UIButton addToAssetBtn = UIButtonBuilderHelper.BuildButton(
                "AddToAssetBtn", "Add To Asset", null, string.Empty);

            addToAssetBtn.Clicked += async (s, e) =>
                await RunControllerActionAsync(
                    RegistrationRequestLineDetailsPageController.CallProcessAddToAssetAsync);

            return addToAssetBtn;
        }

        #endregion

        #region Custom Control Additions

        private void AddEditProductButtonToGrid()
        {
            // Find the product grid
            string productGridName = $"{this.DataDisplayDataDefParentContainer}_" +
                RegistrationRequestLineDetailsModelFields.ProductClass;

            if (!this.ChildControls.Contains(productGridName))
                return;

            UIGrid productGrid = (UIGrid)this.ChildControls[productGridName];

            // Create edit button
            UIImageButton editButton = new("EditProductBtn")
            {
                Source = ResourceHelper.GetImageSourcePNG("EditIcon32"),
                HorizontalOptions = LayoutOptions.End,
                HeightRequest = 20,
                Margin = new Thickness(10)
            };

            // Add tap gesture
            TapGestureRecognizer tapGesture = new() { NumberOfTapsRequired = 1 };
            tapGesture.Tapped += OnEditProductTapped;
            editButton.GestureRecognizers.Add(tapGesture);

            // Add to grid
            productGrid.Add(editButton, 1, 0);
        }

        private async void OnEditProductTapped(object? sender, EventArgs e)
        {
            // Standard lookups go through OpenLookupAsync — it is guarded
            // against double-taps (a second tap while a lookup is open returns
            // null instead of stacking a second modal) and manages
            // IsExpectingModalReturn internally:
            //
            // XalIndexedObjectCollection<Filter>? result =
            //     await OpenLookupAsync<LookupModalPage, LookupModalPageController>(
            //         new ProductLookupModalConfiguration());
            // MyPageController.UpdateProduct(result);
            //
            // CONTRACT: result is null when the user cancelled (✕ button or
            // hardware back) or a lookup was already open — Update* methods must
            // null-guard. Never hand-roll Navigation.PushModalAsync for lookups;
            // wrap custom lookup modals in RunLookupGuardedAsync(...) and make
            // sure their TaskCompletionSource resolves on EVERY exit path
            // (pop first, TrySetResult in finally — see fw LookupModalPage).
        }

        #endregion
    }
}
```

---

### Step 7: Register in DILoader

**Location**: `/engines/DILoader.cs`

**Template**:
```csharp
public class DILoader : client.mobile.engines.app.DILoader
{
    protected override void LoadServices(MauiAppBuilder Builder)
    {
        base.LoadServices(Builder);

        // ... existing registrations

        // Register {ScreenName} Controller
        Builder.Services.AddTransient(
            typeof({ScreenName}PageController),
            mobile.factory.Factory.ClientLocator.GetType(nameof({ScreenName}PageController)));

        // Register {ScreenName} Page
        Builder.Services.AddTransient(
            typeof({ScreenName}Page),
            mobile.factory.Factory.ClientLocator.GetType(nameof({ScreenName}Page)));
    }
}
```

**Example**:
```csharp
using client.mobile.s4wes.models;
using client.mobile.s4wes.pages.receipt;

namespace client.mobile.s4wes.engines
{
    public class DILoader : client.mobile.engines.app.DILoader
    {
        protected override void LoadServices(MauiAppBuilder Builder)
        {
            base.LoadServices(Builder);

            // Registration Search Page
            Builder.Services.AddTransient(
                typeof(RegistrationSearchPageController),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationSearchPageController)));
            Builder.Services.AddTransient(
                typeof(RegistrationSearchPage),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationSearchPage)));

            // Registration Request Info Page
            Builder.Services.AddTransient(
                typeof(RegistrationRequestInfoPageController),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestInfoPageController)));
            Builder.Services.AddTransient(
                typeof(RegistrationRequestInfoPage),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestInfoPage)));

            // Registration Request Lines Page
            Builder.Services.AddTransient(
                typeof(RegistrationRequestLinesPageController),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestLinesPageController)));
            Builder.Services.AddTransient(
                typeof(RegistrationRequestLinesPage),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestLinesPage)));

            // Registration Request Line Details Page
            Builder.Services.AddTransient(
                typeof(RegistrationRequestLineDetailsPageController),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestLineDetailsPageController)));
            Builder.Services.AddTransient(
                typeof(RegistrationRequestLineDetailsPage),
                mobile.factory.Factory.ClientLocator.GetType(nameof(RegistrationRequestLineDetailsPage)));

            // Asset Registration Page
            Builder.Services.AddTransient(
                typeof(AssetRegistrationPageController),
                mobile.factory.Factory.ClientLocator.GetType(nameof(AssetRegistrationPageController)));
            Builder.Services.AddTransient(
                typeof(AssetRegistrationPage),
                mobile.factory.Factory.ClientLocator.GetType(nameof(AssetRegistrationPage)));
        }
    }
}
```

**Important Notes**:
- Always register **BOTH** the Controller and the Page
- Use `AddTransient` lifecycle (new instance per request)
- Registration order doesn't matter
- Use `Factory.ClientLocator.GetType(nameof(...))` for type resolution

---

### Step 8: Register Navigation in AppController

**Location**: `/AppController.cs`

**Template**:
```csharp
public class AppController : client.mobile.AppController
{
    protected override void InitializeRouting()
    {
        // Register route for {ScreenName}
        Routing.RegisterRoute(
            $"//Main/Operation/{ScreenNames.{Parent}}/{ScreenNames.{Current}}",
            typeof({ScreenName}Page));

        // ... more routes

        base.InitializeRouting();
    }
}
```

**Navigation Route Structure**:
```
//Main/Operation/{Feature}/{Screen1}/{Screen2}/{SubScreen}
```

**Example**:
```csharp
using client.mobile.s4wes.constants;
using client.mobile.s4wes.pages.receipt;

namespace client.mobile.s4wes
{
    public class AppController : client.mobile.AppController
    {
        protected override void InitializeRouting()
        {
            // Registration flow - hierarchical structure

            // Level 1: Search page (root of Registration feature)
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}",
                typeof(RegistrationSearchPage));

            // Level 2: Request info page
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}/{ScreenNames.RegistrationRequestInfo}",
                typeof(RegistrationRequestInfoPage));

            // Level 2: Request lines page
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}/{ScreenNames.RegistrationRequestLines}",
                typeof(RegistrationRequestLinesPage));

            // Level 3: Line details page (child of lines)
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}/{ScreenNames.RegistrationRequestLines}/{ScreenNames.RegistrationRequestLineDetails}",
                typeof(RegistrationRequestLineDetailsPage));

            // Level 4: Product lookup (child of line details)
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}/{ScreenNames.RegistrationRequestLines}/{ScreenNames.RegistrationRequestLineDetails}/{ScreenNames.ProductLookup}",
                typeof(ProductLookupPage));

            // Level 4: Asset registration (child of line details)
            Routing.RegisterRoute(
                $"//Main/Operation/{ScreenNames.Registration}/{ScreenNames.RegistrationRequestLines}/{ScreenNames.RegistrationRequestLineDetails}/{ScreenNames.AssetRegistration}",
                typeof(AssetRegistrationPage));

            base.InitializeRouting();
        }
    }
}
```

**Navigation Hierarchy Benefits**:
- Automatic back button behavior
- Parent-child relationship tracking
- Navigation stack management
- Consistent navigation patterns

---

### Step 9: Test and Validate

**Testing Checklist**:

- [ ] **SQL Metadata**: Run SQL scripts on database, verify no errors
- [ ] **Code Compilation**: Build project, verify no compilation errors
- [ ] **Navigation**: Test navigation to screen from parent
- [ ] **Form Fields**: Verify all fields appear correctly
- [ ] **Field Properties**: Check visibility, readonly, mandatory states
- [ ] **Dropdowns**: Verify value lists populate correctly
- [ ] **Cascading Dropdowns**: Test parent-child filtering
- [ ] **Default Values**: Verify default values are set
- [ ] **Conditional Visibility**: Test appearance rules trigger correctly
- [ ] **Validation**: Test validation rules on action buttons
- [ ] **Button Actions**: Test all button clicks execute correctly
- [ ] **Server Communication**: Verify data is saved/loaded from server
- [ ] **Navigation Forward**: Test navigation to child screens with data passing
- [ ] **Navigation Back**: Test back button returns to previous screen
- [ ] **Data Binding**: Verify changes in form update ViewModel
- [ ] **Loading State**: Verify loading overlay shows during async operations

---

## Complete Working Example

### Example: Simple Search Screen

Let's create a complete example of a **Product Search** screen with:
- Search filters: Product Code, Product Name, Category
- Search button
- Results grid with "View Details" command column

#### Step 1: SQL Metadata

**File**: `pages/screens-defs-ProductSearch.sql`

```sql
-- ========================================
-- Screen: ProductSearchPage
-- Purpose: Search for products
-- Profile Code: PSP
-- ========================================

-- Field 1: Product Code (text input)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'ProductSearchPage', 'SearchFilters', 'PRODUCTCODE', 'Product Code',
    1, 'String', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 8, 'Like',
    'PSP', 1, 0, 0
);

-- Field 2: Product Name (text input)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'ProductSearchPage', 'SearchFilters', 'PRODUCTNAME', 'Product Name',
    1, 'String', 'Value', NULL, NULL,
    'admin', CURRENT_TIMESTAMP, 8, 'Like',
    'PSP', 2, 0, 0
);

-- Field 3: Category (dropdown)
INSERT INTO master.DATADISPLAYDATADEFINITION (
    DATADISPLAYNAME, DATAGROUPNAME, DATANAME, DATADESCRIPTION,
    ISVISIBLE, DATATYPE, FILTERTYPE, FILTERDEFAULTVALUES, VALUELISTDEFINITION,
    CREATEDBY, CREATEDDATE, WIDTH, FILTERCOMPARISONTYPE,
    SCREENPROFILENAME, SEQUENCE, ISREADONLY, ISMANDATORY
) VALUES (
    'ProductSearchPage', 'SearchFilters', 'CATEGORYCODE', 'Category',
    1, 'String', 'List', NULL, 'PRODUCTCATEGORY',
    'admin', CURRENT_TIMESTAMP, 8, 'Equal',
    'PSP', 3, 0, 0
);

-- Value List: PRODUCTCATEGORY
INSERT INTO master.DATADISPLAYVALUELISTDEFINITION(
    VALUELISTDEFINITION, TABLENAME, VALUECOLUMNNAME, DISPLAYCOLUMNNAME,
    PARENTVALUESOURCE, PARENTVALUECOLUMNNAME, CONSTRAINTS, ADDBLANKITEM,
    CREATEDBY, CREATEDDATE, SELECTFIRST, SELECTIFSINGLE,
    BPNAME, METHODNAME, ISSEARCHABLE, PRELOAD
) VALUES (
    'PRODUCTCATEGORY', 'PRODUCTCATEGORY', 'CATEGORYCODE', 'CATEGORYNAME',
    NULL, NULL, NULL, 1,
    'admin', CURRENT_TIMESTAMP, 0, 0,
    'BPProductCategoryCRUD', 'Refresh', 1, 0
);
```

#### Step 2: Constants

**File**: `constants/ScreenNames.cs`
```csharp
public class ScreenNames : client.mobile.constants.ScreenNames
{
    public const string ProductSearch = "ProductSearch";
}
```

**File**: `constants/BPNames.cs`
```csharp
public class BPNames : client.mobile.constants.BPNames
{
    public const string BVProductSummary = "BVProductSummary";
}
```

#### Step 3: ViewModel

**File**: `models/product/ProductSearchViewModel.cs`
```csharp
using client.mobile.engines;
using client.mobile.models;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for ProductSearchPage.
    /// Purpose: Holds search filters and product result grid data.
    /// </summary>
    public class ProductSearchViewModel : GridViewModel
    {
    }
}
```

#### Step 4: Controller

**File**: `pages/product/ProductSearchPageController.cs`
```csharp
using client.mobile.controller;
using client.mobile.engines;
using client.mobile.engines.app;
using client.mobile.models;
using client.mobile.navigation;
using client.mobile.s4wes.constants;
using client.mobile.s4wes.models;
using shared.dataquery.objects;
using shared.objects;
using shared.xal.objects;
using shared.xal.objects.collections;
using System.Data;
using static shared.objects.DataHelper;

namespace client.mobile.s4wes.pages.product
{
    /// <summary>
    /// Controller for ProductSearchPage.
    /// Purpose: Search for products based on filter criteria.
    /// </summary>
    public class ProductSearchPageController : BaseController
    {
        #region Field Constants

        public class ProductSearchPageModelFields
        {
            public const string ProductCode = "PRODUCTCODE";
            public const string ProductName = "PRODUCTNAME";
            public const string CategoryCode = "CATEGORYCODE";
        }

        #endregion

        #region ViewModel

        internal ProductSearchViewModel ProductSearchModel = new();
        public override BaseViewModel ViewModel => this.ProductSearchModel;

        #endregion

        #region Constructor

        public ProductSearchPageController(I_NavigationService NavigationService)
            : base(NavigationService)
        {
        }

        #endregion

        #region Internal Action Methods

        /// <summary>
        /// Search for products based on filter criteria.
        /// </summary>
        internal async Task<Result> CallSearchProductsAsync()
        {
            await IsBusyFor(async () =>
            {
                try
                {
                    DataSet dsResult = await GetProductsSummaryAsync();

                    if (DataHelper.IsEmptyResult(dsResult))
                    {
                        result = Result.Failure("No products found", ErrorType.SystemError);
                    }
                    else
                    {
                        this.ProductSearchModel.SetModelData(dsResult.Tables[0]);
                        result = Result.Success();
                    }
                }
                catch (Exception methodEx)
                {
                   result = Result.Failure(methodEx.Message, ErrorType.SystemError);
                }
            });
        }

        #endregion

        #region Server Communication

        private Task<DataSet> GetProductsSummaryAsync()
        {
            return mobile.factory.ModelIO.Instance.ExecuteActionAsync<DataSet>(
                BPNames.BVProductSummary,
                MethodNames.Refresh,
                this.ProductSearchModel.DynamicFilters,
                new XalIndexedObjectCollection<Filter>());
        }

        #endregion
    }
}
```

#### Step 5: Page

**File**: `pages/product/ProductSearchPage.cs`
```csharp
using client.mobile.controls;
using client.mobile.controls.baseuicontrols;
using client.mobile.engines;
using client.mobile.pages;
using client.mobile.s4wes.constants;
using client.mobile.s4wes.models;
using shared.dataquery.objects;
using shared.objects;

namespace client.mobile.s4wes.pages.product
{
    /// <summary>
    /// Page for ProductSearchPage.
    /// Purpose: Search for products.
    /// Layout: Search filters + Search button + Results grid
    /// </summary>
    public class ProductSearchPage : BaseContentPage
    {
        #region Controller Reference

        protected ProductSearchPageController ProductSearchPageController
            => (ProductSearchPageController)this.BaseController;

        #endregion

        #region Fields

        UIDataGrid? ResultGrid;

        #endregion

        #region Constructor

        public ProductSearchPage(ProductSearchPageController ProductSearchPageController)
            : base(ProductSearchPageController, "Product Search", nameof(ProductSearchPage))
        {
            HideShellBackButton();
        }

        #endregion

        #region Lifecycle Methods

        protected override void BeforeOnAppearing()
        {
            if (ResultGrid != null)
                ResultGrid.SelectedItem = null;
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            // Build result grid
            
			ResultGrid = BuildDataGrid(nameof(ProductSearchPageController.ProductSearchModel.DataRows),
				ResultGridColumnDefinitions());
            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.Auto },  // Filters
                    new RowDefinition { Height = GridLength.Auto },  // Button
                    new RowDefinition { Height = GridLength.Star },  // Grid
                }
            };

            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);
            contentGrid.Add(BuildActionsGridLayout(), 0, 1);
            contentGrid.Add(ResultGrid, 0, 2);

            return contentGrid;
        }

        private UIGrid BuildActionsGridLayout()
        {
            UIButton btnSearch = UIButtonBuilderHelper.BuildButton(
                "SearchBtn", "Search", string.Empty, string.Empty);

            btnSearch.Clicked += async (s, e) =>
                await this.ProductSearchPageController.CallSearchProductsAsync();

            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(
                btnSearch, LayoutOptions.End);
        }
		private UIDataGrid BuildDataGrid(string bindingPath, IndexedObjectCollection<DataDefinition> columnDefinitions)
		{
			return UIDataGridBuilderHelper.BuildStandardDataGrid(
				Guid.NewGuid().ToString(),
				bindingPath,
				columnDefinitions,
				async (s, e) =>
				{
					if (e.Item != null)
					{
						ProductSearchPageController.SetSelectedProductCode(e.Item);
						await ProductSearchPageController.GoToProductAsync();
					}
				}
			);
		}
        #endregion

        #region Grid Column Definitions

        private IndexedObjectCollection<DataDefinition> ResultGridColumnDefinitions()
        {
            var fields = ProductSearchPageController.ProductSearchPageModelFields;

            return [
                new DataDefinition()
                {
                    DataName = fields.ProductCode,
                    BindingPath = fields.ProductCode,
                    Caption = "Product Code"
                },
                new DataDefinition()
                {
                    DataName = fields.ProductName,
                    BindingPath = fields.ProductName,
                    Caption = "Product Name"
                },
                new DataDefinition()
                {
                    DataName = fields.CategoryCode,
                    BindingPath = fields.CategoryCode,
                    Caption = "Category"
                }
            ];
        }

        #endregion
    }
}
```

#### Step 6: DILoader Registration

**File**: `engines/DILoader.cs`
```csharp
public class DILoader : client.mobile.engines.app.DILoader
{
    protected override void LoadServices(MauiAppBuilder Builder)
    {
        base.LoadServices(Builder);

        // Product Search Page
        Builder.Services.AddTransient(
            typeof(ProductSearchPageController),
            mobile.factory.Factory.ClientLocator.GetType(nameof(ProductSearchPageController)));
        Builder.Services.AddTransient(
            typeof(ProductSearchPage),
            mobile.factory.Factory.ClientLocator.GetType(nameof(ProductSearchPage)));
    }
}
```

#### Step 7: AppController Navigation

**File**: `AppController.cs`
```csharp
public class AppController : client.mobile.AppController
{
    protected override void InitializeRouting()
    {
        Routing.RegisterRoute(
            $"//Main/Operation/{ScreenNames.ProductSearch}",
            typeof(ProductSearchPage));

        base.InitializeRouting();
    }
}
```

---

## Best Practices and Conventions

### Naming Conventions

1. **Screen Names**:
   - Pattern: `{Feature}{Purpose}Page`
   - Examples: `RegistrationSearchPage`, `ProductLookupPage`, `AssetRegistrationPage`

2. **Controller Names**:
   - Pattern: `{ScreenName}PageController`
   - Examples: `RegistrationSearchPageController`, `ProductLookupPageController`

3. **ViewModel Names**:
   - Pattern: `{ScreenName}ViewModel`
   - Examples: `RegistrationSearchViewModel`, `ProductLookupViewModel`

4. **Field Constants** (Centralized Pattern):
   - Location: `constants/ModelFields.cs` (base) + `constants/ModelFields.{FeatureName}.cs` (feature-specific)
   - Pattern: `ModelFields.{DomainClass}.{FIELDNAME}`
   - Field constant values: UPPERCASE (matching database column names)
   - Examples:
     - `Common.REFERENCEKEY` - shared fields
     - `PickRequest.QTYTOPICK` - feature-specific fields
     - `Location.LOCATIONCODE` - domain-specific fields
   - **Do NOT** create nested `{ScreenName}ModelFields` classes in controllers

5. **Method Names**:
   - Internal methods: `Call{Action}Async()`
   - Private helpers: `{Action}Async()`, `Build{Component}()`
   - Examples: `CallSearchProductsAsync()`, `GetProductsSummaryAsync()`, `BuildActionsGridLayout()`

### Code Organization

1. **Use Regions** for code organization:
   ```csharp
   // Controller regions (NO Field Constants region - use centralized ModelFields)
   #region ViewModel
   #region Constructor
   #region Initialization
   #region Internal Action Methods
   #region Private Helper Methods
   #region Server Communication
   
   // Page regions
   #region UI Layout
   #region Event Handlers
   ```

2. **Separate concerns**:
   - Controller: Business logic, server communication, navigation
   - Page: UI layout, user interactions, event handlers
   - ViewModel: Data storage, property change notifications
   - **ModelFields**: Centralized field constants (in `constants/` folder)

3. **Use centralized ModelFields** instead of magic strings:
   ```csharp
   // Import at top of file
   using static client.mobile.s4wes.constants.ModelFields;
   
   // Good - using centralized ModelFields
   Filter.GetValueFilter(Common.PRODUCTCODE, ...)
   Filter.GetValueFilter(PickRequest.QTYTOPICK, ...)
   
   // Bad - magic strings
   Filter.GetValueFilter("PRODUCTCODE", ...)
   
   // Bad - nested class in controller (deprecated pattern)
   Filter.GetValueFilter(ProductSearchPageModelFields.ProductCode, ...)
   ```

### Error Handling

1. **Always wrap server calls** in try-catch:
   ```csharp
   try
   {
       DataSet dsResult = await GetDataAsync();
       // Process result
   }
   catch (Exception methodEx)
   {
       result = Result.Failure(methodEx.Message, ErrorType.SystemError);
   }
   ```

2. **Check for empty results**:
   ```csharp
   if (DataHelper.IsEmptyResult(dsResult))
   {
        result = Result.Failure("No data found", ErrorType.SystemError);
   }
   ```

3. **Validate before actions** — use the base-class helper:
   ```csharp
   await ValidateThenRunAsync("Submit", MyPageController.CallSubmitAsync);
   ```
   For actions without validation rules:
   ```csharp
   await RunControllerActionAsync(MyPageController.CallSubmitAsync);
   ```
   Only hand-write `ValidatePageAsync` + `DisplayValidationErrorsAsync` when custom
   branching is needed between validation and the action.

### Performance Optimization

1. **Use IsBusyFor()** for all async operations:
   ```csharp
   return IsBusyFor(async () => { /* operation */ });
   ```

2. **Never add artificial delays in InitializeAsync()**. Older code started every
   override with `await Task.Delay(200); // allow UI to settle` — that idiom is a
   template leftover that cost 200ms per navigation and has been removed everywhere.
   If the override ends up with no awaits, make it synchronous:
   ```csharp
   public override Task InitializeAsync()
   {
       InitViewModelValues();
       return Task.CompletedTask;
   }
   ```
   Don't add the override at all when there is nothing to initialize.

3. **Cache metadata** - services automatically cache by screen name

### UI Best Practices

1. **Use GridLength appropriately**:
   - `GridLength.Star` - Fill available space (for scrollable content, grids)
   - `GridLength.Auto` - Size to content (for buttons, fixed content)

2. **Set back button behavior** on root screens:
   ```csharp
   HideShellBackButton();
   ```
   When back must run logic (skip/complete/reset), wire the toolbar arrow AND the
   hardware back button in one call:
   ```csharp
   SetBackAction(MyBackActionAsync);
   ```

3. **Clear selections** on page appearance:
   ```csharp
   protected override void BeforeOnAppearing()
   {
       if (ResultGrid != null)
           ResultGrid.SelectedItem = null;
   }
   ```

4. **Add event handlers** in AfterOnAppearing():
   ```csharp
   protected override void AfterOnAppearing()
   {
       base.AfterOnAppearing();
       SetupEventHandlers();
   }
   ```

### SQL Best Practices

1. **Use consistent SCREENPROFILENAME** (4-letter codes)
2. **Sequence fields logically** (1, 2, 3...) within groups
3. **Set WIDTH** appropriately (4 = half, 8 = full)
4. **Use descriptive DATADESCRIPTION** (user-facing labels)
5. **Document complex conditions** with comments in SQL
6. **Group related fields** using DATAGROUPNAME
7. **Use CONTROLTYPE in DATAPANELAPPEARANCEDEFINITION** to override auto-determined control types (ChipGroup, Chip, CaptionValue, InlineCaptionLabel, Separator)
8. **Use CONTROLPARAMS in DATAPANELAPPEARANCEDEFINITION** for additional control customization via semicolon-separated key='value' pairs (e.g., `EntryStyleName='StyleName'`)

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Fields not appearing on screen

**Possible Causes**:
1. SQL not executed or typo in DATADISPLAYNAME
2. Screen name mismatch between SQL and code
3. ISVISIBLE set to 0
4. SEQUENCE not set or duplicated

**Solution**:
- Verify SQL executed successfully
- Check DATADISPLAYNAME exactly matches nameof(Page)
- Verify ISVISIBLE = 1
- Set unique SEQUENCE values

#### Issue: Dropdown list is empty

**Possible Causes**:
1. VALUELISTDEFINITION name mismatch
2. Source table has no data
3. CONSTRAINTS filtering out all rows
4. BPNAME/METHODNAME not returning data

**Solution**:
- Verify VALUELISTDEFINITION exists in DATADISPLAYVALUELISTDEFINITION
- Check source table has data
- Test CONSTRAINTS syntax (use `~FIELDNAME~` for field references)
- Test Business Process call manually

#### Issue: Conditional visibility not working

**Possible Causes**:
1. CONDITION expression syntax error
2. Field name typo in condition
3. SEQUENCE priority issues
4. PropertyChanged not firing

**Solution**:
- Verify CONDITION uses `~FIELDNAME~` syntax
- Check field names match exactly (case-sensitive)
- Set SEQUENCE to ensure proper evaluation order
- Ensure ViewModel fires PropertyChanged

#### Issue: Validation not triggering

**Possible Causes**:
1. ACTIONNAME mismatch
2. Expression always evaluates to true
3. ValidateThenRunAsync()/ValidatePageAsync() not called

**Solution**:
- Verify ACTIONNAME matches the first parameter of ValidateThenRunAsync() (or ValidatePageAsync() in manual handlers)
- Test expression logic (remember: true = pass, false = fail)
- Ensure the button handler goes through ValidateThenRunAsync()

#### Issue: Navigation not working

**Possible Causes**:
1. Route not registered in AppController
2. Route string mismatch
3. DILoader missing registration
4. Navigation parameters wrong property name

**Solution**:
- Verify Routing.RegisterRoute() called
- Check route string matches exactly
- Ensure both Controller and Page registered in DILoader
- Use nameof() for navigation parameter keys

#### Issue: Data not binding to controls

**Possible Causes**:
1. BindingPath incorrect
2. DynamicFilters not initialized
3. DataName mismatch
4. PropertyChanged not implemented

**Solution**:
- Verify BindingPath = "{DataBindingPathPrefix}[{DataName}].Value"
- Initialize DynamicFilters in controller
- Check DataName matches Filter name exactly
- Ensure ViewModel inherits from DynamicViewModel

#### Issue: Loading overlay stuck

**Possible Causes**:
1. Exception in IsBusyFor() block
2. Async operation not awaited
3. IsBusy counter not decremented

**Solution**:
- Wrap operations in try-catch
- Ensure all async methods use await
- Use IsBusyFor() wrapper (handles counter automatically)

---

## Appendix: Quick Reference

### Data Types
- `String` - Text input (Entry)
- `Double` / `Decimal` - Numeric input (NumericEntry)
- `DateTime` - Date picker (DatePicker)
- `Boolean` - Toggle switch (Switch) or checkbox (CheckBox)
- `Integer` - Whole numbers (NumericEntry)
- `Unknown` - Text label (Label)

### Comparison Types
- `Equal` - Exact match
- `Like` - Partial match (contains)
- `GreaterThan` - Greater than
- `GreaterOrEqual` - Greater than or equal to
- `LessThan` - Less than
- `LessOrEqual` - Less than or equal to
- `Range` - Between two values

### Control Types (Automatically Determined from DataType/FilterType)
- `Entry` - Text input
- `NumericEntry` - Number input
- `DatePicker` - Date selection
- `Switch` - Boolean toggle
- `CheckBox` - Boolean checkbox
- `Combobox` - Dropdown list
- `ChipGroup` - Editable multi-select chip group (set via CONTROLTYPE override, requires ValueList)
- `Chip` - Display-only chip/badge (set via CONTROLTYPE override)
- `Label` - Read-only text
- `Editor` - Multi-line text
- `Password` - Password entry
- `MaskedEntry` - Formatted input

### Override Control Types (via CONTROLTYPE in DATAPANELAPPEARANCEDEFINITION)
These override the auto-determined type. Set in the `CONTROLTYPE` column of `DATAPANELAPPEARANCEDEFINITION`:
- `ChipGroup` - Editable multi-select chip group (requires ValueList on the field)
- `Chip` - Display-only chip/badge (e.g., status indicator)
- `CaptionValue` - Framed box with caption label above a bound value label
- `InlineCaptionLabel` - Horizontal layout with caption + value side-by-side
- `Separator` - Thin horizontal line divider

### Control Parameters (via CONTROLPARAMS in DATAPANELAPPEARANCEDEFINITION)
Semicolon-separated `key='value'` pairs for additional control customization:
- `EntryStyleName='StyleName'` - Override the control's style name
- `ConverterProfile='ProfileName'` - Name of a `ChipConverterRegistry` profile for display-only Chip text/background/text-color converters

### ⚠️ Chip + ReadOnly Gotcha
When using the `Chip` control type override, **never set READONLY = 1**. DevExpress Chip enforces its own default styling (grey text, white background) when ReadOnly is true, which completely overrides any color bindings from converters. The chip is already non-interactive via `InputTransparent = true`.

### Field Icons (IMAGENAME)
- Use `IMAGENAME` column in DATADISPLAYDATADEFINITION to specify an icon/image name for a field
- Example values: `'confirmedQty'`, `'dropId'`, `'barcode'`
- Set to `NULL` if no icon is needed for the field

### Display Types (DATADISPLAYDEFINITION)
- `Panel` — Dynamic form only
- `CardsGrid` — DB-driven card list only (via DataCardTemplateBuilder → UICollectionView)
- `PanelAndCardsGrid` — Both panel form and card list on same page

### CardsGrid Page Overrides (code, not DB)
- `CardsGridParentContainer` — name of the I_UIParentControl container
- `GetCardsGridItemsSourceBinding()` — ViewModel path to rows collection
- `GetCardsGridTapAction()` — optional row tap handler
- `GetCardsGridEmptyViewText()` — empty state text
- `CreateCardsGridConfiguration()` — optional spacing/accent overrides

### GRIDINCLUDE / PANELINCLUDE Quick Rules
- `PANELINCLUDE=1` → panel; `GRIDINCLUDE=1` → cards
- Both NULL → included on whichever surface the display type needs
- Only sibling set → excluded from this surface
- GRID* columns (GRIDCAPTION, GRIDISVISIBLE, GRIDSEQUENCE, GRIDGROUPNAME) override panel equivalents for cards; GRIDWIDTH is not read by mobile

### Expression Functions
- `isemptyornull(~FIELDNAME~)` - Check if field is empty or null
- `~FIELDNAME~=value` - Equality check
- `~FIELDNAME~!=value` - Inequality check
- `~FIELDNAME~>value` - Greater than
- `~FIELDNAME~<value` - Less than
- `||` - Logical OR
- `&&` - Logical AND

### Helper Classes
- `Factory.MessageDisplayService.ShowMessageAsync()` - Show message to user (async Task; needs `using client.mobile.factory;`. Await it in page handlers; inside an IsBusyFor scope use `_ = ...` fire-and-forget so the blocking alert doesn't hold the busy spinner open. MessageDisplayHelper is deleted.)
- `UIButtonBuilderHelper.BuildButton()` - Create button (translates its Caption internally - do NOT pre-wrap in GlobalizationHelper.Translate)
- `ActionGridBuilderHelper.BuildSingleButtonActionGrid()` - Create button layout
- `ActionGridBuilderHelper.BuildHorizontalButtonActionGrid()` - Create multi-button Horizontal layout

### BaseContentPage Helpers (framework, use instead of hand-rolled patterns)
- `ValidateThenRunAsync(actionName, controllerCall)` - Validate + run controller call + error modal, one busy scope
- `RunControllerActionAsync(controllerCall)` - Run controller call under busy indicator + error modal on failure
- `HideShellBackButton()` - Hide back button on root screens
- `SetBackAction(asyncAction)` - Custom back logic wired to toolbar arrow AND hardware back, with re-entrancy guard
- `OpenLookupAsync<LookupModalPage, LookupModalPageController>(config)` - Open lookup modal; double-tap-guarded, returns null on cancel (✕/hardware back) — null-guard the result
- `RunLookupGuardedAsync(showLookup)` - Same re-entrancy guard for custom (non-LookupModalPage) lookup modals

### s4assets App-Level Helpers (ExtendedBaseContentPage / pages/shared)
- `BuildScaffold(content, actionsFooter)` - Star/Auto page shell; pass a UIScrollView for scrolling pages (row spacing follows automatically)
- `BuildInstructionsBanner()` + `InstructionsLabel.Text` - Standard instructions banner
- `SuccessPageBase` - Base for "operation complete" pages: green check header, SummaryGroup card, one completion button that also answers back; subclass overrides SuccessTitle/SuccessSubtitle/CompletionButtonText/CompletionButtonName/ProgressStrip/RunCompletionAsync
- `ActionGridBuilderHelper.BuildVerticalButtonActionGrid()` - Create multi-button Vertical layout
- `FiltersHelper.MergeFilters()` - Merge filter collections
- `FiltersHelper.ExistsWithText(filters, name)` - Filter exists and has visible (non-whitespace) text
- `FiltersHelper.AddValueConstraintIfSet(constraints, filters, filterKey, column, dataType)` - Add a value constraint when the source filter is set (replaces local AddIfSet helpers)
- `FiltersHelper.AddDateRangeConstraintIfSet(constraints, filters, fromKey, toKey, column)` - Add open-ended date-range constraints from a from/to filter pair
- `FiltersHelper.GetString(filters, name)` - Filter value as string, never null (replaces local GetFilterString/GetResultString helpers)
- `FiltersHelper.ClearValue(filters, name)` - Null the filter's value if present (replaces local Clear helpers)
- `SearchCriteriaHelper.AddIfSet(criteria, filters, key, label)` - Add a translated "Label: value" search-criteria entry (replaces local criteria AddIfSet helpers)
- `DataHelper.IsEmptyResult()` - Check if DataSet is empty
- `DataHelper.GetString()`, `GetInt()`, `GetDouble()` - Safe type conversion

---

## Summary

This guide provides everything needed to create screens in the mobile application:

1. **SQL Metadata** defines field properties, dropdowns, visibility rules, and validations
2. **ViewModel** holds form data in DynamicFilters collection
3. **Controller** manages business logic, server communication, and navigation
4. **Page** builds UI and handles user interactions
5. **DILoader** registers components for dependency injection
6. **AppController** defines navigation routes

By following the templates and patterns in this guide, you can create any screen configuration from a specification document. The metadata-driven architecture allows rapid development and changes without code recompilation.

---

**Document Version**: 1.0
**Last Updated**: 2025
**Author**: Generated from comprehensive framework analysis
