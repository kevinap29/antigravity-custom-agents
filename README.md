![Verify Repository](https://github.com/kevinap29/antigravity-custom-agents/actions/workflows/verify.yml/badge.svg)

# 🚀 Antigravity Custom Agents & Modular Plugins

🌐 **English** | [Bahasa Indonesia](README.id.md)

[![Antigravity Agent](https://img.shields.io/badge/Antigravity-Custom%20Agents-blueviolet?style=flat-square)](https://github.com/kevinap29/antigravity-custom-agents)
[![.NET](https://img.shields.io/badge/.NET-6--11%20%7C%20WebForms%20%7C%20MAUI-512BD4?style=flat-square&logo=dotnet)](https://dotnet.microsoft.com/)
[![SvelteKit](https://img.shields.io/badge/SvelteKit-TypeScript%20%2B%20Tailwind-FF3E00?style=flat-square&logo=svelte)](https://kit.svelte.dev/)
[![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20SQL%20Server-003B57?style=flat-square&logo=sqlite)](https://www.sqlite.org/)
[![RTK](https://img.shields.io/badge/RTK-Token%20Optimizer-10B981?style=flat-square)](https://github.com/rtk-ai/rtk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Ready-to-use collection of **9 Custom Agents**, **2 Modular Plugins (`antigravity-sdlc` bundle + `rtk` Token Optimizer)**, **Deterministic Quality/Security Gate**, **Optional Central Memory MCP (Qdrant)**, and a **Slim Personal Developer Profile (`GEMINI.md`)** for **Antigravity / Gemini CLI**. Designed for full-stack SDLC workflows (.NET Core/CQRS, Legacy ASP.NET WebForms, SvelteKit, .NET MAUI Hybrid Blazor, SQLite/SQL Server, and Docker/Portainer/Harbor VPS).

---

## ⚡ Quickstart

Clone this repository and run the installer for your OS:

```bash
# Clone repository
git clone https://github.com/kevinap29/antigravity-custom-agents.git
cd antigravity-custom-agents

# Windows (PowerShell):
powershell -ExecutionPolicy Bypass -File .\install.ps1

# macOS / Linux:
chmod +x install.sh && ./install.sh
```

> **Note:** If installing from a `.zip` archive, extract it first and run `install.ps1` (Windows) or `./install.sh` (macOS/Linux) inside the extracted folder.

---

## ✨ Key Features (v2.1 Modular Plugin Bundle)

- **9 Structured Custom Agents:** 2 Main Agents (`sdlc-team-lead` & `pr-review-fixer`) and 7 domain-specialist Subagents.
- **Modular `antigravity-sdlc` Plugin (`plugins/antigravity-sdlc/`):**
  - **Bundled 3 Domain Skills (`skills/`):** Reusable patterns (WebForms, SvelteKit/MAUI, Portainer/Harbor) packaged cleanly inside the plugin.
  - **Auto-Updated Engineering Rules (`rules/ENGINEERING_RULES.md`):** Static rules (DB-first, Git branching, Searchable Dropdown, DRY/KISS, Zero Regression, Doc Sync, PowerShell & RTK) live in the plugin so `update` refreshes them cleanly without overwriting your personal `GEMINI.md`.
  - **Deterministic `PreToolUse` Guardrails (`hooks/sdlc-guardrails.mjs`):** Zero-dependency Node.js hook that blocks `git push` to `main`/`master`/`develop`, direct DB CLIs (`sqlcmd`, `sqlite3`, `psql`, `mysql`), and EF Core Code-First migrations (`dotnet ef migrations` / `dotnet ef database update`). Auto-disables safely if `node` is not installed.
- **Independent RTK Plugin (`plugins/rtk/`):** Standalone 3rd-party token optimizer hook (`rtk hook antigravity`) kept separate so it can be toggled or updated independently.
- **SDLC v1.5+ Architecture (`sdlc-team-lead`, `ui-prototyper`, `frontend-mobile-dev`, `qa-code-reviewer`):**
  - **5-Lane Complexity Matrix:** `Lane 0 (docs)` handled directly by Team Lead, `Lane 1A (micro < 30 lines)` skips plan file (direct single-file edit or `Model: flash` subagent), `Lane 1B (small <= 100 lines, no DB/DTO/Auth)` skips plan & ceremony using `Model: inherit` + `verify-gate.mjs`, and `Lane 2/3 (standard/complex)` runs full Phase 0–5.
  - **Contract Freeze Gate:** Parallel execution is only allowed after Phase 0 DTO contracts are finalized & pass the Ambiguity Gate, capped at **max 2 parallel subagents**.
  - **Conditional Prototype Fidelity & Package Alignment:** Phase 1 remains optional (skipped for backend-only/minor tasks). When a prototype is created (`_prototypes/<feature-slug>.html`), `ui-prototyper` aligns with the project's CSS/icon/chart packages + *Component Mapping Note*, followed by a *Prototype Approval Gate*, 1:1 conversion by `frontend-mobile-dev`, and *Prototype Parity Audit* by `qa-code-reviewer`.
  - **Progressive Model Escalation:** If `qa-code-reviewer` emits `[CRITICAL][ESCALATE_MODEL]` or a `flash` subagent fails on iteration 2+, Team Lead spawns a new subagent with a higher model tier (`flash` → `inherit` → `pro`).
- **Deterministic Quality & Security Gate (`plugins/antigravity-sdlc/scripts/verify-gate.mjs` + `verify-gate.ps1` wrapper):** Cross-platform Node.js single-source-of-truth gate auto-detecting `.NET` (Core/6–11, MAUI Blazor + unit tests, Legacy `.NET Framework` via `MSBuild`), `Node/SvelteKit` (monorepo-aware `npm run check`/`build`/`test` with Vitest detection), `Python` (`pytest`), plus static security scanners (`gitleaks`, `trivy`, and `semgrep` on Unix/macOS). Bundled inside `antigravity-sdlc` for sandboxed QA agents and mirrored to `~/.gemini/scripts/` by the installer for CLI convenience.
- **Optional Central Memory MCP (`mcp/central_memory_mcp.py` + Qdrant):** Cross-session semantic memory (`BAAI/bge-small-en-v1.5` local CPU embeddings via `fastembed` + 3 Qdrant modes: Local Embedded / Localhost Server / Remote VPS, `git_tree_hash` staleness protection), plus an optional auto-reconnecting SSH tunnel for restricted/office networks.
- **Optional Graphify Code-Graph Lookup (`sdlc-team-lead` & `qa-code-reviewer`):** Zero-overhead intra-repo structural map for `Lane 2/3` tasks (silently skipped if neither `graphify` MCP nor `graphify-out/GRAPH_REPORT.md` exists). Reads `GRAPH_REPORT.md` / queries MCP for god nodes, DRY helpers, and blast radius before broad scans, while `templates/.antigravityignore` excludes heavy raw artifacts (`graph.json`, `*.html`, `cache/`).
- **Modular Installer (Core + 3 Add-ons + OS/Env Preflight Check):** Auto-detects OS & installed tools (e.g., automatically skips `semgrep` on Windows, checks `node` for guardrails), auto-migrates legacy `config/skills/` bundle folders, and persists Add-on selections in `~/.gemini/.addons.json` for `update` & `verify`.
- **Token-Efficient English Prompts + Slim Personal Profile (`GEMINI.md`):** All `agents/*.md`, `plugins/antigravity-sdlc/skills/*/SKILL.md`, and `ENGINEERING_RULES.md` are written in concise bullet-style English, while `GEMINI.md` stays lightweight (only your Tech Stack, Response Language `-ResponseLanguage`/`--response-language`, and Tone).

---

## 📦 Repository Structure

```text
antigravity-custom-agents/
├── agents/                     # 9 custom agent definitions (.md, token-efficient English)
│   ├── sdlc-team-lead.md       # Main Agent: SDLC Architect & Coordinator
│   ├── pr-review-fixer.md      # Main Agent: PR / AI code review auto-fixer
│   ├── dotnet-cqrs-dev.md      # Subagent: C# / .NET Core / CQRS backend
│   ├── dotnet-webforms-dev.md  # Subagent: Legacy .NET Framework / ASP.NET WebForms
│   ├── frontend-mobile-dev.md  # Subagent: SvelteKit & .NET MAUI Hybrid Blazor
│   ├── db-data-engineer.md     # Subagent: SQLite (WAL) & SQL Server (T-SQL)
│   ├── devops-git-ops.md       # Subagent: Git, CI/CD, Docker/Portainer/Harbor, VPS
│   ├── ui-prototyper.md        # Subagent: Standalone HTML prototyping + Package Alignment
│   └── qa-code-reviewer.md     # Subagent: Code quality, build, security & parity auditor
├── plugins/                    # 2 independent Antigravity plugins
│   ├── antigravity-sdlc/       # Modular SDLC bundle (skills, rules, PreToolUse guardrails)
│   │   ├── plugin.json         # Plugin metadata (v2.1.0)
│   │   ├── hooks.json          # PreToolUse guardrail hook config (auto-resolved on install)
│   │   ├── hooks/
│   │   │   └── sdlc-guardrails.mjs # Node.js guardrail (protected branches, DB CLI, EF migrations)
│   │   ├── rules/
│   │   │   └── ENGINEERING_RULES.md # Static engineering guardrails (auto-updated)
│   │   ├── scripts/
│   │   │   ├── verify-gate.mjs # Cross-platform deterministic build/test + security gate
│   │   │   └── verify-gate.ps1 # Backward-compatible PowerShell wrapper for verify-gate.mjs
│   │   └── skills/             # 3 bundled domain skills
│   │       ├── dotnet-webforms-patterns/SKILL.md
│   │       ├── frontend-mobile-patterns/SKILL.md
│   │       └── portainer-harbor-deploy/SKILL.md
│   └── rtk/                    # Independent RTK token optimizer plugin
│       ├── plugin.json         # RTK plugin metadata
│       ├── hooks.json          # PreToolUse hook (rtk hook antigravity)
│       └── rules/AGENTS.md     # RTK usage & output recovery rules
├── scripts/                    # Optional SSH Tunnel scripts
│   ├── qdrant-tunnel.ps1       # Auto-reconnecting SSH tunnel (env/param-based)
│   └── qdrant-tunnel-hidden.vbs# Hidden Windows Task Scheduler launcher (%USERPROFILE%)
├── tests/                      # Automated unit & rule-drift tests (node --test + unittest)
│   ├── sdlc-guardrails.test.mjs # Guardrail hook regression tests
│   ├── verify-gate.test.mjs     # Monorepo & stack detection gate tests
│   └── test_central_memory_mcp.py # Central Memory MCP + rule consistency tests
├── mcp/                        # Central Memory MCP Server (Optional)
│   ├── central_memory_mcp.py   # Qdrant + fastembed MCP (git_tree_hash staleness check)
│   └── requirements.txt        # Python dependencies (qdrant-client[fastembed], fastmcp)
├── memory/                     # Global rules & architecture notes reference (Optional)
│   ├── GLOBAL_RULES.md
│   └── ARCHITECTURE_NOTES.md
├── templates/                  # Starter templates (project & personal profile)
│   ├── .antigravityignore      # Token-saving ignore rules (bin/, obj/, node_modules/, etc.)
│   ├── AGENTS.md               # Project conventions & build/test template
│   └── GEMINI.md               # Slim Personal Developer Profile template (installed to ~/.gemini/)
├── CHEATSHEET.md / .id.md      # Real-world prompt examples (English & Bahasa Indonesia)
├── mcp_config.example.json     # Example MCP config (context7, fetch, sqlite, central_memory)
├── install.ps1                 # Modular Windows Installer (Core + Add-ons + Env Check)
├── install.sh                  # Modular Linux / macOS Installer (Core + Add-ons + Env Check)
├── verify.ps1 / verify.sh      # Health-check for installed Core & Add-ons
├── update.ps1 / update.sh      # Sync & update bundle respecting ~/.gemini/.addons.json
├── uninstall.ps1 / uninstall.sh# Safe rollback removing only bundle components
├── LICENSE                     # MIT License
├── .gitignore
└── README.md / README.id.md    # Bilingual documentation (English & Bahasa Indonesia)
```

### Custom Agents Overview (9 Agents)

| Agent | Role | Primary Responsibility |
| :--- | :--- | :--- |
| `sdlc-team-lead` | **Main Agent** | Isolated per-feature planning, 5-Lane Matrix, auto stack detection, Contract Freeze Gate, conditional prototype handover, and Progressive Model Escalation. |
| `pr-review-fixer` | **Main Agent** | Quota-efficient single-agent executor for PR / AI code review comments with minimal-diff fixes and copy-ready markdown replies. |
| `dotnet-cqrs-dev` | Subagent | C#, .NET Core / .NET 6–11, ASP.NET Core, Vertical Slice Architecture, CQRS, custom mediator, LINQ/EF Core, and `ISqliteConnectionFactory` / Dapper. |
| `dotnet-webforms-dev` | Subagent | Zero-regression maintenance & features for legacy .NET Framework 4.x and ASP.NET WebForms (`.aspx`, `.ascx`, `.aspx.cs`, `.designer.cs`, `Web.config`, EF6/ADO.NET). |
| `frontend-mobile-dev` | Subagent | SvelteKit (UI, routing, server routes, Tailwind) and .NET MAUI Hybrid Blazor (Android/Desktop) with 1:1 Prototype Fidelity. |
| `db-data-engineer` | Subagent | DB-first SQL schemas, idempotent migrations, indexing, SQLite (WAL mode, batch SQL), and SQL Server (T-SQL, stored procedures). |
| `devops-git-ops` | Subagent | Git workflows, GitHub Actions CI/CD, Dockerfile & Portainer Stacks, Harbor registry, `systemd`, `cloudflared` on Ubuntu VPS, and `.NET MAUI Hybrid Blazor` CI/CD. |
| `ui-prototyper` | Subagent | Interactive standalone HTML prototypes aligned with the project's CSS framework, icon library, and chart library. |
| `qa-code-reviewer` | Subagent | Read-only quality & security audit, deterministic gate (`verify-gate.mjs` / `verify-gate.ps1`), API contract sync, Prototype Parity, DRY, Zero Regression, and Doc Sync. |

### Included Plugins (2 Modular Plugins)

1. **`plugins/antigravity-sdlc/` (SDLC Bundle — v2.1.0):**
   - **Bundled Skills (`skills/`):**
     - **`dotnet-webforms-patterns`**: Legacy .NET Framework 4.x / ASP.NET WebForms patterns & static verification (non-SDK `.csproj`, `.designer.cs` sync, EF6/LINQ/ADO.NET).
     - **`frontend-mobile-patterns`**: SvelteKit (Svelte 4 vs Svelte 5 runes) and .NET MAUI Hybrid Blazor (lifecycle, `BlazorWebView`, JS Interop, Windows target builds).
     - **`portainer-harbor-deploy`**: RAM-efficient Docker/Portainer Stack SOP on Ubuntu VPS and GitHub Actions workflows pushing to Harbor private registry.
   - **Engineering Rules (`rules/ENGINEERING_RULES.md`):** Auto-injected static guardrails (DB-first, Git branching, searchable dropdowns, DRY/KISS, Zero Regression, Doc Sync, PowerShell & RTK) updated automatically without touching your personal `GEMINI.md`.
   - **Deterministic `PreToolUse` Guardrails (`hooks/sdlc-guardrails.mjs`):** Zero-dependency Node.js hook blocking `git push` to `main`/`master`/`develop`, direct DB CLI invocations (`sqlcmd`, `sqlite3`, `psql`, `mysql`), and EF Core Code-First migrations (`dotnet ef migrations` / `dotnet ef database update`). Requires `node`; if unavailable, the installer safely sets `"enabled": false`.
2. **`plugins/rtk/` (RTK Token Optimizer — Independent):**
   - Provides `plugin.json`, `hooks.json`, and `rules/AGENTS.md` for transparent `PreToolUse` command rewriting (`rtk hook antigravity`) to condense verbose terminal output and save AI tokens.

> **Prerequisite for RTK:** Install the **`rtk`** CLI binary for full hook compression:
> - **Windows (`winget`):**
>   ```powershell
>   winget install --id rtk-ai.rtk -e
>   ```
>   *(Or pass `-InstallRtk` to `install.ps1`.)*
> - **Linux / macOS:**
>   - Homebrew: `brew install rtk`
>   - Cargo (Rust): `cargo install --git https://github.com/rtk-ai/rtk`
>   - Release binary: `https://github.com/rtk-ai/rtk/releases`

---

## 🚀 Automated Installation — Modular (Core + Add-ons)

The v2.0+ installer splits setup into **Core** (mandatory: `agents/`, `plugins/antigravity-sdlc/` including `scripts/verify-gate.mjs` & `verify-gate.ps1`, `plugins/rtk/`, `templates/GEMINI.md`) and **3 Optional Add-ons** with an automatic **OS/Environment Preflight Check**:
- **Add-on A (Security Scanners):** `gitleaks` & `trivy` (via `winget` on Windows; `semgrep` is automatically skipped on Windows due to lack of native support, and offered on Linux/macOS).
- **Add-on B (Central Memory MCP / Qdrant — 3 Modes):** Copies `mcp/` & `memory/`, checks Python 3 first, offers `.venv` + `requirements.txt` setup, and lets you choose from 3 Qdrant modes:
  - **`Local` (Embedded — Default):** Zero-setup, no VPS/Docker/service required; stores vectors in `~/.gemini/memory/qdrant_local` via `QDRANT_LOCAL_PATH` (automatically skips Add-on C).
  - **`Localhost` (Native Server `127.0.0.1:6333`):** Downloads the official Qdrant binary to `~/.gemini/bin/` + `qdrant-config.yaml` for multi-session access & local Web Dashboard without Docker (automatically skips Add-on C).
  - **`Remote` (VPS):** Uses `QDRANT_URL` + `QDRANT_API_KEY` (offers Add-on C SSH Tunnel on Windows).
- **Add-on C (Qdrant SSH Tunnel Auto-Start — Windows Only, `Remote` Mode):** Copies `scripts/qdrant-tunnel.ps1` & `scripts/qdrant-tunnel-hidden.vbs` for restricted/office networks.

Selections (`centralMemory`, `qdrantMode`, `sshTunnel`, `responseLanguage`) are persisted in `~/.gemini/.addons.json` so `update` and `verify` only manage the modules you chose.

### Windows (PowerShell)

```powershell
# Interactive mode (choose response language, Add-ons A/B/C & Qdrant mode):
powershell -ExecutionPolicy Bypass -File .\install.ps1

# Non-interactive with Central Memory Local Embedded (no VPS):
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GeminiMdMode Skip -ResponseLanguage "English" -WithSecurityTools -WithMemory -QdrantMode Local

# Non-interactive with Central Memory Remote VPS + SSH Tunnel:
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GeminiMdMode Skip -ResponseLanguage "English" -WithSecurityTools -WithMemory -QdrantMode Remote -WithTunnel
```

> **Windows Parameters (`install.ps1`):**
> - `-GeminiMdMode Prompt|Overwrite|Merge|Skip`
> - `-ResponseLanguage <Language>` (agent response language in `GEMINI.md`; default: `English`, interactive offers `English`, `Bahasa Indonesia`, or `Custom`)
> - `-InstallRtk` (install `rtk` CLI via `winget`)
> - `-WithSecurityTools` (install `gitleaks` & `trivy` via `winget`; `semgrep` is auto-skipped on Windows)
> - `-WithMemory` (install Central Memory MCP + `memory/*.md` + optional `.venv`)
> - `-QdrantMode Local|Localhost|Remote` (default: `Local` when `-WithMemory` is set)
> - `-WithTunnel` (install Windows Qdrant SSH Tunnel scripts; `Remote` mode only)

### Linux / macOS (Bash)

```bash
chmod +x install.sh
# Interactive mode:
bash install.sh

# Non-interactive with Add-ons (Local Embedded / Localhost / Remote):
bash install.sh --gemini-mode=skip --response-language="English" --with-security-tools --with-memory --qdrant-mode=local
```

> **Unix/macOS Parameters (`install.sh`):** `--gemini-mode=prompt|overwrite|merge|skip`, `--response-language=<lang>` (default: `English`), `--with-security-tools`, `--with-memory`, `--qdrant-mode=local|localhost|remote`.

---

## 📋 Windows Prerequisites & Advanced Setup (Optional)

### 1. Local Security Scanners (Deterministic Gate)
```powershell
winget install Gitleaks.Gitleaks
winget install AquaSecurity.Trivy
```
*(If not installed, `verify-gate.mjs` / `verify-gate.ps1` runs safely and skips unavailable scanners.)*

### 2. Central Memory MCP (Python 3.13 + Qdrant)
1. Ensure **Python 3.13** (or 3.10+) is installed, then create a virtual environment at `%USERPROFILE%\.gemini\mcp\.venv`:
   ```powershell
   python -m venv "$env:USERPROFILE\.gemini\mcp\.venv"
   & "$env:USERPROFILE\.gemini\mcp\.venv\Scripts\pip.exe" install -r "$env:USERPROFILE\.gemini\mcp\requirements.txt"
   ```
2. Copy the matching entry from `mcp_config.example.json` into `%USERPROFILE%\.gemini\antigravity\mcp_config.json`:
   - **`Local` (Embedded, no VPS):** use `central_memory_local` (set `QDRANT_LOCAL_PATH` to `<USER_HOME>/.gemini/memory/qdrant_local`, no `QDRANT_URL`/`QDRANT_API_KEY`).
   - **`Localhost` (Native Server):** use `central_memory` with `QDRANT_URL=http://127.0.0.1:6333` (start `~/.gemini/bin/qdrant(.exe) --config-path ~/.gemini/bin/qdrant-config.yaml`).
   - **`Remote` (VPS):** use `central_memory` and replace `<USER_HOME>`, `<QDRANT_URL>`, and `<QDRANT_API_KEY>`.

### 3. Auto-Start SSH Tunnel via Windows Task Scheduler (Office / Restricted Network)
1. Set user environment variables (one-time):
   ```powershell
   [Environment]::SetEnvironmentVariable("QDRANT_SSH_HOST", "<SSH_USER>@<VPS_IP>", "User")
   [Environment]::SetEnvironmentVariable("QDRANT_SSH_PORT", "22", "User")
   ```
2. Create a **Windows Task Scheduler** task named `Antigravity-Qdrant-Tunnel`:
   - **Trigger:** *At log on* (your user).
   - **Action:** *Start a program* → Program: `wscript.exe`, Arguments: `"%USERPROFILE%\.gemini\scripts\qdrant-tunnel-hidden.vbs"`.
   - Runs 100% hidden in the background (`127.0.0.1:6333` → VPS) with a named Mutex single-instance guard and auto-reconnect.

### 4. Native Qdrant (Non-Docker) on Ubuntu VPS
For RAM-constrained VPS without Docker:
1. Download the official Qdrant Linux static binary (`qdrant-x86_64-unknown-linux-musl.tar.gz`) to `/usr/local/bin/qdrant` and create `/etc/qdrant/config.yaml` binding **`host: 127.0.0.1`**, **`http_port: 6333`**, and `service.api_key: "<QDRANT_API_KEY>"`.
2. Run via `systemd` (`/etc/systemd/system/qdrant.service`) with **`MemoryMax=300M`**, `Restart=always`, then enable with `systemctl enable --now qdrant`.
3. Connect securely from your laptop over SSH port forwarding (`127.0.0.1:6333`) without exposing Qdrant publicly.

---

## 🛠️ Manual Installation

If you prefer copying files manually:
1. **Copy all agents (`agents/*.md`)** to both `~/.gemini/config/agents/` and `~/.gemini/antigravity/agents/` (symlink allowed).
2. **Copy `antigravity-sdlc` plugin (`plugins/antigravity-sdlc/`)** to `~/.gemini/config/plugins/antigravity-sdlc/` and replace `__HOOK_SCRIPT_PATH__` in its `hooks.json` with the absolute path to `hooks/sdlc-guardrails.mjs` (set `"enabled": false` if `node` is not installed).
3. **Copy RTK plugin (`plugins/rtk/`)** to `~/.gemini/config/plugins/rtk/`.
4. **(Optional CLI Mirror) Copy `plugins/antigravity-sdlc/scripts/verify-gate.mjs` & `verify-gate.ps1`** to `~/.gemini/scripts/` (sandboxed QA uses the copy inside `~/.gemini/config/plugins/antigravity-sdlc/scripts/`).
5. **Copy or merge `templates/GEMINI.md`** to `~/.gemini/GEMINI.md`.

---

## ✅ Verify, Update & Rollback

### 1. Health-Check (`verify`)
```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```
```bash
# macOS / Linux
bash verify.sh
```

### 2. Sync / Update Bundle (`update`)
```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\update.ps1
```
```bash
# macOS / Linux
bash update.sh
```

### 3. Rollback / Uninstall (`uninstall`)
```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
```bash
# macOS / Linux
bash uninstall.sh
```

---

## 🧩 Starter Templates, MCP & Cheatsheet

- **Real-World Prompt Examples ([CHEATSHEET.md](CHEATSHEET.md) | [Bahasa Indonesia](CHEATSHEET.id.md)):** 6 ready-to-use scenarios covering `sdlc-team-lead`, `dotnet-webforms-dev`, `db-data-engineer`, `devops-git-ops`, `qa-code-reviewer`, `pr-review-fixer`, and `ui-prototyper`.
- **Team Project Templates (`templates/`):**
  - Copy `templates/.antigravityignore` to your project root as `.antigravityignore` to keep build folders (`bin/`, `obj/`, `node_modules/`, `.svelte-kit/`, `*.db-wal`, etc.) out of context.
  - Copy `templates/AGENTS.md` to your project root as `AGENTS.md` and fill in your stack and build/test commands.
- **MCP Config (`mcp_config.example.json`):** Reference entries for `context7`, `fetch`, `sqlite`, `central_memory`, and `central_memory_local` to merge into `~/.gemini/antigravity/mcp_config.json`.

---

## ✅ Verifying Inside Antigravity / Gemini CLI

1. Restart **Antigravity** (or open a new Gemini CLI session).
2. Confirm `sdlc-team-lead` and `pr-review-fixer` appear in your agent list.
3. Run a quick smoke test with `sdlc-team-lead`:
   > *"List all available subagents and skills in my current setup."*
4. Verify all 7 subagents (`dotnet-cqrs-dev`, `dotnet-webforms-dev`, `frontend-mobile-dev`, `db-data-engineer`, `devops-git-ops`, `ui-prototyper`, `qa-code-reviewer`) and `GEMINI.md` guardrails are recognized.

---

## ❓ FAQ & Troubleshooting

- **PowerShell blocks `install.ps1` ("running scripts is disabled on this system"):**
  Run with `powershell -ExecutionPolicy Bypass -File .\install.ps1`.
- **Windows SymbolicLink permission error (`PrivilegeNotHeld`):**
  `install.ps1` automatically falls back to direct file copies into `.gemini\antigravity\agents\`.
- **`install.sh` error `\r: command not found` on Linux/macOS:**
  Run `sed -i 's/\r$//' install.sh` or invoke via `bash install.sh`.
- **I already have a personal `GEMINI.md`:**
  The installer never blindly overwrites it—you can choose backup + `overwrite`, backup + `merge`, or `skip`.
