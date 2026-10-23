# Mobile screen reference

Framework facts for generating a screen on the SPAN .NET MAUI mobile framework (`client.mobile`, in rndfwcore). Templates use `{App}` for the app's root namespace (the csproj `RootNamespace`, e.g. `client.mobile.itms`) and `{Feature}` for the feature folder. **The target project's existing code wins over anything here**: SKILL.md step 0 says what to look up.

## How a page is built

On `OnAppearing`, `BaseContentPage` (`pages/basepages/BaseContentPage.cs`):

1. The first time only: `BuildPageLayout()` (your static layout). It never runs again for that page instance.
2. Every time: `BeforeOnAppearing()`, outside the busy overlay. Use it to reset state (tab index, grid selection).
3. Then, all inside one `IsBusyFor` (busy overlay on):
   1. `Controller.InitializeAsync()`. **Server calls on page load go here.**
   2. Loads metadata by the page name (`nameof(Page)`): `DATADISPLAYDEFINITION`, `DATADISPLAYDATADEFINITION`, entity attributes if `EntityDefTableName` is set, then `CONTROLTYPE`/`CONTROLPARAMS` overrides.
   3. Builds the field controls into `DataDisplayDataDefParentContainer`, grouped by `DATAGROUPNAME` (see Tabs and groups), adds a filter for every field missing from the bound collection, and binds each control to `{DataDisplayDataDefBindingPath}[FIELD].Value` (default `DynamicFilters`). Comboboxes load their lists.
   4. Builds the cards grid if the display type includes one.
   5. Applies `DATAPANELAPPEARANCEDEFINITION` conditions and subscribes to the ViewModel's `PropertyChanged` to re-apply them (only if the screen has a conditional row; see Row navigation for the catch).
   6. `AfterOnAppearing()`: **synchronous `void`, still under the overlay**. Hook control events here (`-=` before `+=`, since it runs on every appearance). Don't prompt the user here, and don't start server calls from it unless you follow `PickDetailsPage.AfterOnAppearing` in rnditmscore (`async void` override with a try/catch around everything that shows `ShowErrorAsModalAsync`; an exception escaping an `async void` kills the app).

If the container named by `DataDisplayDataDefParentContainer` (or a group's container) isn't in the layout, the fields are silently not built.

## Files of one screen

| File | Path |
| --- | --- |
| Metadata SQL | `pages/{Feature}/screens-defs-{Name}Page.sql` |
| ViewModel | the project's models folder (flat `models/` or `models/{Feature}/`) |
| Controller | `pages/{Feature}/{Name}PageController.cs` |
| Page | `pages/{Feature}/{Name}Page.cs` |
| Constants | `constants/`: `ScreenNames`, plus whatever else the project keeps there (`PageNames`, `ControllerNames`, `MethodNames`, `BPNames`, `ModelFields.{Feature}.cs`) |
| DI registration | `engines/DILoader.cs` |
| Route | `AppController.cs` |
| Menu entry (root screens) | SQL, see Menu |

## SQL metadata

All tables are in the `master` schema. **Write the script the way the project's existing `screens-defs-*.sql` files are written** (re-run guards, schema prefix or not, value-list style). The column lists below are the reference, not the format. One exception: every row this skill writes sets `CREATEDBY` to `'AIGenerated'` (with `CREATEDDATE` = the dialect's current date), whatever value the existing scripts use, so generated metadata can be told apart from hand-written rows.

### DATADISPLAYDEFINITION (one row per screen, required)

| Column | Value |
| --- | --- |
| `DATADISPLAYNAME` | `{Name}Page`, equal to `nameof(Page)` |
| `DATADISPLAYTYPE` | `Panel` (form), `CardsGrid` (card list), `PanelAndCardsGrid` (both) |

Without it, no cards grid is ever built.

### DATADISPLAYDATADEFINITION (one row per field)

| Column | Meaning |
| --- | --- |
| `DATADISPLAYNAME` | page name |
| `SCREENPROFILENAME` | short screen code, unique in the project (check existing scripts) |
| `DATANAME` | field name: the filter name the server receives |
| `DATADESCRIPTION` | label |
| `DATAGROUPNAME` | group: a tab, an expander or a named container (see Tabs and groups) |
| `SEQUENCE` | order (groups are ordered by their lowest sequence) |
| `DATATYPE` | `String`, `Integer`, `Double`, `Decimal`, `DateTime`, `Boolean`, `Unknown` |
| `WIDTH` | columns out of 8: `4` half, `8` full |
| `ISVISIBLE` / `ISREADONLY` / `ISMANDATORY` | `1`/`0`. `ISREADONLY` on a text, numeric, combo or date field sets the editor's `IsReadOnly`: grey fill, no typing, but its end icon (a lookup) still works. Check boxes, switches and chip groups are disabled instead. |
| `FILTERTYPE` | `Value`, or `List` for a combobox |
| `FILTERCOMPARISONTYPE` | `Equal`, `Like`, `GreaterOrEqual`, `LessOrEqual`, `Range`, ... |
| `FILTERDEFAULTVALUES` | default value or NULL |
| `VALUELISTDEFINITION` | value list name for a combobox, else NULL |
| `DATAFORMAT` | `n0`, `n2`, `d`, ... or NULL |
| `IMAGENAME` | field icon or NULL |
| `PANELINCLUDE` / `GRIDINCLUDE` | which surface on `PanelAndCardsGrid`: `1` include; both NULL = whichever the display type needs; only the sibling set = excluded here |
| `GRIDCAPTION`, `GRIDISVISIBLE`, `GRIDSEQUENCE`, `GRIDGROUPNAME` | card overrides (`GRIDWIDTH` is not read by mobile) |

Control type from the row: value list -> Combobox; `DateTime` -> DatePicker; `Boolean` -> Switch (there is no metadata CheckBox); numeric -> NumericEntry; `Unknown` -> Label; else Entry.

### DATADISPLAYVALUELISTDEFINITION (one row per combobox list)

| Column | Meaning |
| --- | --- |
| `VALUELISTDEFINITION` | list name |
| `TABLENAME`, `VALUECOLUMNNAME`, `DISPLAYCOLUMNNAME` | source table and columns |
| `CONSTRAINTS` | filter on the source; syntax depends on the BP that serves the list, so copy an existing list in the project that uses the same BP |
| `BPNAME`, `METHODNAME` | BP that serves the list |
| `PARENTVALUESOURCE`, `PARENTVALUECOLUMNNAME` | cascading: parent field and the source column it filters |
| `ADDBLANKITEM`, `ISSEARCHABLE` | `1`/`0` |

The mobile client doesn't read `SELECTFIRST`, `SELECTIFSINGLE` or `PRELOAD`; leave them as the project's existing rows do.

Reuse an existing list when one already serves the same data.

### DATAPANELAPPEARANCEDEFINITION (conditional state and control overrides)

| Column | Meaning |
| --- | --- |
| `DATADISPLAYNAME`, `CONTROLNAME` | page and field (`DATANAME`, not the prefixed entry name) |
| `SEQUENCE` | evaluation order; later rows win |
| `CONDITION` | expression, or NULL for always |
| `VISIBLE`, `ENABLED`, `READONLY` | state while the condition holds |
| `APPEARANCENAME` | `DefaultAppearance` |
| `CONTROLTYPE` | override: `ChipGroup` (editable multi-select, needs a value list), `Chip` (display-only badge), `CaptionValue`, `InlineCaptionLabel`, `Separator`, `CheckBox`, `Password` |
| `CONTROLPARAMS` | `key='value'` pairs separated by `;`: `EntryStyleName='...'`, `ConverterProfile='...'` (a `ChipConverterRegistry` profile registered in DILoader) |

A `Chip` must have `READONLY` 0 here and `ISREADONLY` 0 on the field: read-only disables a chip group, which greys out its colours.

Overrides worth knowing:

- A Boolean field is a `Switch` by default, and a Switch shows **no caption**. For a labelled checkbox ("Location Full") add a `CheckBox` override: it shows the field's description beside the box.
- A `Separator` is a bare line, also with no caption. For a section heading ("Confirm", "Target") use an `Unknown` field with an `InlineCaptionLabel` override.
- `Password` masks a String field.

`DQDataPanelControlAppearanceCRUD` inner-joins `master.DATAAPPEARANCEDEFINITION` on `APPEARANCENAME`, so a database without the `DefaultAppearance` row there silently ignores every row of this table. After applying a script with overrides, check they come back: `BPDataPanelControlAppearanceCRUD.Refresh` with `DataDisplayName` = the page (the BP test client can call it). rnditmscore's `database/07-shared-db-master-fixes.sql` adds the row.

### DATADISPLAYVALIDATIONDEF (rules checked before an action)

| Column | Meaning |
| --- | --- |
| `DATADISPLAYNAME`, `ACTIONNAME`, `SEQUENCE` | page, the action name passed to `ValidateThenRunAsync`, order |
| `VALIDATIONNAME` | rule name |
| `VALIDATIONTYPE` | not read by mobile; fill it as the project's existing rows do (`Condition`) |
| `VALIDATIONMESSAGE` | shown when the rule fails |
| `EXPRESSION` | must be **true to pass** |

Mandatory fields need no rule: a visible field with `ISMANDATORY = 1` and no value already fails validation with "<Label> is required.".

### Expressions

`~FIELD~` reads a field. Operators `= != > < >= <=`, `&&`, `||`, function `isemptyornull(~FIELD~)`. Example: `~ADDTOASSET~=1||isemptyornull(~CATALOG~)=false`.

### Menu

A root screen also needs a menu row. In the apps seen so far it is `master.SCREENPROFILEMENU` (`SCREENPROFILENAME`, `MENUNAME`, `PARENTMENUNAME`, `MENUTEXT`, `IMAGENAME`, `SEQUENCE`, `SCREENNAME`, `APPLICATIONID = 'MOBILE'`, `ISACTIVE`), where `SCREENNAME` is the route segment (`ScreenNames.X`). Find how the project inserts its existing menu rows and do the same.

## Code templates

Write each file in the style of the project's nearest existing page; these show the required parts.

### Constants

```csharp
// constants/ScreenNames.cs: one per route segment
public const string {Name} = "{Name}";
// constants/ModelFields.{Feature}.cs: field names, if the project uses ModelFields
public static partial class ModelFields
{
    public static class {Feature}
    {
        public const string {FIELD} = "{FIELD}";
    }
}
```

Add `PageNames`, `ControllerNames`, `MethodNames`, `BPNames` entries only if the project has those files and its DI or controllers use them.

### ViewModel

Base class: `GridViewModel` if the page shows a data grid (`DataRows`, `SetModelData(DataTable)`), else `DynamicViewModel` (`DynamicFilters`). Add `[QueryProperty(nameof(DynamicFilters), "DynamicFilters")]` when it receives navigation parameters, and `I_ContextDataExtractor` when it passes data on.

```csharp
namespace {App}.models
{
    /// <summary>{Purpose}</summary>
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]
    public class {Name}ViewModel : DynamicViewModel, I_ContextDataExtractor
    {
        // Only properties the spec needs. Notify on set:
        // public int Count { get => count; set { count = value; OnPropertyChanged(nameof(Count)); } }
    }
}
```

### Controller

```csharp
namespace {App}.pages.{Feature}
{
    /// <summary>{Purpose}</summary>
    public class {Name}PageController(I_NavigationService NavigationService) : BaseController(NavigationService)
    {
        internal {Name}ViewModel {Name}Model = new();
        public override BaseViewModel ViewModel => this.{Name}Model;

        // Only when there is something to initialize. No Task.Delay.
        public override Task InitializeAsync()
        {
            AddOrReplaceFilter({Feature}.{FIELD}, DataType.String, this.{Name}Model.DynamicFilters, "{default}");
            return Task.CompletedTask;
        }

        // One per button or server action.
        internal async Task<Result> Call{Action}Async()
        {
            Result result = Result.Success();
            await IsBusyFor(async () =>
            {
                try
                {
                    // Arguments = the BP method's own parameters (see Server calls).
                    DataSet ds = await mobile.factory.ModelIO.Instance.ExecuteActionAsync<DataSet>(
                        "{BP}", "{Method}", Build{Action}Filters());
                    // use the result as the spec says
                }
                catch (Exception ex)
                {
                    result = Result.Failure(ex.Message, ErrorType.SystemError);
                }
            });
            return result;
        }

        internal Task GoTo{Target}Async() =>
            IsBusyFor(() => this.NavigationService.NavigateToAsync(
                $"//Main/Operation/{ScreenNames.{Parent}}/{ScreenNames.{Target}}",
                new Dictionary<string, object> { { nameof({Target}ViewModel.DynamicFilters), this.{Name}Model.DynamicFilters } }));
    }
}
```

The BP and method names are passed the way the project's controllers pass them (constants or literals).

### Page

```csharp
namespace {App}.pages.{Feature}
{
    /// <summary>{Purpose}. Layout: {sections}.</summary>
    public class {Name}Page : BaseContentPage
    {
        protected {Name}PageController {Name}PageController => ({Name}PageController)this.BaseController;

        public {Name}Page({Name}PageController {Name}PageController)
            : base({Name}PageController, "{Title}", nameof({Name}Page))
        {
            // HideShellBackButton();          root screens
            // SetBackAction(OnBackAsync);     back that must run logic (toolbar and hardware back)
        }

        protected override IView BuildPageLayout()
        {
            UIGrid content = new()
            {
                RowDefinitions =
                {
                    new RowDefinition { Height = GridLength.Star },  // form (Auto when a grid follows)
                    new RowDefinition { Height = GridLength.Auto },  // buttons
                }
            };
            content.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);
            content.Add(BuildActionsGridLayout(), 0, 1);
            return content;
        }

        private UIGrid BuildActionsGridLayout()
        {
            UIButton btn = UIButtonBuilderHelper.BuildButton("{Action}Btn", "{Label}", string.Empty, string.Empty);
            btn.Clicked += async (s, e) => await ValidateThenRunAsync("{Action}", {Name}PageController.Call{Action}Async);
            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(btn, LayoutOptions.End);
        }
    }
}
```

`UIButtonBuilderHelper.BuildButton` translates its caption; don't wrap it in `GlobalizationHelper`. Several buttons: `ActionGridBuilderHelper.BuildHorizontalButtonActionGrid(...)` / `BuildVerticalButtonActionGrid(...)`, or a `UIGrid` with columns as the existing pages do.

A bottom bar with icons and roles (rndfwcore dev since October 2026): `UIButtonBuilderHelper.BuildActionButton(name, caption, ButtonRole.Primary | Secondary | Alternate, iconFile)` per button, then `ActionGridBuilderHelper.BuildActionBar(buttons)` in role order Secondary, Alternate, Primary. The bar uses equal columns with an `ActionGap` (8dp) and the page gutter, and three buttons get a smaller font so labels fit at 360dp. `UIButtonBuilderHelper.SetIcon(button, iconFile)` puts a 16dp image left of any button's caption, tinted with its text colour (draw the SVG in black). `BuildButton`'s own `IconName` takes a framework PNG instead.

### DI and route

Copy the existing lines in `engines/DILoader.cs` and `AppController.cs` exactly (some apps resolve types by `nameof(...)`, others by `PageNames`/`ControllerNames` constants):

```csharp
Builder.Services.AddTransient(typeof({Name}PageController), Factory.ClientLocator.GetType(<as the file does>));
Builder.Services.AddTransient(typeof({Name}Page), Factory.ClientLocator.GetType(<as the file does>));

Routing.RegisterRoute($"//Main/Operation/{ScreenNames.{Root}}/{ScreenNames.{Name}}", typeof({Name}Page));
```

The route is the screen's path from its menu root. Every page in the path needs its own route.

## Patterns

### Actions

- With validation rules: `await ValidateThenRunAsync("{Action}", controller.Call{Action}Async)`. It validates, shows errors, runs the call under the busy overlay and shows the error modal on failure.
- Without: `await RunControllerActionAsync(controller.Call{Action}Async)`.
- Hand-write a handler only when the flow branches between validation and the call (a confirmation prompt, a success message, several outcomes). Then use `ValidatePageAsync("{Action}")` + `DisplayValidationErrorsAsync(result)`.

### Side margins

Inset every block that sits on the page background (banner, `UIFormCard`, stat strips, tab views, grids, a lone button, the action bar) by `ThemeConstants.Spacing.PageGutter` (12dp) at both sides, so their edges line up; `ThemeConstants.Spacing.PageMargin(top, bottom)` builds that margin, and `UIFormCard` already has it. A block inside a card or tab gets no side margin: its container insets it. `DataGridConfiguration.Margin` is one number for all sides, so set it to 0 and give the grid a `Thickness` afterwards. A `UIStackLayout` that only stacks blocks needs `Padding = 0`, because the theme pads every stack by 3dp.

### Shared layout pieces live in the framework

Don't add a per-flow or per-app layout helper (a `PVLayoutHelper`, a `{Flow}Ui`): anything another screen could use goes to rndfwcore. A component goes in `client.mobile.controls/controls` as a `UI*` control that implements `I_UIControl` (or `I_UIParentControl`). A builder goes in `client.mobile/helpers` (`UIButtonBuilderHelper`, `ActionGridBuilderHelper`), and a size or spacing number in `ThemeConstants`. Make the change in the rndfwcore repo on its own branch and PR, never under an app's `BUILD/baseruntime`; the app builds against it from rndfwcore's `BUILD\RUNTIME\dllsndroid` until a new base runtime is published. The app keeps only what is its own: icon file names in `constants/AppIcons`, colours in `constants/AppColors`.

Framework pieces for this (rndfwcore dev since October 2026):
- `UIStatStrip(name, params UIStat[])`: a white card with stats side by side, split by hairlines, and no margin of its own. `new UIStat(title, valuePath, UIStatTone, progressPath?)` binds the number to the view model, with an optional 0..1 bar. Tones: Neutral, Success (always green), and Warning and Alert (amber and red, only above zero).
- `UIBoundLabel`: use it for text that comes from a binding. The page globalizes every `UILabel` on load by writing its Text back, which replaces the binding. Translate bound text at its source.

### Instructions banner

In apps whose base page has `Instructions` (S4Assets `ExtendedBaseContentPage`), a page sets its banner hint by overriding it, never by writing `InstructionsLabel.Text`: `protected override string Instructions => "...";` in English (the base translates it). The banner shows it when built and on every appearance. When the hint depends on state (a ticket loaded, a location resolved, the selected tab), return it from that state and call `RefreshInstructions()` when the state changes.

### Load errors

Let `InitializeAsync` throw. The base page goes back to the previous page and shows the error, so don't catch a load failure to show it later from the page.

### Editors are rebuilt on every appearance

`BaseContentPage.OnAppearing` removes the metadata editors and builds new ones, but the old editors stay alive. Don't bind an editor property to a view model that outlives the page; a replaced editor still bound to it lays out its disposed native view when the value changes, and the app crashes. Set the property on the current editor (`GetControl(...)`) when the value changes instead. A `TextChanged` handler also fires when a removed editor blanks its text, so ignore senders whose `BindingContext` is null.

### Server calls with exact filters

`ModelIO.Instance.ExecuteActionAsync<T>(bp, method, params object[] args)` passes `args` straight to the BP method, so send exactly what that method declares: a BL `Execute(filters)` takes one collection, a CRUD `Get`/`Refresh(constraints, parameters)` takes two. Check the method in the logic project when the spec doesn't say.

The server reads filters by name, and a misnamed filter is silently ignored.

When the call takes the page's own fields, send `DynamicFilters` as it is; it holds exactly the fields the SQL defines, so listing them by name (`ExtractFilters(DynamicFilters, [12 names])`) only repeats the SQL. Add the spec's constants on a copy so the page's fields stay untouched (`RemoveNullOrEmptyFilters` and `Clone()` both return one):

```csharp
XalIndexedObjectCollection<Filter> filters = FiltersHelper.RemoveNullOrEmptyFilters(this.{Name}Model.DynamicFilters);
filters.AddOrReplace(Filter.GetValueFilter("TaskType", DataType.String, "Move"));   // constant from the spec
```

Pick fields by name only when the page holds fields that must not reach the server, or when the server's names differ from the page's:

```csharp
private XalIndexedObjectCollection<Filter> Build{Action}Filters()
{
    XalIndexedObjectCollection<Filter> f = [];
    f.AddOrReplace(Filter.GetValueFilter("LocationCode", DataType.String, FiltersHelper.GetString(Model.DynamicFilters, Move.LOCATIONCODE)));
    f.AddOrReplace(Filter.GetValueFilter("UOMConvertion", DataType.String, "1"));   // constant from the spec
    return f;
}
```

`FiltersHelper` (rndfwcore `shared.helpers`) has `GetString`, `ExistsWithText`, `IsEmptyOrNull`, `ExtractFilters(DataRow | filters, columns)`, `MergeFilters`, `ExcludeFilters`, `RemoveNullOrEmptyFilters`, `AddValueConstraintIfSet`, `AddDateRangeConstraintIfSet`, `ClearValue`, `SetValue`. A filter's runtime value type must match its declared `DataType` (the framework throws otherwise).

**Setting a page field from code** (a lookup result, a server row, a computed text): use `FiltersHelper.SetValue(this.{Name}Model.DynamicFilters, {Feature}.{FIELD}, DataType.String, value)`. It sets the value on the existing filter and adds one only when the page hasn't built that field. `AddOrReplace` / `AddOrReplaceFilter` swap in a new `Filter`, so the control bound to the old one stops updating and appearance rules stop firing. Keep `AddOrReplace` for building a fresh collection to send to the server, and for initial defaults in `InitializeAsync`. Don't write a private "set it if it exists, otherwise add it" helper; a one-line wrapper over `FiltersHelper.SetValue` is fine when a controller sets many fields.

### Prompts and messages

`client.mobile.factory.Factory.MessageDisplayService`:

- `await ConfirmAsync(title, message, "Yes", "No")` returns `bool`. Ask in the page's button handler before calling the controller action, never inside an `IsBusyFor` scope or `AfterOnAppearing`.
- `await ShowMessageAsync(title, message)` for information. Inside an `IsBusyFor` scope, fire and forget (`_ = ...`) so the alert doesn't hold the overlay.
- `await this.DisplaySnackbar(text)` (page) for a short success note.

### Tabs and groups

`DATAGROUPNAME` places each field group. For each group the framework looks, in order, for:

1. A control in the page named exactly like the group: the fields go into it. Use this to fix a tab's header text, order or mixed content.
2. Otherwise, if `DataDisplayDataDefParentContainer` is a `UITabView`: a new tab is added with the group name as its header.
3. Otherwise: a group with an empty name, or the only group, goes straight into the container; other groups each get a collapsible expander.

So a tabbed screen sets `this.DataDisplayDataDefParentContainer = "<TabViewName>"` in the constructor and builds the tab view in `BuildPageLayout()`:

```csharp
TabView = UITabViewBuilderHelper.BuildTabView(ControlName: TabViewName);
TabView.Items.Add(new UITabitem
{
    HeaderText = "Main",
    Content = new UIScrollView { Content = new UIGrid("{Name}Main"), VerticalOptions = LayoutOptions.Start },
});
// DATAGROUPNAME = '{Name}Main' for that tab's fields. A tab can instead hold a data grid
// or the attributes container. Reset TabView.SelectedItemIndex = 0 in BeforeOnAppearing.
```

Tabs that legacy showed only when needed (Change Info, Supervisor) **stay in the TabView**; the page switches to them and decides from its own state whether their fields are sent. What doesn't work, all found on MoveTaskConfirmPage (Android):

- `UITabitem.IsVisible` (the `I_UIControl` member) throws `NotImplementedException`, and `TabView` sets every item's `VisualElement.IsVisible` itself (only the selected tab is visible), so a tab can't be hidden.
- Removing a tab from `TabView.Items` and adding it back drops its content's inherited `BindingContext`: its fields neither show nor write the bound values (re-assigning `Content.BindingContext` fixes that part only).
- Setting `SelectedItemIndex` across several tabs in one go (General to the fifth tab) left a skipped tab's page laid over the left half of the target tab, swallowing taps there. That was the DevExpress `TabView`; the in-house one collapses unselected tabs, so recheck on the device before working around it.

So change tabs in code one index at a time, and don't record the "previous tab" for a Back button while stepping (`TaskMoveConfirmPage.SelectTab`).

### Entity attributes

Set in the page constructor: `EntityDefTableName = "<ENTITYATTR table>"`, `EntityDefParentContainer = "<container name>"` (often a `UIStackLayout` inside a tab), and `EntityDefBindingPath` when the form isn't bound to `DynamicFilters`. The attribute fields then bind like normal fields.

### Row navigation (previous / next over a list)

Used when a page works through rows one at a time (confirm each line or task). There is no framework component; the pattern in use:

- The ViewModel holds the rows (`DataTable`) and the current index, and exposes the current row as `XalIndexedObjectCollection<Filter>` (`Current{Row}`, raising `OnPropertyChanged`) built from the row with `FiltersHelper.ExtractFilters(row)`.
- **Types**: extracted filters carry the SQL column's type, and the framework only fixes up DateTime. Where the spec's field Type differs from the column's (a number stored as nvarchar, say), `AddOrReplace` a filter of the spec's type with the converted value, or editing the field throws "declared as A but the value is B". Add empty filters for spec fields the row doesn't have (see `ReceiveDetailsViewModel` in rnditmscore).
- **Appearance rules**: they re-apply on the ViewModel's `PropertyChanged`. `DynamicViewModel` raises it when a `DynamicFilters` value changes, but a `Current{Row}` collection doesn't. If the page has section 7 rules, subscribe to each filter's `PropertyChanged` when setting `Current{Row}` and raise `OnPropertyChanged(nameof(Current{Row}))`.
- The page binds the form to it: `this.DataDisplayDataDefBindingPath = nameof(...ViewModel.Current{Row})` (and `EntityDefBindingPath` if attributes are shown).
- The controller exposes `CanGetNextRow()`, `CanGetPreviousRow()`, `GetNext{Row}()`, `GetPrevious{Row}()`; the page enables `<` / `>` buttons from them after every move.
- After a successful confirm, remove the row and move to the next one (or previous if it was last); when none is left, go back as the spec says.
- A hand-written confirm handler runs from an async-void `Clicked`: guard it against a second tap while the call runs (a double tap confirms the row twice) and catch into `ShowErrorAsModalAsync`, or an exception crashes the app (`TaskMoveConfirmPage.OnConfirmAsync`).
- Keep one edit collection per row (built once from the `DataTable`), so what the user typed on a row survives moving away and back, as legacy's bound `DataRow` did (`TaskMoveConfirmViewModel`).
- Visibility that depends on the current row (show only the ID pair the task has) is simplest in code after each move: `GetControl(FIELD).IsVisible = ...`, the same call the appearance service makes. Derive the flags in the ViewModel and build the server filters from the same flags, so what is shown and what is sent can't drift apart.

Reference: `pages/receive/ReceiveDetailsPage.cs` and `pages/pick/PickDetailsPage.cs` in rnditmscore.

### Data grid

```csharp
UIDataGrid grid = UIDataGridBuilderHelper.BuildStandardDataGrid(Guid.NewGuid().ToString(),
    nameof({Name}ViewModel.DataRows), Columns(),
    async (s, e) => { if (e.Item != null) await {Name}PageController.On{Row}SelectedAsync(e.Item); });

private IndexedObjectCollection<DataDefinition> Columns() =>
[
    new DataDefinition { DataName = "{FIELD}", BindingPath = "{FIELD}", Caption = "{Label}" },
    // numeric: DataType = DataType.Decimal; command column: EntryType = ControlTypeName.Command, Commands = { ... }
];
```

Fill it with `Model.SetModelData(ds.Tables[0])`; rows become `ExpandoObject`s, so read a tapped row as `(IDictionary<string, object>)e.Item` (see `MoveSearchResultPage` in rnditmscore). Hide it until there is data when the spec says so. Clear `grid.SelectedItem` in `BeforeOnAppearing`.

Column widths: leave them out. The grid sizes each text column to its widest value or caption, gives spare room to the text columns, and scrolls sideways when they don't fit. A `MinWidth` on a text column only makes it wider than its content, and `StandardColumnMinWidth` forces one floor on every column, so set neither. Template columns (icons, images, commands) aren't measured, so give them a fixed `MinWidth` and `MaxWidth`, and pass `TemplateColumnMaxWidth = null` when they need more than the default 50dp.

### Cards grid

For `CardsGrid` / `PanelAndCardsGrid`: card fields come from rows with `GRIDINCLUDE = 1`; the page provides `CardsGridParentContainer` (the name of a container in `BuildPageLayout`), `GetCardsGridItemsSourceBinding()` (e.g. `nameof(VM.Rows)`; items must support `[COLUMN]` indexing, like `DataTable.Rows`), and optionally `GetCardsGridTapAction()`, `GetCardsGridEmptyViewText()`, `CreateCardsGridConfiguration(fields)`.

### Lookups and back

- Lookup modal: `await OpenLookupAsync<LookupModalPage, LookupModalPageController>(config)`; returns null on cancel, so null-guard. Custom modals: wrap in `RunLookupGuardedAsync(...)`.
- Lookup trigger: the field's own end icon, not a separate button: `if (GetControl(FIELD) is EditBase editor) { editor.EndIcon = ResourceHelper.GetImageSourcePNG("LookupIcon32"); editor.EndIconCommand = new Command(async () => await OpenXLookupAsync()); }`. A field filled only from the lookup is `ISREADONLY` 1; its end icon keeps working.
- Root screen: `HideShellBackButton()`. Back that must run logic (release a task, confirm exit): `SetBackAction(asyncAction)`, which covers both the toolbar arrow and the hardware button.
- A Cancel button on a root screen that navigates to `//Main/Menu` leaves the operation open: the next menu tap asks "New Operation Confirmation: Close Current Operation And Open New Operation?". Expect it when driving the device.

### Numeric entry

A numeric field can't show "empty": it shows and writes 0. If empty means something (legacy "empty = the full quantity"), pre-fill the meaningful value and send whatever the field holds, so the server's own check rejects a 0 or a negative entry. Leave it out only where the server would apply that check wrongly (Move Task: a Cancel or Postpone reason, whose 0 the "<= 0" check would refuse). Values from SQL `numeric` columns carry their scale (`10.00000`); divide by `1.000000000000000000000000000000000m` before binding, or editing the text leaves stray decimals ("10.005") that the server rejects for products without decimal quantities.

### Field events

In `AfterOnAppearing()`: `if (GetControl(Feature.FIELD) is UISwitch s) { s.Toggled -= OnX; s.Toggled += OnX; }`. Prefer an appearance rule (SQL) over code when the behaviour is a pure show/hide/enable on a field value.

**Scans** (keyboard-wedge scanner: text plus Enter in a field): no existing page handles Enter yet. Entry fields are `UIEntry`, the in-house `TextEdit`, which raises `Completed` on Enter. Tell the user the pattern is new so it gets tested on a device.

## When something doesn't show

| Symptom | Check |
| --- | --- |
| No fields | `DATADISPLAYNAME` = `nameof(Page)`; script applied; `ISVISIBLE`; unique `SEQUENCE`; `DataDisplayDataDefParentContainer` names a container that is in the layout |
| A tab or group stays empty | its container's name equals the fields' `DATAGROUPNAME` exactly |
| Editing a field throws "declared as A but the value is B" | the bound filter's type comes from a SQL column of another type (Row navigation, Types) |
| Empty combobox | list name matches; the list's BP returns rows for its `CONSTRAINTS` |
| Appearance rule ignored | `~FIELD~` spelling (case-sensitive); `SEQUENCE` order |
| Validation never fires | `ACTIONNAME` equals the name passed to `ValidateThenRunAsync`; expression is true when valid |
| Navigation fails | route registered for every level; both controller and page registered in DI; parameter key is `nameof(VM.DynamicFilters)` |
| Server ignores a value | filter name and `DataType` match what the BP reads |
| Overlay stuck | an exception escaped `IsBusyFor`, or an un-awaited task |
| Control type override ignored (Switch instead of CheckBox, password not masked) | `master.DATAAPPEARANCEDEFINITION` has a `DefaultAppearance` row (see DATAPANELAPPEARANCEDEFINITION) |
| Fields in one tab don't show or keep values | the tab was removed from `TabView.Items` and added back (Tabs and groups) |
| Taps on the left half of a tab hit nothing or the wrong field | a multi-tab `SelectedItemIndex` jump; step one tab at a time |
| "Object reference not set to an instance of an object" on page load after a server restart or a test run | the device session ended; restart the app and log in again |
