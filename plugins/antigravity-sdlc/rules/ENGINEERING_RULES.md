# SDLC Engineering Rules

- **DB-First Mandatory:** No Migration-First/Code-First (`dotnet ef migrations`, `dotnet ef database update`), no direct DB CLI execution (`sqlcmd`, `sqlite3`, `psql`, `mysql`), and use LINQ/EF when already present (no raw SQL template strings).
- **Git Branching:** Never push directly to `main`, `master`, or `develop`; always work on feature branches and open a PR.
- **UI Dropdown Component:** Whenever implementing an HTML dropdown element, ALWAYS build a **custom searchable dropdown component** with a built-in search input inside the dropdown panel and **debounced** filtering/querying (e.g., 250–300ms) instead of a plain native `<select>`.
- **Token Efficiency:** Read only task-relevant files; avoid full-repo scans unless necessary.
- **DRY & Reuse:** Check existing helpers, validators, or queries before adding new ones.
- **Zero Regression:** Preserve existing contracts and run relevant test suites before finishing.
- **KISS & Atomic:** Write the simplest valid solution; ensure atomic DB mutations (transactions / affected-row checks) and proper `IDisposable` cleanup.
- **Doc Sync & Pruning:** Update or remove stale docs/comments when adding, changing, or deleting features.
- **AGENTS.md Hygiene:** Keep repo `AGENTS.md` <= 4 KB (~1,000 tokens); during Phase 0, if bloated (`> 4.5 KB`, ASCII diagrams, or global-rule duplicates), include auto-splitting details into `docs/` with 1-line pointers in the plan and execute once approved.
- **PowerShell & RTK:** In Windows PowerShell, use `;` (not `&&`) to chain commands. If `curl` payloads or compile errors are condensed by RTK, use `rtk recall <hash>`, `rtk bypass <cmd>`, or `Invoke-RestMethod`.
