# 🎯 Antigravity Custom Agents — Prompt Cheatsheet

🌐 [English](CHEATSHEET.md) | **Bahasa Indonesia**

Panduan cepat contoh prompt nyata untuk memicu masing-masing agent dan workflow di **Antigravity / Gemini CLI**.

---

## 1. Fitur Fullstack Baru (.NET CQRS + SvelteKit) — `sdlc-team-lead`

Gunakan Main Agent `sdlc-team-lead` saat membangun fitur end-to-end agar perencanaan, backend, frontend, dan QA terkoordinasi otomatis.

```text
@sdlc-team-lead Saya ingin menambah fitur Manajemen Shift Karyawan:
- Backend (.NET 8 CQRS): endpoint GET/POST/PUT /api/shifts dengan validasi bentrok jam.
- Database (SQLite WAL): tabel `shifts` (DB-first, buat skrip SQL terpisah).
- Frontend (SvelteKit + Tailwind): halaman `/shifts` dengan modal form tambah/edit.
Tolong buat plan dulu di .gemini/plans/, lalu delegasikan implementasi dan akhiri dengan QA review.
```

---

## 2. Fitur & Maintenance Legacy ASP.NET WebForms — `dotnet-webforms-dev`

Cocok untuk proyek `.NET Framework 4.x` (`.aspx`, `.ascx`, `.aspx.cs`, `.designer.cs`, `Web.config`, EF6/ADO.NET).

```text
@dotnet-webforms-dev Tambahkan kolom filter "Status Approval" pada halaman `Pages/ApprovalList.aspx` beserta binding ke `GridView` di `ApprovalList.aspx.cs`.
Pastikan sinkronisasi `.designer.cs` dan pendaftaran file di `.csproj` non-SDK tetap utuh tanpa merusak ViewState atau event eksisting.
```

---

## 3. Desain DB-First & T-SQL — `db-data-engineer`

Gunakan untuk merancang skema tabel, index, stored procedure, atau optimasi query SQLite/SQL Server (tanpa Code-First migration).

```text
@db-data-engineer Buatkan skrip SQL DB-first untuk SQL Server:
1. Tabel `InventoryTransactions` dengan index komposit `(WarehouseId, CreatedAt DESC)`.
2. Stored procedure `usp_RecordStockMovement` yang atomik (transaksi + validasi stok minus).
Jangan eksekusi SQL langsung ke database; simpan hasilnya ke folder `database/scripts/` untuk direview.
```

---

## 4. Portainer Stack, Docker & Harbor CI/CD — `devops-git-ops`

Gunakan untuk membuat `Dockerfile` multi-stage hemat RAM, `docker-compose.yml` ramah Portainer, workflow GitHub Actions ke Harbor, atau konfigurasi `systemd`/`cloudflared`.

```text
@devops-git-ops Siapkan konfigurasi deployment untuk service .NET 8 API ini:
1. `Dockerfile` multi-stage non-root user.
2. `docker-compose.yml` ramah Portainer Stack (named volume, healthcheck, log rotation, mem_limit 512m).
3. Workflow `.github/workflows/build-push-harbor.yml` untuk build dan push image bertag commit SHA & semver ke Harbor registry.
```

---

## 5. Review PR, Keamanan & Zero-Regression — `qa-code-reviewer` & `pr-review-fixer`

- **Audit kualitas & regresi sebelum merge (`qa-code-reviewer`):**
  ```text
  @qa-code-reviewer Lakukan audit perubahan pada branch saat ini terhadap `main`.
  Periksa sinkronisasi kontrak DTO API vs SvelteKit, potensi N+1 query, IDisposable, dan jalankan `dotnet test` serta `npm run check`.
  ```
- **Eksekusi komentar review PR bot/reviewer (`pr-review-fixer`):**
  ```text
  @pr-review-fixer Berikut daftar komentar review pada PR #42:
  1. [File: OrderHandler.cs:58] Gunakan transaksi atomik saat update stok dan status order.
  2. [File: +page.svelte:112] Tangani state error 409 Conflict dari API.
  Tolong perbaiki dengan minimal diff, jalankan ulang test, lalu buatkan draft balasan markdown siap salin untuk setiap komentar.
  ```

---

## 6. HTML Prototype Standalone — `ui-prototyper`

Gunakan sebelum menulis kode SvelteKit atau Blazor untuk validasi layout & UX dengan cepat.

```text
@ui-prototyper Buatkan prototipe UI interaktif standalone (1 file HTML sesuai CSS/icon library proyek) untuk halaman "Dashboard Monitoring Tiket".
Harus ada filter status, search bar real-time, tabel responsif, dan slide-over detail tiket dengan data dummy yang realistis.
```
