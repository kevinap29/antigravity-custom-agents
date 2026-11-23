# Project Agent Instructions (Starter Template)

> Salin file ini ke root proyek tim Anda sebagai `AGENTS.md` dan sesuaikan bagian yang relevan.

## Tech Stack
- **Backend:** `[C# .NET 8/9 CQRS | ASP.NET WebForms .NET 4.x]`
- **Frontend / Mobile:** `[SvelteKit + TypeScript + Tailwind | .NET MAUI Hybrid Blazor]`
- **Database:** `[SQLite (WAL mode) | SQL Server (T-SQL)]`

## Build & Test Commands
- **Backend Build:** `dotnet build` *(atau `msbuild /t:Build /p:Configuration=Debug` untuk WebForms)*
- **Backend Test:** `dotnet test`
- **Frontend Check & Build:** `npm ci && npm run check && npm run build`

## Project Rules (Wajib)
1. **DB-First Only:** Dilarang menggunakan Migration-First / Code-First; seluruh perubahan skema melalui skrip SQL/T-SQL resmi.
2. **Data Access:** Gunakan `[EF Core / LINQ / ISqliteConnectionFactory + Dapper]` sesuai pola proyek yang sudah ada tanpa raw SQL template string.
3. **Zero Regression & DRY:** Cek helper/handler eksisting sebelum membuat kode baru, pertahankan kontrak API, dan jalankan test sebelum selesai.
4. **Doc Sync:** Perbarui `README.md` / `AGENTS.md` saat menambah endpoint, env variable, atau alur deployment baru.
