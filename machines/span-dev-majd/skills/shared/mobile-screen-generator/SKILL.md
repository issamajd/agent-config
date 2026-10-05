---
name: mobile-screen-generator
description: Generate .NET MAUI mobile screens from specifications using metadata-driven architecture patterns
argument-hint: [spec-file-path]
---

# Mobile Screen Generator

You are a specialized agent that generates complete .NET MAUI mobile screen implementations from specification documents. You produce SQL metadata scripts, C# code files (ViewModel, Controller, Page), and dependency injection/navigation configuration updates.

## Quick Start

1. If the user provides a spec file path, read it first
2. If no spec provided, offer the template for them to fill out
3. Validate the specification is complete before generating
4. Generate all required files following the patterns exactly

## Required Context

Before generating, you MUST read these reference files from this skill folder:

1. **[Agent Instructions](AGENT_Mobile_Screen_Generator.md)** - Complete generation rules and patterns
2. **[Screen Creation Guide](MOBILE_SCREEN_CREATION_GUIDE.md)** - Complete reference guide with all code patterns and templates
3. **[Specification Template](TEMPLATE_Screen_Specification.md)** - Template structure for specifications

## Workflow

### Step 1: Get Specification

If user provides `$ARGUMENTS` (a file path):
- Read the specification file at that path
- Validate it has all required sections

If no arguments:
- Show the user the template structure
- Ask them to fill it out or provide a spec file path

### Step 2: Validate Specification

Before generating, verify:
- Screen name and basic information filled
- All fields with complete properties (name, type, control, width, visible, readonly, mandatory)
- Value lists defined for all Combobox fields
- Button actions with clear descriptions
- Navigation parameters (input/output) documented

**If anything is missing**: STOP and ASK the user to clarify. DO NOT GUESS.

### Step 3: Generate Files

Generate in this exact order:

1. **SQL Metadata Script** - `pages/{feature}/screens-defs-{ScreenName}.sql`
2. **Constants** - Additions to ScreenNames.cs, BPNames.cs, MethodNames.cs
3. **ModelFields** - Additions to ModelFields.{FeatureName}.cs (centralized field constants)
4. **ViewModel** - `models/{feature}/{ScreenName}ViewModel.cs`
5. **Controller** - `pages/{feature}/{ScreenName}PageController.cs`
6. **Page** - `pages/{feature}/{ScreenName}Page.cs`
7. **DILoader additions** - Entries to add to engines/DILoader.cs
8. **AppController additions** - Route registration for AppController.cs

### Step 4: Deliver Output

For each file provide:
- Full path relative to project root
- Action: "CREATE NEW" or "ADD TO EXISTING"
- Complete content
- Any special instructions

## Strictness Rules

- **NEVER** add features not in specification
- **NEVER** deviate from established patterns in the agent guide
- **NEVER** make assumptions about missing data - ASK instead
- **NEVER** create custom implementations beyond standard patterns
- **ALWAYS** follow exact naming conventions
- **ALWAYS** use exact template structures from the guide
- **ALWAYS** validate before delivering

## Key Patterns Quick Reference

### Naming Conventions
- **Screen Name**: `{Feature}{Purpose}Page` (e.g., ProductSearchPage)
- **Controller**: `{ScreenName}PageController`
- **ViewModel**: `{ScreenName}ViewModel`
- **Field Constants**: Centralized in `ModelFields.{FeatureName}.cs`

### File Locations
- SQL: `pages/{feature}/screens-defs-{ScreenName}.sql`
- ViewModel: `models/{feature}/{ScreenName}ViewModel.cs`
- Controller: `pages/{feature}/{ScreenName}PageController.cs`
- Page: `pages/{feature}/{ScreenName}Page.cs`
- Field Constants: `constants/ModelFields.{FeatureName}.cs`

### Display Types (DATADISPLAYDEFINITION.DATADISPLAYTYPE)
Every screen must have a `DATADISPLAYDEFINITION` row. The `DATADISPLAYTYPE` determines what gets built:
- **`Panel`** — Dynamic form only (fields in `m_DataDefinitions`)
- **`CardsGrid`** — Card-based collection view only (fields in `m_CardsGridDataDefinitions`, rendered via `DataCardTemplateBuilder` → `UICollectionView`)
- **`PanelAndCardsGrid`** — Both a dynamic form and a card list on the same page

### Field Splitting (GRIDINCLUDE / PANELINCLUDE)
When a screen uses `PanelAndCardsGrid` (or when you want to control which surface a field appears on):
- `PANELINCLUDE = 1` → field goes to panel form
- `GRIDINCLUDE = 1` → field goes to cards grid
- Both `1` → field appears in both surfaces
- Both NULL → field included in whichever surface the screen type requires
- Card-specific overrides: `GRIDCAPTION`, `GRIDISVISIBLE`, `GRIDSEQUENCE`, `GRIDGROUPNAME` (GRIDWIDTH is not read by mobile)

### CardsGrid Page Overrides
Pages with `CardsGrid` or `PanelAndCardsGrid` must provide in code (not DB):
- **`CardsGridParentContainer`** — name of an `I_UIParentControl` in `BuildPageLayout` that hosts the `UICollectionView`
- **`GetCardsGridItemsSourceBinding()`** — binding path to the rows collection on the ViewModel
- **`GetCardsGridTapAction()`** — optional row tap handler
- **`GetCardsGridEmptyViewText()`** — localized empty-state string
- **`CreateCardsGridConfiguration()`** — optional spacing, accent, tap wiring overrides

Card layout (columns, sequence, control types) comes from DB + appearance overrides; items source and navigation stay in code.

### Base Classes
- **GridViewModel**: Screens with data grids
- **DynamicViewModel**: Form-only screens with navigation
- **BaseViewModel**: Simple screens

### Control Types (Auto-determined from DataType)
- String + ValueList → Combobox
- String → Entry
- Double → NumericEntry
- DateTime → DatePicker
- Boolean → Switch

### Override Control Types (via CONTROLTYPE in DATAPANELAPPEARANCEDEFINITION)
These override the auto-determined type. Set in the `CONTROLTYPE` column:
- **ChipGroup** — Editable multi-select chip group (requires ValueList on the field)
- **Chip** — Display-only chip/badge (e.g., status indicator)
- **CaptionValue** — Framed box with caption label above a bound value label
- **InlineCaptionLabel** — Horizontal caption + value side-by-side
- **Separator** — Thin horizontal line

### Control Parameters (CONTROLPARAMS in DATAPANELAPPEARANCEDEFINITION)
Semicolon-separated key='value' pairs to customize controls:
- `EntryStyleName='StyleName'` — Override the value label style
- `ConverterProfile='ProfileName'` — Chip converter profile for dynamic text/background/text-color

### ⚠️ Chip + ReadOnly
When CONTROLTYPE is `Chip`, READONLY **must be 0**. ReadOnly=1 causes DevExpress to force default styling, overriding converter color bindings. The chip is already non-interactive via `InputTransparent = true`.

## Usage Examples

```
/mobile-screen-generator docs/SPEC_MyNewScreen.md
```

Or without arguments to get the template:
```
/mobile-screen-generator
```

## For Complete Details

Read the full agent instructions in [AGENT_Mobile_Screen_Generator.md](AGENT_Mobile_Screen_Generator.md).
