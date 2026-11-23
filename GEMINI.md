# Global Developer Profile & Rules

## Tech Stack
- **Backend (.NET):** C#, .NET Core / .NET 6–11, ASP.NET Core, LINQ / EF Core, serta legacy .NET Framework / ASP.NET WebForms (`.aspx`, `.ascx`, `.aspx.cs`).
- **Architecture:** CQRS (custom mediator), Vertical Slice Architecture, Domain-Driven Design (DDD), serta arsitektur legacy WebForms eksisting.
- **Frontend & Mobile:** TypeScript, Svelte, SvelteKit, Tailwind CSS, .NET MAUI Hybrid Blazor (Android/Desktop), serta standalone HTML + Tailwind CDN untuk prototyping.
- **Database:** SQLite (`ISqliteConnectionFactory`, WAL mode, batch insert) dan SQL Server (T-SQL, stored procedures, indexing). DB-first wajib: **dilarang Migration-First/Code-First**, **dilarang eksekusi SQL langsung oleh agent**, dan **wajib gunakan LINQ/EF** jika sudah ada di proyek (tanpa raw SQL template string).
- **DevOps & Infra:** Ubuntu Linux VPS (hemat RAM, Docker / Portainer / Harbor / `systemd` / `cloudflared`), GitHub Actions (CI/CD & build `.NET MAUI Hybrid Blazor`).

## Coding Guardrails (Wajib)
- **Token Efficiency:** Baca hanya file terkait tugas; hindari full-repo scan jika tidak diperlukan.
- **DRY & Reuse:** Cek helper, validator, atau query eksisting sebelum membuat fungsi baru.
- **Zero Regression:** Pertahankan kontrak eksisting dan jalankan test suite terkait sebelum selesai.
- **KISS & Atomic:** Tulis solusi paling sederhana; pastikan mutasi DB atomik (transaksi / cek affected rows) dan IDisposable tertutup.
- **Doc Sync & Pruning:** Update atau hapus dokumentasi/komentar usang di proyek saat menambah, mengubah, atau menghapus fitur.
- **PowerShell & RTK:** Di Windows PowerShell, gunakan `;` (bukan `&&`) saat mem-batch command. Jika payload `curl` atau detail error compile diringkas RTK, gunakan `rtk recall <hash>`, `rtk bypass <cmd>`, atau `Invoke-RestMethod`.
