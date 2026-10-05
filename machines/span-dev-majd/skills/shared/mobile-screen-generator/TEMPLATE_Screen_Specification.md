# Screen Specification Template

> **Instructions**: Fill out this template with your screen requirements. Sections marked with ⭐ are required. Remove any sections you don't need.

---

## 1. Basic Information ⭐

| Property | Value |
|----------|-------|
| **Screen Name** | `{ScreenName}Page` (e.g., ProductSearchPage) |
| **Screen Title** | "{Title}" (shown in header) |
| **Screen Profile Code** | {4-letter code} (e.g., PSP) |
| **Feature Area** | {folder name} (e.g., receipt, product, lookup) |
| **Parent Screen** | {ParentScreenName} or "None" (if root) |
| **Purpose** | {Brief description of what this screen does} |

---

## 2. Screen Layout ⭐

**Display Type** (choose one):
- [ ] **Panel** — Dynamic form only
- [ ] **CardsGrid** — Card-based collection view only
- [ ] **PanelAndCardsGrid** — Both form and card list on same page

Check all sections that apply:

- [ ] **Section 1: Form Fields** (present for Panel or PanelAndCardsGrid)
- [ ] **Section 2: Attributes Grid** (optional - dynamic entity attributes)
- [ ] **Section 3: Action Buttons** (list button labels below)
- [ ] **Section 4: Data Grid** (for search results or listings — legacy UIDataGrid, NOT CardsGrid)
- [ ] **Section 5: Cards Grid** (for DB-driven card list — see Section 11b)

**Buttons** (if Section 3 checked):
1. {Button Label} - {What it does}
2. {Button Label} - {What it does}

**Grid Columns** (if Section 4 checked):
- {Column1 Name}
- {Column2 Name}
- {Column3 Name}

**Cards Grid** (if Section 5 checked):
- Items source binding: {ViewModel property path, e.g. Rows}
- Tap action: {What happens on card tap, or "None"}
- Empty text: {Text shown when no items}

---

## 3. Navigation Flow ⭐

### Input Parameters
Data received from parent screen:

| Parameter Name | Data Type | Description |
|----------------|-----------|-------------|
| {FIELDNAME} | {String/Double/DateTime/Boolean/Integer} | {What is this field} |
| {FIELDNAME} | {String/Double/DateTime/Boolean/Integer} | {What is this field} |

### Output Parameters
Data passed to child screens:

**To {ChildScreenName}**:
- {List of fields to pass}
- {Or "All DynamicFilters"}

---

## 4. Fields Definition ⭐

> List all fields that appear on the form. Use this table format:

| Field Name | Label | Type | Control | Width | Visible | ReadOnly | Mandatory | Default | Format | Image | Panel | Grid | Notes |
|------------|-------|------|---------|-------|---------|----------|-----------|---------|--------|-------|-------|------|-------|
| {FIELDNAME} | {Label} | String/Double/DateTime/Boolean | Entry/DatePicker/Combobox/Switch/Label | 4 or 8 | Y/N | Y/N | Y/N | {value or blank} | {n0/n2/d or blank} | {image name or blank} | Y/N/- | Y/N/- | {any special notes} |

> **Panel / Grid columns**: `Y` = include on that surface, `N` = exclude, `-` = leave NULL (included on whichever surface the display type requires). Only relevant for `PanelAndCardsGrid`; for `Panel`-only or `CardsGrid`-only screens you can leave both as `-`.

**Example**:
| Field Name | Label | Type | Control | Width | Visible | ReadOnly | Mandatory | Default | Format | Image | Panel | Grid | Notes |
|------------|-------|------|---------|-------|---------|----------|-----------|---------|--------|-------|-------|------|-------|
| PRODUCTCODE | Product Code | String | Entry | 8 | Y | N | N | | | | Y | N | Panel-only field |
| EXPECTEDQTY | Expected Qty | Double | Entry | 4 | Y | Y | N | | n0 | | N | Y | Card field with CaptionValue override |
| FROMDATE | From Date | DateTime | DatePicker | 4 | Y | N | N | | | | - | - | Both surfaces |
| STATUS | Status | String | Combobox | 8 | Y | N | N | | | | Y | Y | ValueList: STATUSLIST |
| ISACTIVE | Is Active | Boolean | Switch | 4 | Y | N | N | 1 | | | Y | N | |
| CONFIRMEDQTY | Confirmed Qty | Integer | Entry | 8 | Y | N | Y | | n0 | confirmedQty | - | - | Field with icon |
| DROPID | Drop Id | String | Entry | 8 | Y | N | Y | | | dropId | - | - | Field with icon |

### Control Type Guide:
- **Entry**: Text input (for String)
- **NumericEntry**: Number input (for Double/Integer) - automatically determined
- **DatePicker**: Date selection (for DateTime) - automatically determined
- **Switch**: Toggle (for Boolean) - automatically determined
- **Combobox**: Dropdown (for String with ValueList)
- **Label**: Text (for Unknown type)

### Override Control Types (via CONTROLTYPE in DATAPANELAPPEARANCEDEFINITION):
These override the auto-determined type. Set in `DATAPANELAPPEARANCEDEFINITION.CONTROLTYPE`:
- **ChipGroup**: Editable multi-select chip group (requires ValueList on the field)
- **Chip**: Display-only chip/badge (e.g., status indicator)
- **CaptionValue**: Framed box with caption label above a bound value label
- **InlineCaptionLabel**: Horizontal caption + value displayed side-by-side
- **Separator**: Thin horizontal line divider

> **Note**: If a field uses a control type override, add it to the "Control Type Overrides" table in Section 7b below.

---

## 5. Value Lists (Dropdowns)

> Only fill if you have Combobox fields

| List Name | Source Type | Source Table | Value Column | Display Column | Parent Filter | Searchable | Notes |
|-----------|-------------|--------------|--------------|----------------|---------------|------------|-------|
| {LISTNAME} | Table/ValueList | {TABLENAME} | {column} | {column} | {parent field or blank} | Y/N | {notes} |

**Example**:
| List Name | Source Type | Source Table | Value Column | Display Column | Parent Filter | Searchable | Notes |
|-----------|-------------|--------------|--------------|----------------|---------------|------------|-------|
| PRODUCTCODE | Table | PRODUCT | PRODUCTCODE | PRODUCTNAME | SUBCATEGORYCODE | Y | Filtered by subcategory |
| STATUSLIST | ValueList | VALUELIST | ITEMVALUE | DESCRIPTION | | N | Static status list |

**For cascading dropdowns**, specify parent filter field name.

---

## 6. Calculated/Derived Fields

> Only fill if you have fields calculated from other fields

| Field Name | Formula/Logic | When Calculated |
|------------|---------------|-----------------|
| {FIELDNAME} | {Formula or description} | On page load / On field change |

**Example**:
| Field Name | Formula/Logic | When Calculated |
|------------|---------------|-----------------|
| EXPECTEDAMOUNT | ExpectedQty × UnitPrice | On page load |
| REMAININGQTY | ExpectedQty - RegisteredQty | On page load |

---

## 7. Conditional Visibility/Behavior

> Only fill if fields show/hide or enable/disable based on conditions

| Field Name | Condition | Show/Hide | Enable/Disable | Notes |
|------------|-----------|-----------|----------------|-------|
| {FIELDNAME} | {When/if condition} | Show/Hide | Enable/Disable | {explanation} |

**Example**:
| Field Name | Condition | Show/Hide | Enable/Disable | Notes |
|------------|-----------|-----------|----------------|-------|
| TAGID | When ADDTOASSET checkbox is checked | Show | - | Only visible when adding to existing asset |
| CATALOG | When ADDTOASSET is unchecked AND CAPTURECATALOG=1 | Show | - | Hidden when adding to asset |

---

## 7b. Control Type Overrides

> Only fill if any fields need their auto-determined control type overridden (e.g., to use ChipGroup, Chip, CaptionValue, InlineCaptionLabel, or Separator)

| Field Name | Override ControlType | ControlParams | Notes |
|------------|---------------------|---------------|-------|
| {FIELDNAME} | ChipGroup/Chip/CaptionValue/InlineCaptionLabel/Separator | {semicolon-separated key='value' or blank} | {explanation} |

**Example**:
| Field Name | Override ControlType | ControlParams | Notes |
|------------|---------------------|---------------|-------|
| REQUESTKEY | InlineCaptionLabel | EntryStyleName='ThemeStyleNames.Label.ListSubDetailData' | Styled as sub-detail |
| EXPECTEDQTY | CaptionValue | | Framed caption+value |
| STATUSCODE | Chip | ConverterProfile='LineStatus' | Display-only status badge with color converters (ReadOnly must be N) |
| DIVIDER1 | Separator | | Line between sections |

**ControlParams Format**: Semicolon-separated `key='value'` pairs:
- `EntryStyleName='StyleName'` — Override the control's style
- `ConverterProfile='ProfileName'` — Chip converter profile for dynamic text/background/text-color (registered in `DILoader.cs`)

**⚠️ Chip + ReadOnly**: When using `Chip` override, the field's ReadOnly **must be N** (0 in DB). ReadOnly=1 causes DevExpress to force default styling, overriding converter color bindings.

---

## 8. Validation Rules

> Validation that should happen before button actions

### For Action: {ActionName} (e.g., Submit, Save, Search)

| Rule Name | Error Message | Condition to PASS | Notes |
|-----------|---------------|-------------------|-------|
| {RuleName} | "{Message to show user}" | {When validation passes} | {explanation} |

**Example**:

### For Action: Submit

| Rule Name | Error Message | Condition to PASS | Notes |
|-----------|---------------|-------------------|-------|
| QtyCheck | "Quantity must be greater than zero" | QTYTOREGISTER > 0 | Ensure qty is positive |
| CatalogRequired | "Catalog is required" | ADDTOASSET=1 OR CATALOG is not empty | Required unless adding to asset |

---

## 9. Button Actions ⭐

> For each button in Section 3

### Button: {Button Label}

| Property | Value |
|----------|-------|
| **Visible By Default** | Yes/No |
| **Conditional Visibility** | {When it shows/hides or "Always visible"} |
| **Validation** | {ActionName from section 8, or "None"} |
| **Action Type** | Navigation / Server Call / Both |

**If Navigation**:
- Navigate to: {TargetScreenName}
- Pass parameters: {List fields to pass or "All DynamicFilters"}

**If Server Call**:
- Business Process: {BPName}
- Method: {MethodName}
- Parameters: {List parameters to send}
- On Success: {What happens - navigate back, show message, etc.}

**Example**:

### Button: Search

| Property | Value |
|----------|-------|
| **Visible By Default** | Yes |
| **Conditional Visibility** | Always visible |
| **Validation** | None |
| **Action Type** | Server Call |

**Server Call**:
- Business Process: BVProductSummary
- Method: Refresh
- Parameters: All search filter fields from DynamicFilters
- On Success: Display results in grid

### Button: Start Registration

| Property | Value |
|----------|-------|
| **Visible By Default** | Yes |
| **Conditional Visibility** | Hidden when ADDTOASSET is checked |
| **Validation** | AssetRegistration |
| **Action Type** | Navigation |

**Navigation**:
- Navigate to: AssetRegistrationPage
- Pass parameters: All DynamicFilters

---

## 10. Business Logic

> Any special calculations, initialization logic, or custom behavior

### Initialization (on page load):
{Describe what happens when page appears}

**Example**:
```
1. Calculate ExpectedAmount = ExpectedQty × UnitPrice
2. Calculate RemainingQty = ExpectedQty - RegisteredQty
3. Set default values:
   - ALLOWOVERRECEIVE = 1
   - ADDTOASSETLABEL = "Add to assets"
```

### Special Behaviors:
{Describe any special UI behaviors, toggle logic, modal dialogs, etc.}

**Example**:
```
- Add To Asset Toggle:
  - When checked: Show "Add To Asset" button, hide "Start Registration" button
  - When unchecked: Show "Start Registration" button, hide "Add To Asset" button
  - If already added (flag=true): Disable toggle to prevent unchecking

- Product Edit Button:
  - Display edit icon next to product fields
  - On tap: Open ProductLookupPage as modal
  - On return: Update product classification fields
```

---

## 11. Grid Configuration (if Section 4 checked)

### Grid Columns:

| Column Name | Binding Field | Label | Type | Has Command |
|-------------|---------------|-------|------|-------------|
| {Column} | {FIELDNAME} | "{Label}" | Data/Command | Y/N |

**Example**:
| Column Name | Binding Field | Label | Type | Has Command |
|-------------|---------------|-------|------|-------------|
| Actions | PRODUCTKEY | "More Info" | Command | Y |
| ProductCode | PRODUCTCODE | "Product Code" | Data | N |
| ProductName | PRODUCTNAME | "Product Name" | Data | N |

**Command Action** (if any command columns):
- On click: {What happens - navigate to details, open modal, etc.}

---

## 11b. Cards Grid Configuration (if Section 5 / CardsGrid checked)

> Fill this if Display Type is `CardsGrid` or `PanelAndCardsGrid`.

| Property | Value |
|----------|-------|
| **Items source binding** | {ViewModel property, e.g. `Rows`} |
| **Tap action** | {Navigate to detail / None} |
| **Empty text** | {e.g. "No items found."} |
| **Show accent bar** | Y/N |
| **Accent color** | {hex or "default"} |

Card fields come from `DATADISPLAYDATADEFINITION` rows where `GRIDINCLUDE = 1`. Their **control type** is set via `DATAPANELAPPEARANCEDEFINITION.CONTROLTYPE` (e.g. Chip, CaptionValue, InlineCaptionLabel, Separator).

**Card-specific field overrides** (optional — only needed when card label/sequence/visibility should differ from panel):

| Field Name | Grid Sequence | Grid Description | Grid Visible | Grid Width | Notes |
|------------|---------------|------------------|--------------|------------|-------|
| {FIELDNAME} | {int or blank} | {label or blank} | {Y/N or blank} | {4/8 or blank} | {notes} |

---

## 12. Special Notes

> Any additional information, edge cases, or implementation notes

{Write any special considerations here}

**Example**:
```
- Once an asset is added via "Add To Asset", the toggle cannot be unchecked on return
- Product reclassification is allowed via edit button
- System checks ALLOWQUANTITYOVERRECEIVE flag to allow registering more than remaining
```

---

## 13. Test Scenarios (Optional but Recommended)

### Scenario 1: {Scenario Name}
**Steps**:
1. {Step 1}
2. {Step 2}
3. {Step 3}

**Expected Result**: {What should happen}

### Scenario 2: {Scenario Name}
**Steps**:
1. {Step 1}
2. {Step 2}

**Expected Result**: {What should happen}

---

## Template Version
**Version**: 1.0
**Last Updated**: 2025

---

## Quick Checklist

Before submitting this specification, ensure:

- [ ] Screen name and basic information filled
- [ ] All form fields listed with types and properties
- [ ] Value lists defined for all Combobox fields
- [ ] Button actions clearly described
- [ ] Validation rules specified
- [ ] Navigation parameters (input/output) documented
- [ ] Special behaviors or business logic explained
- [ ] Any conditional visibility rules documented

---

## Example: Complete Simple Specification

Here's a complete example for reference:

### 1. Basic Information
- **Screen Name**: ProductSearchPage
- **Screen Title**: "Product Search"
- **Screen Profile Code**: PSP
- **Feature Area**: product
- **Parent Screen**: None (root screen)
- **Purpose**: Search for products by code, name, or category

### 2. Screen Layout
- [x] Section 1: Form Fields
- [ ] Section 2: Attributes Grid
- [x] Section 3: Action Buttons
  1. Search - Executes search and displays results
- [x] Section 4: Data Grid
  - Product Code, Product Name, Category

### 3. Fields Definition
| Field Name | Label | Type | Control | Width | Visible | ReadOnly | Mandatory | Default | Format | Image |
|------------|-------|------|---------|-------|---------|----------|-----------|---------|--------|-------|
| PRODUCTCODE | Product Code | String | Entry | 8 | Y | N | N | | | |
| PRODUCTNAME | Product Name | String | Entry | 8 | Y | N | N | | | |
| CATEGORYCODE | Category | String | Combobox | 8 | Y | N | N | | | |

### 5. Value Lists
| List Name | Source Type | Source Table | Value Column | Display Column | Searchable |
|-----------|-------------|--------------|--------------|----------------|------------|
| PRODUCTCATEGORY | Table | PRODUCTCATEGORY | CATEGORYCODE | CATEGORYNAME | Y |

### 9. Button Actions

#### Button: Search
- **Visible**: Always
- **Validation**: None
- **Action**: Server Call
  - BP: BVProductSummary
  - Method: Refresh
  - Parameters: All filter fields
  - On Success: Display in grid

### 11. Grid Configuration
| Column Name | Binding Field | Label |
|-------------|---------------|-------|
| ProductCode | PRODUCTCODE | "Product Code" |
| ProductName | PRODUCTNAME | "Product Name" |
| Category | CATEGORYCODE | "Category" |

---

That's it! Fill out this template and provide it for screen generation.
