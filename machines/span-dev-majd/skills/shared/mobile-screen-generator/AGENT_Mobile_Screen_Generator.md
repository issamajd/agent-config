# Mobile Screen Generator Agent

## Agent Purpose

This agent generates complete mobile screen implementations from specification documents. It produces SQL metadata scripts, C# code files (ViewModel, Controller, Page), and updates dependency injection and navigation configuration files.

---

## Agent Capabilities

### What This Agent CAN Do:

1. ✅ **Generate SQL Metadata Scripts**:
   - DATADISPLAYDATADEFINITION entries for all fields
   - DATADISPLAYVALUELISTDEFINITION entries for dropdowns
   - DATAPANELAPPEARANCEDEFINITION entries for conditional visibility **and control type overrides**
   - DATADISPLAYVALIDATIONDEF entries for validation rules

2. ✅ **Generate ViewModel Class**:
   - Inherit from GridViewModel, DynamicViewModel, or BaseViewModel
   - Add [QueryProperty] attributes for navigation parameters
   - Implement I_ContextDataExtractor interface when needed
   - Add custom properties with OnPropertyChanged notifications

3. ✅ **Generate Controller Class**:
   - Field constants class (nested)
   - ViewModel reference and constructor
   - InitializeAsync() with calculations and default values
   - Internal Call{Action}Async() methods
   - Server communication methods
   - Navigation methods with route building

4. ✅ **Generate Page Class**:
   - Constructor with dependency injection
   - BuildPageLayout() for UI structure
   - BuildActionsGridLayout() for buttons
   - Grid column definitions (if grid section)
   - Event handlers in AfterOnAppearing()
   - Validation before button actions

5. ✅ **Update DILoader**:
   - Add AddTransient registration for Controller
   - Add AddTransient registration for Page
   - Use Factory.ClientLocator.GetType() pattern

6. ✅ **Update AppController**:
   - Add Routing.RegisterRoute() with full hierarchical path
   - Map to Page type

7. ✅ **Add Constants**:
   - Add to ScreenNames.cs
   - Add to BPNames.cs (if new business processes)
   - Add to MethodNames.cs (if new methods)

---

## Agent Constraints

### What This Agent CANNOT/MUST NOT Do:

1. ❌ **Do NOT add features not in specification**:
   - No extra fields
   - No extra buttons
   - No extra validation rules
   - No extra conditional logic

2. ❌ **Do NOT deviate from established patterns**:
   - Always follow MOBILE_SCREEN_CREATION_GUIDE.md patterns
   - Use exact naming conventions
   - Follow exact file structure
   - Use exact template structure from guide

3. ❌ **Do NOT make assumptions**:
   - If specification is unclear, ASK the user
   - If field type is ambiguous, ASK the user
   - If business process name is missing, ASK the user
   - Do NOT fill in missing information with guesses

4. ❌ **Do NOT create custom implementations**:
   - No custom base classes
   - No custom helper methods beyond standard patterns
   - No custom UI controls beyond standard set
   - No custom validation logic beyond expression-based

5. ❌ **Do NOT modify existing screens**:
   - Only create NEW screens or update SPECIFIED files
   - Do NOT change patterns in other screens
   - Only add entries to DILoader and AppController, never modify existing entries

---

## Required Context Files

Before generating code, ensure these files are available, if not don't continue:

1. **MOBILE_SCREEN_CREATION_GUIDE.md** - Complete reference guide with all patterns, you should refer to it when in doubt
2. **TEMPLATE_Screen_Specification.md** - Template structure for specifications
3. **User's filled specification** - Completed specification for the screen to generate

---

## Generation Workflow

### Step 1: Validate Specification

Before starting, verify the specification has:
- ✅ Screen name and basic information
- ✅ All fields with complete properties (name, type, control, width, visible, readonly, mandatory, image)
- ✅ Value lists defined for all Combobox fields
- ✅ Button actions with clear descriptions
- ✅ Navigation parameters (input/output)

**If anything is missing or unclear**: STOP and ASK the user to clarify.

### Step 2: Generate Files in Order

Generate files in this exact order:

#### 2.1: SQL Metadata Script
**File**: `pages/screens-defs-{ScreenName}.sql`

**Contents**:
1. Header comment with screen name and purpose

1b. **DATADISPLAYDEFINITION entry** (one row per screen — **required for all screens**)
   - Set DATADISPLAYNAME = {ScreenName}Page (must match `nameof(Page)`)
   - Set DATADISPLAYTYPE = one of: `Panel`, `CardsGrid`, `PanelAndCardsGrid`
     - `Panel` — form-only screen
     - `CardsGrid` — card list only (no dynamic form panel)
     - `PanelAndCardsGrid` — form + card list on same page
   - Without this row, `DataDisplayDefinitionService` returns null → cards never load

2. DATADISPLAYDATADEFINITION entries (one per field)
   - Use specification field table directly
   - Set DATADISPLAYNAME = {ScreenName}Page from spec
   - Set SCREENPROFILENAME = Profile Code from spec
   - Set DATAGROUPNAME = "Main" (or from spec if different)
   - Set DATANAME from field "Field Name"
   - Set DATADESCRIPTION from field "Label"
   - Set SEQUENCE from field order
   - Set WIDTH from field Width column (4 or 8)
   - Set ISVISIBLE from field Visible column (1 or 0)
   - Set ISREADONLY from field ReadOnly column (1 or 0)
   - Set ISMANDATORY from field Mandatory column (1 or 0)
   - Set DATATYPE from field Type column
   - Set DATAFORMAT from field Format column (if specified)
   - Set FILTERDEFAULTVALUES from field Default column (if specified)
   - Set VALUELISTDEFINITION from field Notes (if mentions ValueList)
   - Set FILTERTYPE = 'Value' or 'List' (List if Combobox, else Value)
   - Set FILTERCOMPARISONTYPE = 'Equal' (or from spec if different)
   - Set IMAGENAME from field Image column (if specified, for fields with icons)
   - Set PANELINCLUDE = 1 if field belongs to the panel form, 0 or NULL if not
   - Set GRIDINCLUDE = 1 if field belongs to the cards grid, 0 or NULL if not
     - For `Panel`-only screens: leave both NULL (all fields go to panel by default)
     - For `CardsGrid`-only screens: set GRIDINCLUDE = 1 on card fields
     - For `PanelAndCardsGrid`: explicitly set the appropriate flag per field
     - Both flags NULL → field included on whichever surface the screen type requires
   - Card-specific override columns (used only when GRIDINCLUDE = 1):
     - GRIDCAPTION — label within cards (overrides DATADESCRIPTION)
     - GRIDISVISIBLE — visibility within cards (overrides ISVISIBLE)
     - GRIDSEQUENCE — ordering within cards (overrides SEQUENCE)
     - GRIDGROUPNAME — grouping within cards (overrides DATAGROUPNAME)
     - (GRIDWIDTH exists in the table but is NOT read by the mobile client)
   - Set CREATEDBY = 'AIGenerated' (Always)
   - Set CREATEDDATE = 'getdate()' (Always)

3. DATADISPLAYVALUELISTDEFINITION entries (if any dropdowns)
   - Use specification Value Lists table
   - Set VALUELISTDEFINITION = List Name from spec
   - Set TABLENAME = Source Table from spec
   - Set VALUECOLUMNNAME = Value Column from spec
   - Set DISPLAYCOLUMNNAME = Display Column from spec
   - Set PARENTVALUESOURCE = Parent Filter from spec (if cascading)
   - Set PARENTVALUECOLUMNNAME = Parent column in source table
   - Set CONSTRAINTS = Build from parent filter (e.g., "COLUMN=~PARENTFIELD~")
   - Set ADDBLANKITEM = 1 or 0
   - Set ISSEARCHABLE = From spec Searchable column (1 or 0)
   - Set BPNAME, METHODNAME if Source Type is BP-based
   - Set CREATEDBY = 'AIGenerated' (Always)
   - Set CREATEDDATE = 'getdate()' (Always)
   
4. DATAPANELAPPEARANCEDEFINITION entries (for conditional visibility **AND/OR control type overrides**)
   - Use specification Conditional Visibility table AND Control Type Override table
   - Create one entry per condition per field, or one entry per control type override
   - Set DATADISPLAYNAME = {ScreenName}Page
   - Set CONTROLNAME = Field Name (raw data name, NOT the prefixed EntryName)
   - Set VISIBLE = 1 or 0 based on spec Show/Hide
   - Set ENABLED = 1 or 0 based on spec Enable/Disable
   - Set READONLY = 0 (unless specified)
   - Set CONDITION = Build expression from spec condition (NULL if purely a control type override)
   - Set SEQUENCE = Priority order (start from 1)
   - Set APPEARANCENAME = 'DefaultAppearance'
   - Set CONTROLTYPE = Override control type if specified (e.g., 'ChipGroup', 'Chip', 'CaptionValue', 'InlineCaptionLabel', 'Separator'). NULL if no override.
   - Set CONTROLPARAMS = Semicolon-separated key='value' pairs for additional customization (e.g., `EntryStyleName='ThemeStyleNames.Label.ListSubDetailData'`). NULL if no params.
   - Set CREATEDBY = 'AIGenerated' (Always)
   - Set CREATEDDATE = 'getdate()' (Always)
   
   **CONTROLTYPE Override Behavior**: When CONTROLTYPE is set, it overrides the auto-determined control type from DATADISPLAYDATADEFINITION. This is applied in BaseContentPage before controls are built. Available override types: ChipGroup (editable multi-select, requires ValueList), Chip (display-only badge), CaptionValue, InlineCaptionLabel, Separator.
   
   **CONTROLPARAMS Format**: Semicolon-separated `key='value'` pairs. Currently supported parameters:
   - `EntryStyleName='StyleName'` — Overrides the control's style
   - `ConverterProfile='ProfileName'` — Name of a `ChipConverterRegistry` profile for display-only Chip text/background/text-color converters (registered in `DILoader.cs` via `ChipConverterRegistry.Register()`)
   
   **⚠️ Chip + ReadOnly**: When CONTROLTYPE is `Chip`, READONLY **must be 0**. ReadOnly=1 causes DevExpress to enforce default styling (grey text, white background), overriding any color bindings from converters. The chip is already non-interactive via `InputTransparent = true`.
   
5. DATADISPLAYVALIDATIONDEF entries (if validation rules)
   - Use specification Validation Rules table
   - Group by Action Name
   - Set DATADISPLAYNAME = {ScreenName}Page
   - Set ACTIONNAME = Action from spec (e.g., 'Submit', 'Save')
   - Set SEQUENCE = Order from spec
   - Set VALIDATIONNAME = Rule Name from spec
   - Set VALIDATIONTYPE = 'Condition'
   - Set VALIDATIONMESSAGE = Error Message from spec
   - Set EXPRESSION = Build expression from spec Condition to PASS
   - Set CREATEDBY = 'AIGenerated' (Always)
   - Set CREATEDDATE = 'getdate()' (Always)
   
**Expression Syntax Rules**:
- Field references: `~FIELDNAME~`
- Comparisons: `=`, `!=`, `>`, `<`, `>=`, `<=`
- Logical operators: `||` (OR), `&&` (AND)
- Functions: `isemptyornull(~FIELDNAME~)`
- Example: `~ADDTOASSET~=1||isemptyornull(~CATALOG~)=false`

#### 2.2: Constants Files

**File**: `constants/ScreenNames.cs`
```csharp
public class ScreenNames : client.mobile.constants.ScreenNames
{
    // ... existing constants

    public const string {ScreenName} = "{ScreenName}";
}
```

**File**: `constants/BPNames.cs` (only if new BP)
```csharp
public class BPNames : client.mobile.constants.BPNames
{
    // ... existing constants

    public const string {BusinessProcessName} = "{BusinessProcessName}";
}
```

**File**: `constants/MethodNames.cs` (only if new method)
```csharp
public class MethodNames : client.mobile.constants.MethodNames
{
    // ... existing constants

    public const string {MethodName} = "{MethodName}";
}
```

#### 2.2.1: Model Field Constants (IMPORTANT - Centralized Pattern)

**IMPORTANT**: Field constants MUST be added to the centralized `ModelFields` partial class files, NOT as nested classes in controllers.

**File Structure**:
- `constants/ModelFields.cs` - Base partial class with Common fields
- `constants/ModelFields.{FeatureName}.cs` - Feature-specific fields (e.g., `ModelFields.PickRequest.cs`)

**Step 1**: Check if a feature file already exists for your feature. If not, create one:

**File**: `constants/ModelFields.{FeatureName}.cs`
```csharp
namespace client.mobile.s4wes.constants
{
    public static partial class ModelFields
    {
        /// <summary>{FeatureName} specific fields</summary>
        public static class {FeatureName}
        {
            public const string {FIELDNAME} = "{FIELDNAME}";
            // ... more fields specific to this feature
        }

        /// <summary>Additional domain classes if needed</summary>
        public static class {DomainName}
        {
            public const string {FIELDNAME} = "{FIELDNAME}";
        }
    }
}
```

**Step 2**: Add any new common fields to the base file:

**File**: `constants/ModelFields.cs`
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
            // Add new common fields here
        }
    }
}
```

**Example Feature File** (`ModelFields.PickRequest.cs`):
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
        }

        /// <summary>Location and section fields</summary>
        public static class Location
        {
            public const string SECTIONID = "SECTIONID";
            public const string SECTIONCODE = "SECTIONCODE";
            public const string LOCATIONCODE = "LOCATIONCODE";
        }

        /// <summary>Drop ID and box-related fields</summary>
        public static class DropId
        {
            public const string DROPID = "DROPID";
            public const string CLOSEBOX = "CLOSEBOX";
        }
    }
}
```

**Rules for Field Organization**:
1. **Common fields** (used across multiple features): Add to `ModelFields.Common`
2. **Feature-specific fields**: Add to feature-specific nested class in `ModelFields.{FeatureName}.cs`
3. **Domain grouping**: Group related fields into logical classes (e.g., Location, DropId)
4. **Avoid duplication**: Before adding a field, check if it exists in Common or another feature file

#### 2.3: ViewModel Class
**File**: `models/{feature}/{ScreenName}ViewModel.cs`

**Template Selection**:
- If spec has Section 4 (Grid): Use **GridViewModel**
- Else if spec has navigation parameters: Use **DynamicViewModel**
- Else: Use **BaseViewModel**

**Structure**:
```csharp
using client.mobile.engines;
using client.mobile.models;
using shared.dataquery.objects;
using shared.xal.objects.collections;

namespace client.mobile.s4wes.models
{
    /// <summary>
    /// ViewModel for {ScreenName}.
    /// Purpose: {Purpose from spec}
    /// </summary>
    [QueryProperty(nameof(DynamicFilters), "DynamicFilters")]  // If receives parameters
    public class {ScreenName}ViewModel : {BaseClass}, I_ContextDataExtractor  // If passes data forward
    {
        // Add custom properties only if specified in spec
    }
}
```

**Base Class Selection**:
- `GridViewModel` if grid section (Section 4)
- `DynamicViewModel` if form only
- `BaseViewModel` only if custom requirements

**Attributes**:
- Add `[QueryProperty(nameof(DynamicFilters), "DynamicFilters")]` if receives navigation parameters

**Interfaces**:
- Add `I_ContextDataExtractor` if passes data to child screens

**Custom Properties** (only if in spec):
```csharp
private {type} {fieldName};
public {Type} {PropertyName}
{
    get => {fieldName};
    set
    {
        {fieldName} = value;
        OnPropertyChanged(nameof({PropertyName}));
    }
}
```

#### 2.4: Controller Class
**File**: `pages/{feature}/{ScreenName}PageController.cs`

**IMPORTANT**: Do NOT create nested Field Constants classes in controllers. Use the centralized `ModelFields` pattern (see section 2.2.1).

**Full Structure**:
```csharp
using client.mobile.controller;
using client.mobile.engines;
using client.mobile.engines.app;
using client.mobile.models;
using client.mobile.s4wes.constants;
using static client.mobile.s4wes.constants.ModelFields;  // <-- Import centralized ModelFields
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
    /// Purpose: {Purpose from spec}
    /// </summary>
    public class {ScreenName}PageController : BaseController
    {
        // NOTE: Field constants are in constants/ModelFields.{FeatureName}.cs
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
            // Add initialization logic from spec Business Logic section
            // (no artificial delays — this idiom was removed codebase-wide)
            InitViewModelValues();
            // Add calculated fields from spec section 6
            return Task.CompletedTask;
        }

        private void InitViewModelValues()
        {
            // Add filters with default values from spec
            // Use centralized ModelFields: Common.FIELDNAME, {Feature}.FIELDNAME, etc.
            // AddOrReplaceFilter(Common.{FieldName}, DataType.{Type}, this.{ScreenName}Model.DynamicFilters, {DefaultValue});
        }

        #endregion

        #region Internal Action Methods

        // Create one method per button from spec section 9

        /// <summary>
        /// {Button description from spec}
        /// </summary>
        internal async Task<Result> Call{ButtonAction}Async()
        {
            Result result = null;
            await IsBusyFor(async () =>
            {
                try
                {
                    // If Server Call:
                    DataSet dsResult = await {ServerMethodName}Async();

                    if (DataHelper.IsEmptyResult(dsResult))
                    {
                        result = Result.Failure("No data found", ErrorType.SystemError);
                    }
                    else
                    {
                        // If grid: this.{ScreenName}Model.SetModelData(dsResult.Tables[0]);
                        // If navigation: proceed to navigation
                    }

                    // If Navigation:
                    // string route = Build{Target}NavigationRoute();
                    // Dictionary<string, object> parameters = Build{Target}NavigationParameters();
                    // await this.NavigationService.NavigateToAsync(route, parameters);

                    // finally always add:
                    // result = Result.Success();
                }
                catch (Exception methodEx)
                {
                    result = Result.Failure(methodEx.Message, ErrorType.SystemError);
                }
            });
            return result;
        }

        #endregion

        #region Private Helper Methods

        private string Build{Target}NavigationRoute()
        {
            // Build from spec navigation hierarchy
            return $"//Main/Operation/{ScreenNames.{Parent}}/{ScreenNames.{Current}}";
        }

        private Dictionary<string, object> Build{Target}NavigationParameters()
        {
            return new Dictionary<string, object>
            {
                { nameof({TargetViewModel}.DynamicFilters),
                  this.{ScreenName}Model.DynamicFilters }
            };
        }

        #endregion

        #region Server Communication

        private Task<DataSet> {ServerMethodName}Async()
        {
            return mobile.factory.ModelIO.Instance.ExecuteActionAsync<DataSet>(
                BPNames.{BusinessProcess},  // From spec
                MethodNames.{Method},        // From spec
                this.{ScreenName}Model.DynamicFilters,
                new XalIndexedObjectCollection<Filter>());
        }

        #endregion

        #region Helper Methods

        #endregion
    }
}
```

**Key Generation Rules**:
1. **Field Constants**: Add to centralized `ModelFields.{FeatureName}.cs` file (NOT nested in controller)
2. **InitializeAsync()**: Add logic from spec Business Logic section
3. **InitViewModelValues()**: Add filters for fields with defaults or calculated fields, use `Common.FIELD`, `{Feature}.FIELD` syntax
4. **Call{Action}Async()**: One method per button in spec
5. **Server Methods**: Use BP and Method names from spec Button Actions
6. **Navigation Methods**: Build routes from spec navigation hierarchy

#### 2.5: Page Class
**File**: `pages/{feature}/{ScreenName}Page.cs`

**Full Structure**:
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
using client.mobile.objects;

namespace client.mobile.s4wes.pages.{feature}
{
    /// <summary>
    /// Page for {ScreenName}.
    /// Purpose: {Purpose from spec}
    /// Layout: {Describe sections from spec}
    /// </summary>
    public class {ScreenName}Page : BaseContentPage
    {
        #region Controller Reference

        protected {ScreenName}PageController {ScreenName}PageController
            => ({ScreenName}PageController)this.BaseController;

        #endregion

        #region Fields

        // Declare fields for controls accessed later
        UIDataGrid? ResultGrid;  // If Section 4 (grid)

        #endregion

        #region Constructor

        public {ScreenName}Page({ScreenName}PageController {ScreenName}PageController)
            : base({ScreenName}PageController,
                   "{ScreenTitle from spec}",
                   nameof({ScreenName}Page))
        {
            // Root screens hide the back button:
            // HideShellBackButton();
            // Screens where back must run logic (skip/complete/reset) wire it once for
            // BOTH the toolbar arrow and the hardware back button:
            // SetBackAction(MyBackActionAsync);
        }

        #endregion

        #region Lifecycle Methods

        protected override void BeforeOnAppearing()
        {
            // Add reset logic from spec if any

            // If grid: clear selection
            if (ResultGrid != null)
                ResultGrid.SelectedItem = null;
        }

        protected override void AfterOnAppearing()
        {
            base.AfterOnAppearing();

            // Add event handlers from spec Business Logic section
            // SetupEventHandlers();
        }

        #endregion

        #region UI Layout

        protected override IView BuildPageLayout()
        {
            // Build grid if Section 4 checked
            if (/* Section 4 checked */)
            {
			
				ResultGrid = BuildDataGrid(nameof({ScreenName}PageController.{ScreenName}Model.DataRows),
    ResultGridColumnDefinitions());
				ResultGrid.IsVisible = false; //Should show it only after server call for data (need to add this functionality during generation)
            }

            UIGrid contentGrid = new()
            {
                RowDefinitions =
                {
                    // Add rows based on sections checked in spec:
                    // Section 1 (Form): GridLength.Star or GridLength.Auto
                    // Section 2 (Attributes): GridLength.Star
                    // Section 3 (Buttons): GridLength.Auto
                    // Section 4 (Grid): GridLength.Star
                }
            };

            // Section 1: Always present
            contentGrid.Add(new UIGrid(this.DataDisplayDataDefParentContainer), 0, 0);

            // Section 3: If buttons checked
            if (/* Section 3 checked */)
            {
                contentGrid.Add(BuildActionsGridLayout(), 0, 1);
            }

            // Section 4: If grid checked
            if (/* Section 4 checked */)
            {
                contentGrid.Add(ResultGrid, 0, 2);
            }

            return contentGrid;
        }

        #endregion

        #region Section Builders

        private UIGrid BuildActionsGridLayout()
        {
            // Create buttons from spec Section 3

            UIButton btn{ButtonName} = UIButtonBuilderHelper.BuildButton(
                "{ButtonName}Btn",
                "{Button Label from spec}",
                string.Empty,
                string.Empty);

            // If validation specified in spec (validates, shows validation errors,
            // runs the controller action under one busy scope, shows error modal on failure):
            btn{ButtonName}.Clicked += async (s, e) =>
                await ValidateThenRunAsync("{ActionName}", {ScreenName}PageController.Call{Action}Async);

            // If NO validation specified in spec (runs the action under the busy
            // indicator and shows the error modal on failure):
            // btn{ButtonName}.Clicked += async (s, e) =>
            //     await RunControllerActionAsync({ScreenName}PageController.Call{Action}Async);

            // Only fall back to a hand-written handler when the flow needs extra
            // branching the helpers can't express (success snackbars/modals,
            // multi-outcome results, checks between validation and the call).

            // If multiple buttons (could be Horizontal or Vertical):
            // return ActionGridBuilderHelper.BuildVerticalButtonActionGrid(btn1, btn2);
			// or
            // return ActionGridBuilderHelper.BuildHorizontalButtonActionGrid(btn1, btn2);
            // If single button:
            return ActionGridBuilderHelper.BuildSingleButtonActionGrid(btn{ButtonName}, LayoutOptions.End);
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
						// Add required functionality here, for example if navigation needed you need
					}
				}
			);
		}
        #endregion

        #region Grid Column Definitions

        // Only if Section 4 checked
        private IndexedObjectCollection<DataDefinition> ResultGridColumnDefinitions()
        {
            // Use centralized ModelFields: Common.FIELDNAME, {Feature}.FIELDNAME, etc.
            return [
                // Create columns from spec Section 11 Grid Configuration
                new DataDefinition()
                {
                    DataName = Common.{FieldName},           // or {Feature}.{FieldName}
                    BindingPath = Common.{FieldName},        // or {Feature}.{FieldName}
                    Caption = "{Column Label from spec}"
                },
                // ...
            ];
        }

        #endregion
    }
}
```

**Page Import Requirements**:
Add this import to use centralized ModelFields:
```csharp
using static client.mobile.s4wes.constants.ModelFields;
```

**Layout Rules**:
1. **RowDefinitions**: Based on checked sections in spec Section 2
   - Section 1 (Form): `GridLength.Star` if only section, else `GridLength.Auto`
   - Section 2 (Attributes): `GridLength.Star`
   - Section 3 (Buttons): `GridLength.Auto`
   - Section 4 (Grid): `GridLength.Star`

2. **Buttons**:
   - Single button: Use `ActionGridBuilderHelper.BuildSingleButtonActionGrid()`
   - Two buttons: Use `ActionGridBuilderHelper.BuildTwoButtonsActionGrid()`
   - More buttons: Use `ActionGridBuilderHelper.BuildVerticalButtonActionGrid()`

3. **Validation**: Use `ValidateThenRunAsync("{ActionName}", controllerCall)` if spec has validation for that button; `RunControllerActionAsync(controllerCall)` if not. Never hand-write the validate → display-errors → call → error-modal chain.

4. **Grid Columns**: Use spec Section 11 Grid Configuration table

#### 2.5b: CardsGrid Page Pattern (for `CardsGrid` or `PanelAndCardsGrid` display types)

When the spec indicates a CardsGrid surface, the page must provide card-specific overrides. Card fields, layout, and control types come from DB; items source, navigation, and chrome come from code.

**Additional overrides on the Page class**:

```csharp
public class {ScreenName}Page : ExtendedBaseContentPage  // or BaseContentPage
{
    private const string CardsGridContainerName = "{ScreenName}CardsContainer";

    // Tell BaseContentPage where to insert the UICollectionView
    protected override string? CardsGridParentContainer { get; set; } = CardsGridContainerName;

    // Binding path to the rows collection on the ViewModel (e.g. DataTable.Rows, ObservableCollection, etc.)
    protected override string? GetCardsGridItemsSourceBinding() => nameof({ScreenName}ViewModel.Rows);

    // Optional: row tap handler
    protected override Action<object>? GetCardsGridTapAction()
    {
        return item =>
        {
            if (item is DataRow row)
                _ = {ScreenName}PageController.CallGoToDetailAsync(/* extract params from row */);
        };
    }

    // Optional: empty state text
    protected override string GetCardsGridEmptyViewText() => "No items found.";

    // Optional: spacing, accent bar
    protected override DataCardConfiguration CreateCardsGridConfiguration(DataDefinition[] fields)
    {
        DataCardConfiguration config = base.CreateCardsGridConfiguration(fields);
        config.ColumnSpacing = 8;
        config.RowSpacing = 10;
        return config;
    }

    protected override IView BuildPageLayout()
    {
        // Create named container that matches CardsGridContainerName
        UIStackLayout cardsContainer = new UIStackLayout(CardsGridContainerName);
        cardsContainer.VerticalOptions = LayoutOptions.FillAndExpand;

        UIGrid page = new()
        {
            RowDefinitions =
            {
                // For PanelAndCardsGrid: form row + cards row
                new RowDefinition { Height = GridLength.Auto },  // form / instructions
                new RowDefinition { Height = GridLength.Star },  // cards
            }
        };
        // Section 1: form or instructions
        page.Add(/* form or instructions view */, 0, 0);
        // CardsGrid container
        page.Add(cardsContainer, 0, 1);

        return page;
    }
}
```

**Key rules**:
- `CardsGridParentContainer` must match the `Name` of an `I_UIParentControl` (e.g. `UIStackLayout`) in `BuildPageLayout`.
- `GetCardsGridItemsSourceBinding()` returns a binding path relative to the page's `BindingContext` (the ViewModel).
- Card fields bind with `[COLUMN]` bracket notation (set by `DataDefinitionBuilderForCardsGrid`), so the items source must be a collection whose items support indexer access (e.g. `DataTable.Rows`).
- Control types on cards (Chip, CaptionValue, etc.) are applied via `DATAPANELAPPEARANCEDEFINITION` just like panel fields.

#### 2.6: Update DILoader
**File**: `engines/DILoader.cs`

**Action**: ADD these entries (do not modify existing)

```csharp
// {ScreenName} Controller
Builder.Services.AddTransient(
    typeof({ScreenName}PageController),
    mobile.factory.Factory.ClientLocator.GetType(nameof({ScreenName}PageController)));

// {ScreenName} Page
Builder.Services.AddTransient(
    typeof({ScreenName}Page),
    mobile.factory.Factory.ClientLocator.GetType(nameof({ScreenName}Page)));
```

**Location**: Inside `LoadServices()` method, after existing registrations

#### 2.7: Update AppController
**File**: `AppController.cs`

**Action**: ADD this route (do not modify existing)

```csharp
// {ScreenName}
Routing.RegisterRoute(
    $"//Main/Operation/{ScreenNames.{Parent}}/{ScreenNames.{ScreenName}}",
    typeof({ScreenName}Page));
```

**Location**: Inside `InitializeRouting()` method, before `base.InitializeRouting();`

**Route Building Rules**:
- Root screen: `//Main/Operation/{ScreenNames.{ScreenName}}`
- Child screen: `//Main/Operation/{Parent}/{ScreenName}`
- Deep hierarchy: `//Main/Operation/{GrandParent}/{Parent}/{ScreenName}`

---

## Output Format

### File Organization

Provide generated files in this structure:

```
Generated Files:
├── SQL/
│   └── screens-defs-{ScreenName}.sql
├── Constants/
│   ├── ScreenNames.cs (additions)
│   ├── BPNames.cs (additions, if needed)
│   ├── MethodNames.cs (additions, if needed)
│   ├── ModelFields.cs (additions to Common class, if new common fields)
│   └── ModelFields.{FeatureName}.cs (CREATE if new feature, or additions if exists)
├── Models/
│   └── {feature}/{ScreenName}ViewModel.cs
├── Pages/
│   └── {feature}/{ScreenName}Page.cs
├── Controllers/
│   └── {feature}/{ScreenName}PageController.cs
├── DILoader_Additions.txt (entries to add to DILoader.cs)
└── AppController_Additions.txt (entries to add to AppController.cs)
```

### Output Each File Separately

For each file, provide:

1. **File Path**: Full path relative to project root
2. **Action**: "CREATE NEW" or "ADD TO EXISTING"
3. **Content**: Complete file content or additions
4. **Instructions**: Any special notes for the developer

**Example**:

```markdown
### File: SQL/screens-defs-ProductSearchPage.sql
**Action**: CREATE NEW
**Content**:
```sql
-- SQL content here
```
**Instructions**: Execute this script on the database before running the application.
```

---

## Validation Checklist

Before delivering generated code, verify:

### SQL Metadata:
- [ ] DATADISPLAYDEFINITION row exists with correct DATADISPLAYNAME and DATADISPLAYTYPE
- [ ] All fields from spec have DATADISPLAYDATADEFINITION entries
- [ ] PANELINCLUDE / GRIDINCLUDE flags set correctly per field surface (Panel, CardsGrid, or both)
- [ ] GRID* override columns set where card layout differs from panel (GRIDCAPTION, GRIDISVISIBLE, GRIDSEQUENCE, GRIDGROUPNAME)
- [ ] All Combobox fields have DATADISPLAYVALUELISTDEFINITION entries
- [ ] All conditional visibility rules have DATAPANELAPPEARANCEDEFINITION entries
- [ ] All control type overrides have DATAPANELAPPEARANCEDEFINITION entries with CONTROLTYPE set
- [ ] CONTROLPARAMS set where additional customization is specified (e.g., EntryStyleName)
- [ ] All validation rules have DATADISPLAYVALIDATIONDEF entries
- [ ] DATADISPLAYNAME matches spec Screen Name exactly
- [ ] SCREENPROFILENAME matches spec Profile Code exactly
- [ ] SEQUENCE values are sequential starting from 1
- [ ] IMAGENAME set for fields with icons (from spec Image column)

### ViewModel:
- [ ] Correct base class (GridViewModel/DynamicViewModel/BaseViewModel)
- [ ] [QueryProperty] attribute if receives navigation parameters
- [ ] I_ContextDataExtractor if passes data to child screens
- [ ] Custom properties only if specified in spec

### ModelFields (Centralized Constants):
- [ ] New fields added to appropriate `ModelFields.{FeatureName}.cs` file
- [ ] Common fields added to `ModelFields.Common` class if shared across features
- [ ] Fields organized into logical domain classes (e.g., Location, DropId)
- [ ] No duplicate field definitions across files

### Controller:
- [ ] NO nested Field Constants class (use centralized ModelFields)
- [ ] `using static client.mobile.s4wes.constants.ModelFields;` import added
- [ ] ViewModel property and constructor
- [ ] InitializeAsync() with logic from spec Business Logic section
- [ ] One Call{Action}Async() method per button
- [ ] Server communication methods with correct BP/Method names from spec
- [ ] Navigation methods with correct routes from spec
- [ ] Field references use `Common.FIELD`, `{Feature}.FIELD` syntax

### Page:
- [ ] Constructor with correct screen title from spec
- [ ] BuildPageLayout() with correct sections based on spec checkboxes
- [ ] BuildActionsGridLayout() with all buttons from spec
- [ ] Button event handlers with validation if specified
- [ ] Grid column definitions if Section 4 checked
- [ ] If CardsGrid: `CardsGridParentContainer` set and matching a named container in `BuildPageLayout`
- [ ] If CardsGrid: `GetCardsGridItemsSourceBinding()` returns correct ViewModel path
- [ ] If CardsGrid: `GetCardsGridTapAction()` / `GetCardsGridEmptyViewText()` overridden if needed

### DILoader:
- [ ] Controller registration with AddTransient
- [ ] Page registration with AddTransient
- [ ] Correct namespaces and type names

### AppController:
- [ ] Route registration with correct hierarchy
- [ ] Route matches spec Parent Screen

---

## Error Handling

### If Specification is Incomplete:

**DO NOT GUESS**. Instead:

1. **List missing information**:
   ```
   ⚠️ Specification incomplete. Please provide:
   - Field X: Missing data type
   - Button Y: Missing action type (Navigation or Server Call?)
   - ValueList Z: Missing source table name
   ```

2. **Wait for user clarification**

3. **Do not proceed until complete**

### If Specification is Ambiguous:

**ASK for clarification**:

```
⚠️ Specification unclear. Please clarify:
- Field "Status": Should this be a Combobox or Entry?
- Button "Submit": Should this validate before proceeding?
- Navigation: Is this a root screen or child of {ParentScreen}?
```

### If Pattern is Not in Guide:

**DO NOT INVENT**. Instead:

```
⚠️ Requested feature not in standard patterns:
- Feature: {Feature description}
- This requires custom implementation beyond standard patterns
- Please confirm if this should be implemented as custom code
```

---

## Examples

### Example Input (Spec Summary):

```
Screen: ProductSearchPage
- 3 fields: PRODUCTCODE (Entry), PRODUCTNAME (Entry), CATEGORYCODE (Combobox)
- 1 value list: PRODUCTCATEGORY
- 1 button: Search (calls BVProductSummary.Refresh)
- 1 grid: 3 columns (Product Code, Product Name, Category)
```

### Example Output Summary:

```
Generated 7 files:
1. SQL: screens-defs-ProductSearchPage.sql
   - 3 DATADISPLAYDATADEFINITION entries
   - 1 DATADISPLAYVALUELISTDEFINITION entry

2. Constants: ScreenNames.cs additions
   - Added: ProductSearch = "ProductSearch"

3. Constants: BPNames.cs additions
   - Added: BVProductSummary = "BVProductSummary"

4. ViewModel: models/product/ProductSearchViewModel.cs
   - Inherits: GridViewModel (has grid)

5. Controller: pages/product/ProductSearchPageController.cs
   - Field constants: 3 fields
   - Method: CallSearchProductsAsync()

6. Page: pages/product/ProductSearchPage.cs
   - Layout: Form + Button + Grid
   - Button: Search with server call

7. DILoader additions: 2 registrations
8. AppController additions: 1 route
```

---

## Usage Instructions

### For User/Developer:

1. **Fill specification template** (TEMPLATE_Screen_Specification.md)
2. **Provide filled spec** to this agent
3. **Review generated files**
4. **Execute SQL script** on database
5. **Add generated C# files** to project
6. **Apply DILoader changes**
7. **Apply AppController changes**
8. **Build and test**

### For Agent (Internal Workflow):

1. **Receive specification**
2. **Validate completeness** (use Validation Checklist)
3. **Generate SQL metadata** (follow exact patterns)
4. **Generate ViewModel** (select correct base class)
5. **Generate Controller** (follow structure template)
6. **Generate Page** (follow structure template)
7. **Generate DILoader additions** (exact format)
8. **Generate AppController additions** (exact format)
9. **Validate output** (use Validation Checklist)
10. **Provide files to user** (with instructions)

---

## Agent Strictness Level: MAXIMUM

- ⚠️ **NEVER** add features not in spec
- ⚠️ **NEVER** deviate from guide patterns
- ⚠️ **NEVER** make assumptions about missing data
- ⚠️ **NEVER** create custom implementations
- ⚠️ **ALWAYS** follow exact naming conventions
- ⚠️ **ALWAYS** use exact template structures
- ⚠️ **ALWAYS** ask when unclear
- ⚠️ **ALWAYS** validate before delivering

---

## Success Criteria

Generated code is successful if:

1. ✅ **Compiles without errors** (all namespaces, types correct)
2. ✅ **Follows ALL patterns** from MOBILE_SCREEN_CREATION_GUIDE.md
3. ✅ **Matches specification exactly** (no additions, no omissions)
4. ✅ **SQL metadata is complete** (all tables have required entries)
5. ✅ **Navigation works** (route is registered, parameters passed correctly)
6. ✅ **Validation works** (if specified, triggers before actions)
7. ✅ **Conditional visibility works** (if specified, fields show/hide correctly)
8. ✅ **Server calls work** (BP and Method names are correct)

---

## Agent Version
**Version**: 1.0
**Last Updated**: 2025
**Based On**:
- MOBILE_SCREEN_CREATION_GUIDE.md (Complete Reference Guide)
- TEMPLATE_Screen_Specification.md (Specification Template)
- SPEC_RegistrationRequestLineDetailsPage.md (Example Reverse-Engineered Spec)

---

## Quick Reference: Key Patterns

### Naming Conventions:
- **Screen Name**: `{Feature}{Purpose}Page` (e.g., ProductSearchPage)
- **Controller Name**: `{ScreenName}PageController`
- **ViewModel Name**: `{ScreenName}ViewModel`
- **Field Constants**: Centralized in `ModelFields.{FeatureName}.cs` (NOT nested in controllers)
- **Methods**: `Call{Action}Async()`, `Build{Target}NavigationRoute()`

### File Locations:
- **SQL**: `pages/screens-defs-{ScreenName}.sql`
- **ViewModel**: `models/{feature}/{ScreenName}ViewModel.cs`
- **Controller**: `pages/{feature}/{ScreenName}PageController.cs`
- **Page**: `pages/{feature}/{ScreenName}Page.cs`
- **Constants**: `constants/{ConstantType}.cs`
- **Field Constants**: `constants/ModelFields.cs` (base) + `constants/ModelFields.{FeatureName}.cs` (feature-specific)

### ModelFields Usage Pattern:
```csharp
// In Controller/Page imports:
using static client.mobile.s4wes.constants.ModelFields;

// Usage:
FiltersHelper.ExtractFilters(filters, [
    Common.REFERENCEKEY,          // Common fields
    PickRequest.QTYTOPICK,        // Feature-specific fields
    Location.LOCATIONCODE         // Domain-specific fields
]);
```

### Base Classes:
- **GridViewModel**: For screens with data grids
- **DynamicViewModel**: For form-only screens
- **BaseViewModel**: Only if custom requirements

### Control Types (Auto-determined from DataType):
- String + ValueList → Combobox
- String → Entry
- Double → NumericEntry (auto)
- DateTime → DatePicker (auto)
- Boolean → Switch (auto)
- Unknown → Label

### Override Control Types (via CONTROLTYPE in DATAPANELAPPEARANCEDEFINITION):
These override the auto-determined type. Set in the `CONTROLTYPE` column:
- **ChipGroup** — Editable multi-select chip group (requires ValueList on the field)
- **Chip** — Display-only chip/badge (e.g., status indicator)
- **CaptionValue** — Framed box with caption label above a bound value label
- **InlineCaptionLabel** — Horizontal caption + value side-by-side
- **Separator** — Thin horizontal line

### Control Parameters (via CONTROLPARAMS in DATAPANELAPPEARANCEDEFINITION):
Semicolon-separated `key='value'` pairs for additional customization:
- `EntryStyleName='StyleName'` — Override the control style
- `ConverterProfile='ProfileName'` — Chip converter profile for text/background/text-color

### ⚠️ Chip + ReadOnly:
- When CONTROLTYPE is `Chip`, READONLY **must be 0** — ReadOnly=1 causes DevExpress to force default styling, overriding converter color bindings

### Field Icons:
- Use `IMAGENAME` column to specify icon/image name for fields
- Example: `'confirmedQty'`, `'dropId'`
- Set to NULL or omit if no icon needed

### Expression Syntax:
- Field reference: `~FIELDNAME~`
- Empty check: `isemptyornull(~FIELDNAME~)`
- Comparison: `~FIELD~=1`, `~FIELD~>0`
- Logical: `||` (OR), `&&` (AND)

---

## Final Note

This agent is designed to be **deterministic** and **predictable**. Given the same specification, it should always generate the same code. It does not "get creative" or "improve" the design - it strictly implements what is specified, following established patterns exactly.

If you find the agent deviating from this behavior, it is a bug. Report it immediately.
