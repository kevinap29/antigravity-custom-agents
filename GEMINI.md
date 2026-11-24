# Global Developer Profile & Rules

## Tech Stack
- **Backend (.NET):** C#, .NET Core / .NET 6–11, ASP.NET Core, LINQ / EF Core, and legacy .NET Framework / ASP.NET WebForms (`.aspx`, `.ascx`, `.aspx.cs`).
- **Architecture:** CQRS (custom mediator), Vertical Slice Architecture, Domain-Driven Design (DDD), and existing legacy WebForms patterns.
- **Frontend & Mobile:** TypeScript, Svelte, SvelteKit, Tailwind CSS, .NET MAUI Hybrid Blazor (Android/Desktop), and standalone HTML + Tailwind CDN for prototyping.
- **Database:** SQLite (`ISqliteConnectionFactory`, WAL mode, batch insert) and SQL Server (T-SQL, stored procedures, indexing). DB-first mandatory: **no Migration-First/Code-First**, **no direct SQL execution by agents**, and **use LINQ/EF** when already present (no raw SQL template strings).
- **DevOps & Infra:** Ubuntu Linux VPS (RAM-efficient Docker / Portainer / Harbor / `systemd` / `cloudflared`), GitHub Actions (CI/CD & `.NET MAUI Hybrid Blazor` builds).

## Coding Guardrails
- **Token Efficiency:** Read only task-relevant files; avoid full-repo scans unless necessary.
- **DRY & Reuse:** Check existing helpers, validators, or queries before adding new ones.
- **Zero Regression:** Preserve existing contracts and run relevant test suites before finishing.
- **KISS & Atomic:** Write the simplest valid solution; ensure atomic DB mutations (transactions / affected-row checks) and proper `IDisposable` cleanup.
- **Doc Sync & Pruning:** Update or remove stale docs/comments when adding, changing, or deleting features.
- **PowerShell & RTK:** In Windows PowerShell, use `;` (not `&&`) to chain commands. If `curl` payloads or compile errors are condensed by RTK, use `rtk recall <hash>`, `rtk bypass <cmd>`, or `Invoke-RestMethod`.

## Communication & Language
- **Response Language:** Always respond to the user in English.
- **Tone:** Direct, concise, technical; no filler or redundant recaps.
