---
name: dotnet-webforms-patterns
description: Referensi pola implementasi & verifikasi statis untuk proyek legacy .NET Framework (4.x) dan ASP.NET WebForms (.aspx, .ascx, .aspx.cs, .designer.cs, .csproj non-SDK, EF6/LINQ/ADO.NET). Gunakan saat membuat atau memodifikasi halaman/kontrol WebForms.
---

# ASP.NET WebForms Patterns & Checklist

Gunakan pola ini agar kode WebForms baru maupun perbaikan tetap kompatibel dengan Visual Studio / `msbuild` tanpa regresi.

## 1. Sinkronisasi `.csproj` Non-SDK-Style (.NET Framework)

Setiap file baru pada Web Application Project (`.csproj` non-SDK) **harus** didaftarkan agar ikut dikompilasi `msbuild`:

```xml
<ItemGroup>
  <Content Include="Pages\LaporanStok.aspx" />
  <Compile Include="Pages\LaporanStok.aspx.cs">
    <DependentUpon>LaporanStok.aspx</DependentUpon>
    <SubType>ASPXCodeBehind</SubType>
  </Compile>
  <Compile Include="Pages\LaporanStok.aspx.designer.cs">
    <DependentUpon>LaporanStok.aspx</DependentUpon>
  </Compile>
</ItemGroup>
```

## 2. Sinkronisasi `.aspx` & `.aspx.designer.cs`

Setiap kontrol `runat="server"` baru di `.aspx`/`.ascx` (misal `<asp:TextBox ID="txtKode" runat="server" />` atau `<asp:Button ID="btnSimpan" runat="server" />`) harus punya deklarasi `protected` yang cocok di `*.aspx.designer.cs`:

```csharp
protected global::System.Web.UI.WebControls.TextBox txtKode;
protected global::System.Web.UI.WebControls.Button btnSimpan;
```

## 3. Page Lifecycle, Anti-XSS & ViewState

- Selalu bungkus load data awal di `if (!IsPostBack)` agar nilai input user & event postback tidak tertimpa.
- Gunakan `<%: Eval("Nama") %>` atau `HttpUtility.HtmlEncode(...)` untuk seluruh output teks; jangan memakai `<%= ... %>` atau `Response.Write` mentah untuk data input/DB.
- Set `EnableViewState="false"` pada kontrol display read-only / `Repeater` / `GridView` besar bila tidak butuh mempertahankan state antar postback.
- Cek `if (!Page.IsValid) return;` pada event handler tombol submit.

## 4. Data Access: EF6 / LINQ First & Safe ADO.NET

- **EF6 / LINQ to SQL (Utamakan jika sudah ada di proyek):**
  - Gunakan `using (var db = new AppDbContext())`, `.AsNoTracking()` untuk query baca, dan LINQ tanpa raw SQL template string.
  - Dilarang memicu `Add-Migration` / `Enable-Migrations`.
- **ADO.NET (Hanya jika modul tidak memakai EF/LINQ):**
  - Validasi input dulu sebelum membuka koneksi (**Validate-Before-Allocate**).
  - Gunakan `using` untuk `SqlConnection`, `SqlCommand`, `SqlTransaction`, dan `SqlDataReader` (**Single-Owner Cleanup**).
  - Gunakan `cmd.Parameters.Add("@Kode", SqlDbType.VarChar, 50).Value = kode;` (hindari string concatenation dan hindari `AddWithValue` untuk kolom berindeks yang sensitif tipe).

## 5. Checklist Verifikasi Statis (Saat `msbuild` Tidak Tersedia di Sandbox)

1. Semua file baru `.aspx`/`.ascx`/`.cs`/`.designer.cs` sudah tercantum di `.csproj`.
2. `CodeBehind` & `Inherits` pada directive `<%@ Page ... %>` cocok 100% dengan namespace & class di `.aspx.cs`.
3. Seluruh `ID` kontrol `runat="server"` yang diakses di `.aspx.cs` ada dan bertipe sama di `.designer.cs`.
4. Tidak ada `SqlConnection`/`DbContext` yang bocor tanpa `using`, dan tidak ada `<%=` untuk data dinamis.

## 6. Legacy Architecture, Testability & Security Guardrails

- **Respect Legacy Patterns:** Gunakan pola `BasePage`, `MasterPage`, UserControl (`.ascx`), Handler (`.ashx`), dan BLL/DAL eksisting. Jangan memaksakan pola .NET Core (CQRS/MediatR/Minimal API) atau menambah NuGet yang tidak diminta.
- **Fail-Closed Auth & Session:** Pertahankan validasi auth/role/session dan `ViewStateUserKey` di `Page_Init`/`Page_Load` atau `.ashx` (tidak ada endpoint/WebMethod yang fail-open).
- **DRY & Anti-Wrong Abstraction (Rule of Three):** Cek `BasePage`, `.ascx`, `App_Code`/Helper, dan `Web.config` `appSettings` sebelum membuat helper baru. Hindari menggabungkan dua alur bisnis berbeda lewat boolean flag; pecah bertahap dengan **Inline & Split** (`[Obsolete]` bila pemanggil tersebar).
- **Legacy Testability & Dependency-Breaking:** Sebelum refactor logic legacy tanpa unit test, kunci perilaku dengan **Characterization Test** (bila test project ada). Isolasikan fitur baru dari method raksasa memakai **Sprout Method** / **Wrap Method**, dan pisahkan pure business logic dari `Page`/`Session`/`HttpContext`/`DateTime.Now` via **Extract Interface**, **Parameterize Constructor/Method**, atau **`Func<>` injection**.
