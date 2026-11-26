# SDLC Engineering Rules

- **DB-First Mandatory:** No Migration-First/Code-First (`dotnet ef migrations`, `dotnet ef database update`), no direct DB CLI execution (`sqlcmd`, `Invoke-Sqlcmd`, `sqlite3`, `psql`, `mysql`, `sqlpackage`), and use LINQ/EF when already present (no raw SQL template strings).
- **Git Branching & Safety:** Never push directly to `main`, `master`, or `develop`, and never run `git push --force`, `git reset --hard`, or `git clean -fd` autonomously; always work on feature branches and open a PR.
- **UI Dropdown Component (Pragmatic KISS):** For **dynamic / API-backed / master-data** dropdowns or lists with **`> 7` options**, ALWAYS build/reuse a **custom searchable dropdown** with an internal search input and **debounced** filtering (250–300ms). For small static option sets (`<= 7` items, e.g., Status, Sort, Page Size), a native `<select>` or radio/segmented control is allowed.
- **Token Efficiency:** Read only task-relevant files; avoid full-repo scans unless necessary.
- **DRY & Reuse:** Check existing helpers, validators, or queries before adding new ones.
- **Zero Regression:** Preserve existing contracts and run relevant test suites before finishing.
- **KISS & Atomic:** Write the simplest valid solution; ensure atomic DB mutations (transactions / affected-row checks) and proper `IDisposable` cleanup.
- **Doc Sync & Pruning:** Update or remove stale docs/comments when adding, changing, or deleting features.
- **AGENTS.md Hygiene:** Keep repo `AGENTS.md` <= 4 KB (~1,000 tokens); during Phase 0, if bloated (`> 4.5 KB`, ASCII diagrams, or global-rule duplicates), include auto-splitting details into `docs/` with 1-line pointers in the plan and execute once approved.
- **PowerShell & RTK:** In Windows PowerShell, use `;` (not `&&`) to chain commands. If `curl` payloads or compile errors are condensed by RTK, use `rtk recall <hash>`, `rtk bypass <cmd>`, or `Invoke-RestMethod`.
