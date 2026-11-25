---
name: dotnet-webforms-patterns
description: Implementation patterns and static verification checklist for legacy .NET Framework (4.x) and ASP.NET WebForms (.aspx, .ascx, .aspx.cs, .designer.cs, non-SDK .csproj, EF6/LINQ/ADO.NET). Use when creating or modifying WebForms pages/controls.
---

# ASP.NET WebForms Patterns & Checklist

Use these patterns to keep new and updated WebForms code compatible with Visual Studio / `msbuild` without regressions.

## 1. Non-SDK `.csproj` Sync (.NET Framework)
Every new file in a Web Application Project (non-SDK `.csproj`) **must** be registered for `msbuild` compilation:

```xml
<ItemGroup>
  <Content Include="Pages\StockReport.aspx" />
  <Compile Include="Pages\StockReport.aspx.cs">
    <DependentUpon>StockReport.aspx</DependentUpon>
    <SubType>ASPXCodeBehind</SubType>
  </Compile>
  <Compile Include="Pages\StockReport.aspx.designer.cs">
    <DependentUpon>StockReport.aspx</DependentUpon>
  </Compile>
</ItemGroup>
```

## 2. `.aspx` & `.aspx.designer.cs` Sync
Every `runat="server"` control in `.aspx`/`.ascx` (e.g., `<asp:TextBox ID="txtCode" runat="server" />`, `<asp:Button ID="btnSave" runat="server" />`) must have a matching `protected` declaration in `*.aspx.designer.cs`:

```csharp
protected global::System.Web.UI.WebControls.TextBox txtCode;
protected global::System.Web.UI.WebControls.Button btnSave;
```

## 3. Page Lifecycle, Anti-XSS & ViewState
- Wrap initial data loading in `if (!IsPostBack)` so user inputs and postback events are not overwritten.
- Use `<%: Eval("Name") %>` or `HttpUtility.HtmlEncode(...)` for all text output; never use raw `<%= ... %>` or `Response.Write` for user/DB data.
- Set `EnableViewState="false"` on read-only display controls or large `Repeater`/`GridView` controls when postback state is unnecessary.
- Check `if (!Page.IsValid) return;` in submit button event handlers.

## 4. Data Access: EF6 / LINQ First & Safe ADO.NET
- **EF6 / LINQ to SQL (Prefer when present):**
  - Use `using (var db = new AppDbContext())`, `.AsNoTracking()` for read queries, and LINQ without raw SQL template strings.
  - Never trigger `Add-Migration` / `Enable-Migrations`.
- **ADO.NET (Only when module lacks EF/LINQ):**
  - Validate inputs before opening connections (**Validate-Before-Allocate**).
  - Wrap `SqlConnection`, `SqlCommand`, `SqlTransaction`, and `SqlDataReader` in `using` (**Single-Owner Cleanup**).
  - Use typed parameters: `cmd.Parameters.Add("@Code", SqlDbType.VarChar, 50).Value = code;` (avoid string concatenation and `AddWithValue` on type-sensitive indexed columns).

## 5. Static Verification Checklist (When `msbuild` Is Unavailable in Sandbox)
1. All new `.aspx`/`.ascx`/`.cs`/`.designer.cs` files are registered in `.csproj`.
2. `CodeBehind` & `Inherits` in `<%@ Page ... %>` match namespace & class in `.aspx.cs` 100%.
3. Every `runat="server"` control `ID` referenced in `.aspx.cs` exists with matching type in `.designer.cs`.
4. No leaked `SqlConnection`/`DbContext` without `using`, and no `<%=` for dynamic data.

## 6. Legacy Architecture, Testability & Security Guardrails
- **Respect Legacy Patterns:** Follow existing `BasePage`, `MasterPage`, UserControl (`.ascx`), Handler (`.ashx`), and BLL/DAL patterns. Never force .NET Core patterns (CQRS/MediatR/Minimal API) or unrequested NuGet packages.
- **Fail-Closed Auth & Session:** Preserve auth/role/session checks and `ViewStateUserKey` in `Page_Init`/`Page_Load` or `.ashx` (no fail-open endpoints/WebMethods).
- **DRY & Anti-Wrong Abstraction (Rule of Three):** Check `BasePage`, `.ascx`, `App_Code`/Helpers, and `Web.config` `appSettings` first. Avoid merging distinct business flows via boolean flags; split incrementally using **Inline & Split** (`[Obsolete]` if callers are widespread).
- **Legacy Testability & Dependency-Breaking:** Before refactoring untested legacy logic, lock behavior with a **Characterization Test** (if test project exists). Isolate new features from monolithic methods via **Sprout Method** / **Wrap Method**, and decouple pure business logic from `Page`/`Session`/`HttpContext`/`DateTime.Now` via **Extract Interface**, **Parameterize Constructor/Method**, or **`Func<>` injection**.
