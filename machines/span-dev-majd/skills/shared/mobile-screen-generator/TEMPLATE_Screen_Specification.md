# Screen specification: {Name}Page

> One file per page. Sections marked ⭐ are required; delete sections that don't apply. Write facts, not intentions: every field name is the exact name the server reads, every message is the exact text.
>
> **Server calls**, wherever they happen (button, page load, back, row move), are written as a Call block:
>
> ```
> Call {C1}: {BP}.{Method}({argument list as the method declares it, e.g. "filters" or "constraints, parameters"})
> | Filter | Type | Value | Sent when |
> | {name the BP reads} | {String/Decimal/...} | {field X / constant "1" / row column Y} | {always / only when <condition>, e.g. the field has a value, the reason allows a target change} |
> Sends: only these filters | all page fields plus these
> Result: {Tables[0] -> grid / ignored / ...}
> On error: {show the server message / ...}
> ```
>
> Other sections refer to a call by its id (C1, C2, ...). Put the blocks in section 9a.

## 1. Basic information ⭐

| Property | Value |
| --- | --- |
| Page | `{Name}Page` |
| Title | "{shown in the header}" |
| Screen profile code | {short code, unique in the project} |
| Feature folder | {e.g. receive} |
| Route | `//Main/Operation/{Root}/.../{Name}` |
| Menu entry | {root pages: menu text, parent menu, icon, sequence; else "None"} |
| Display type | Panel / CardsGrid / PanelAndCardsGrid |
| Purpose | {one sentence} |

## 2. Layout ⭐

Top to bottom:

- [ ] Form fields (metadata)
- [ ] Tabs (fill 2a)
- [ ] Entity attributes: table `{ENTITYATTR table}`, shown {in tab X / below the form}
- [ ] Buttons (section 9)
- [ ] Data grid (section 11)
- [ ] Cards grid (section 11b)
- [ ] Row navigation `<` `>` (section 10a)

### 2a. Tabs

| Order | Header | Contents | Group name (`DATAGROUPNAME`) | Page switches to it |
| --- | --- | --- | --- | --- |
| 1 | {Main} | {fields} | {NameMain} | {on load / after each row move} |
| 2 | {Attrs} | {entity attributes} | — | — |
| 3 | {Items} | {data grid} | — | {when ...} |

Every tab stays in the tab view (a mobile TabView can't hide one; see REFERENCE.md, Tabs and groups). For a tab legacy showed only when needed, give the condition in the last column and say in 9a when its fields are sent.

## 3. Navigation ⭐

**Comes from**: {page, and on what action} with:

| Parameter | Type | Meaning |
| --- | --- | --- |
| {FIELD} | {String/Decimal/...} | {...} |

**Goes to**:

| Target | When | Passes |
| --- | --- | --- |
| {Page} | {button / row tap / after confirm} | {fields, or "all DynamicFilters", or "selected row"} |

**Back**: {plain back / runs logic: prompt ..., then call C? / hidden (root)}

## 4. Fields ⭐

| Field | Label | Type | Control | Group | Width | Visible | ReadOnly | Mandatory | Default | Format | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {FIELD} | {Label} | String / Integer / Decimal / DateTime / Boolean / Unknown | Entry / Combobox / Switch / DatePicker / Label | {group} | 4 / 8 | Y/N | Y/N | Y/N | | | {value list, legacy name, scan behaviour} |

Control follows from Type: a value list makes a Combobox, DateTime a DatePicker, Boolean a Switch, numbers a numeric entry, `Unknown` a Label (or use a 7b override).

On a PanelAndCardsGrid page add `Panel` and `Grid` columns (Y / N / -).

## 5. Value lists

| List | Source table | Value column | Display column | Constraints | Parent field | Blank item | Searchable |
| --- | --- | --- | --- | --- | --- | --- | --- |
| {LIST} | {TABLE or VALUELIST} | {col} | {col} | {e.g. TYPENAME/LISTNAME} | {field or blank} | Y/N | Y/N |

## 6. Derived fields

| Field | Formula | When |
| --- | --- | --- |
| {FIELD} | {...} | page load / on change of X |

## 7. Conditional state

| Field | Condition | Visible | Enabled | ReadOnly |
| --- | --- | --- | --- | --- |
| {FIELD} | {when ...} | Y/N/- | Y/N/- | Y/N/- |

### 7b. Control type overrides

| Field | Control type | Params |
| --- | --- | --- |
| {FIELD} | Chip / ChipGroup / CaptionValue / InlineCaptionLabel / Separator | {key='value'; ...} |

## 8. Validation

| Action | Rule | Passes when | Message |
| --- | --- | --- | --- |
| {Confirm} | {QtyPositive} | {QTY > 0} | "{exact text}" |

Mandatory fields (section 4) are checked automatically; don't repeat them here.

### 8a. Prompts

| When | Kind | Title | Message | Yes / OK | No |
| --- | --- | --- | --- | --- | --- |
| {before Confirm, if X} | Confirm / Info | "{...}" | "{...}" | {continue} | {stop} |

## 9. Buttons ⭐

### Button: {Label}

| Property | Value |
| --- | --- |
| Visible | {always / when ...} |
| Validation | {action name from section 8, or none} |
| Prompts | {from 8a, or none} |
| Does | {calls C1, C2 in order, then navigation / message / clear} |
| On success | {...} |

### 9a. Server calls

{Call blocks C1, C2, ... in the format at the top of this file.}

## 10. Behaviour

**On page load**: {calls C?, defaults, pre-fills, focus}

**Other**: {field events, scan handling (Enter on a field), anything not covered above}

### 10a. Row navigation

| Property | Value |
| --- | --- |
| Rows | {where they come from} |
| Form shows | the current row |
| `<` / `>` | {enabled when a previous / next row exists} |
| `<<` / `>>` | {first / last row, if the legacy navigator had them; else delete this row} |
| On each move | {e.g. set the task in progress: call C?} |
| After a successful confirm | {remove the row and show the next (previous if last)} |
| When no rows are left | {go back to ... / message "..."} |

## 11. Data grid

| Column | Field | Caption | Type |
| --- | --- | --- | --- |
| {1} | {FIELD} | "{Caption}" | Data / Decimal / Command |

Row tap: {navigate to ... with ... / none}. Shown: {always / after a search}.

### 11b. Cards grid

| Property | Value |
| --- | --- |
| Items source | {ViewModel property} |
| Tap | {...} |
| Empty text | "{...}" |

Card fields are the section 4 fields with `Grid` = Y.

## 12. Notes

{Anything else the generator must know: decisions made, known server behaviour, things deliberately left out.}

## 13. Test scenarios

1. {Steps} -> {expected result}
