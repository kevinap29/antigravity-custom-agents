# 🎯 Antigravity Custom Agents — Prompt Cheatsheet

🌐 **English** | [Bahasa Indonesia](CHEATSHEET.id.md)

Quick reference of real-world prompts to trigger each agent and workflow in **Antigravity / Gemini CLI**.

---

## 1. New Fullstack Feature (.NET CQRS + SvelteKit) — `sdlc-team-lead`

Use Main Agent `sdlc-team-lead` for end-to-end features so planning, backend, frontend, and QA are automatically coordinated.

```text
@sdlc-team-lead I want to add an Employee Shift Management feature:
- Backend (.NET 8 CQRS): GET/POST/PUT /api/shifts endpoints with overlap validation.
- Database (SQLite WAL): `shifts` table (DB-first, create a standalone SQL script).
- Frontend (SvelteKit + Tailwind): `/shifts` page with an add/edit modal form.
Create a plan in .gemini/plans/ first, delegate implementation, and finish with a QA review.
```

---

## 2. Legacy ASP.NET WebForms Maintenance & Features — `dotnet-webforms-dev`

Ideal for `.NET Framework 4.x` projects (`.aspx`, `.ascx`, `.aspx.cs`, `.designer.cs`, `Web.config`, EF6/ADO.NET).

```text
@dotnet-webforms-dev Add an "Approval Status" filter dropdown to `Pages/ApprovalList.aspx` and bind it to the `GridView` in `ApprovalList.aspx.cs`.
Ensure `.designer.cs` stays synced and non-SDK `.csproj` entries remain intact without breaking ViewState or existing events.
```

---

## 3. DB-First Design & T-SQL — `db-data-engineer`

Use for table schemas, indexing, stored procedures, or SQLite/SQL Server query optimization (no Code-First migrations).

```text
@db-data-engineer Create DB-first SQL scripts for SQL Server:
1. `InventoryTransactions` table with composite index `(WarehouseId, CreatedAt DESC)`.
2. Atomic stored procedure `usp_RecordStockMovement` (transaction + negative stock validation).
Do not execute SQL directly against the database; save scripts to `database/scripts/` for review.
```

---

## 4. Portainer Stack, Docker & Harbor CI/CD — `devops-git-ops`

Use for RAM-efficient multi-stage `Dockerfile`, Portainer-friendly `docker-compose.yml`, GitHub Actions pushing to Harbor, or `systemd`/`cloudflared`.

```text
@devops-git-ops Prepare deployment configs for this .NET 8 API service:
1. Multi-stage `Dockerfile` with a non-root user.
2. Portainer-friendly `docker-compose.yml` (named volumes, healthcheck, log rotation, mem_limit 512m).
3. `.github/workflows/build-push-harbor.yml` to build and push images tagged with commit SHA & semver to Harbor registry.
```

---

## 5. PR Review, Security & Zero-Regression — `qa-code-reviewer` & `pr-review-fixer`

- **Pre-merge quality & regression audit (`qa-code-reviewer`):**
  ```text
  @qa-code-reviewer Audit changes on the current branch against `main`.
  Verify API vs SvelteKit DTO contract sync, check for N+1 queries and IDisposable leaks, and run `verify-gate.mjs` / `dotnet test` / `npm run check`.
  ```
- **Execute PR bot/reviewer comments (`pr-review-fixer`):**
  ```text
  @pr-review-fixer Here are the review comments on PR #42:
  1. [File: OrderHandler.cs:58] Use an atomic transaction when updating stock and order status.
  2. [File: +page.svelte:112] Handle 409 Conflict API error state.
  Fix with minimal diff, re-run tests, and draft copy-ready markdown replies for each comment.
  ```

---

## 6. Standalone HTML Prototype — `ui-prototyper`

Use before writing SvelteKit or Blazor code to validate layout & UX quickly (aligned with the project's CSS/icon/chart packages).

```text
@ui-prototyper Create an interactive standalone HTML prototype (matching our project's CSS/icon packages) for the "Ticket Monitoring Dashboard" page.
Include status filters, real-time search bar, responsive table, and a ticket detail slide-over with realistic dummy data.
```
