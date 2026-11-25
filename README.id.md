# 🚀 Antigravity Custom Agents & Modular Plugins

🌐 [English](README.md) | **Bahasa Indonesia**

[![Antigravity Agent](https://img.shields.io/badge/Antigravity-Custom%20Agents-blueviolet?style=flat-square)](https://github.com/kevinap29/antigravity-custom-agents)
[![.NET](https://img.shields.io/badge/.NET-6--11%20%7C%20WebForms%20%7C%20MAUI-512BD4?style=flat-square&logo=dotnet)](https://dotnet.microsoft.com/)
[![SvelteKit](https://img.shields.io/badge/SvelteKit-TypeScript%20%2B%20Tailwind-FF3E00?style=flat-square&logo=svelte)](https://kit.svelte.dev/)
[![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20SQL%20Server-003B57?style=flat-square&logo=sqlite)](https://www.sqlite.org/)
[![RTK](https://img.shields.io/badge/RTK-Token%20Optimizer-10B981?style=flat-square)](https://github.com/rtk-ai/rtk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Koleksi siap pakai berisi **9 Custom Agents**, **2 Plugin Modular (`antigravity-sdlc` bundle + `rtk` Token Optimizer)**, **Deterministic Quality/Security Gate**, **Central Memory MCP Opsional (Qdrant)**, dan **Personal Developer Profile ramping (`GEMINI.md`)** untuk **Antigravity / Gemini CLI**. Dirancang untuk alur kerja SDLC full-stack (.NET Core/CQRS, Legacy ASP.NET WebForms, SvelteKit, .NET MAUI Hybrid Blazor, SQLite/SQL Server, hingga Docker/Portainer/Harbor VPS).

---

## ⚡ Quickstart

Clone repositori ini lalu jalankan skrip installer otomatis sesuai sistem operasi Anda:

```bash
# Clone repository
git clone https://github.com/kevinap29/antigravity-custom-agents.git
cd antigravity-custom-agents

# Windows (PowerShell):
powershell -ExecutionPolicy Bypass -File .\install.ps1

# macOS / Linux:
chmod +x install.sh && ./install.sh
```

> **Catatan:** Jika Anda menginstal dari arsip `.zip`, cukup ekstrak arsip tersebut lalu jalankan perintah `install.ps1` (Windows) atau `./install.sh` (macOS/Linux) di dalam folder hasil ekstrak.

---

## ✨ Fitur Utama (Upgrade v2.0 — Modular Plugin Bundle)

- **9 Custom Agents Terstruktur:** Terdiri dari 2 Main Agent (`sdlc-team-lead` & `pr-review-fixer`) dan 7 Subagent spesialis domain.
- **Plugin Modular `antigravity-sdlc` (`plugins/antigravity-sdlc/`):**
  - **3 Domain Skills Terbundel (`skills/`):** Pola siap pakai (WebForms, SvelteKit/MAUI, Portainer/Harbor) dikemas rapi di dalam plugin.
  - **Engineering Rules Auto-Update (`rules/ENGINEERING_RULES.md`):** Aturan statis (DB-first, Git branching, Searchable Dropdown, DRY/KISS, Zero Regression, Doc Sync, PowerShell & RTK) tinggal di plugin sehingga `update` otomatis menyinkronkannya tanpa menyentuh `GEMINI.md` pribadi Anda.
  - **Deterministic `PreToolUse` Guardrails (`hooks/sdlc-guardrails.mjs`):** Hook Node.js zero-dependency yang memblokir `git push` ke `main`/`master`/`develop`, eksekusi langsung CLI DB (`sqlcmd`, `sqlite3`, `psql`, `mysql`), dan migrasi EF Core Code-First (`dotnet ef migrations` / `dotnet ef database update`). Otomatis dinonaktifkan dengan aman jika `node` belum terpasang.
- **Plugin RTK Independen (`plugins/rtk/`):** Plugin 3rd-party penghemat token (`rtk hook antigravity`) dipisahkan agar bisa diaktifkan/update secara independen.
- **Arsitektur SDLC v1.5+ (`sdlc-team-lead`, `ui-prototyper`, `frontend-mobile-dev`, `qa-code-reviewer`):**
  - **4-Lane Complexity Matrix:** `Lane 0 (docs)` langsung oleh Team Lead, `Lane 1 (micro < 30 baris)` skip file plan dengan `Model: flash`, dan `Lane 2/3 (standard/complex)` alur penuh Phase 0–5.
  - **Contract Freeze Gate:** Eksekusi paralel hanya diizinkan setelah kontrak DTO Phase 0 matang & lolos Ambiguity Gate, dengan batas **maksimal 2 subagent paralel**.
  - **Conditional Prototype Fidelity & Package Alignment:** Phase 1 tetap opsional (skip untuk backend-only/minor task). Namun jika prototype dibuat (`_prototypes/<feature-slug>.html`), `ui-prototyper` menyamakan CSS/icon/chart package proyek + *Component Mapping Note*, diikuti *Prototype Approval Gate*, konversi 1:1 oleh `frontend-mobile-dev`, dan *Prototype Parity Audit* oleh `qa-code-reviewer`.
  - **Progressive Model Escalation:** Jika `qa-code-reviewer` memberi tag `[CRITICAL][ESCALATE_MODEL]` atau gagal di iterasi ke-2 pada model `flash`, Team Lead otomatis men-spawn subagent baru dengan kelas model lebih tinggi (`flash` → `inherit` → `pro`).
- **Deterministic Quality & Security Gate (`scripts/verify-gate.ps1`):** Auto-detect `.NET` (`dotnet build`/`test`), `Node/SvelteKit` (`npm run check`/`build`/`test`), `Python` (`pytest`), serta static security scanner (`gitleaks`, `trivy`, dan `semgrep` di Unix/macOS).
- **Central Memory MCP Opsional (`mcp/central_memory_mcp.py` + Qdrant):** Memori semantik lintas sesi (`BAAI/bge-small-en-v1.5` via `fastembed` lokal CPU + Qdrant 3 mode: Local Embedded / Localhost Server / Remote VPS, proteksi staleness `git_tree_hash`), lengkap dengan auto-reconnecting SSH tunnel opsional untuk jaringan kantor/restricted.
- **Modular Installer (Core + 3 Add-ons + OS/Env Preflight Check):** Otomatis mengecek OS & tool terpasang (mis. otomatis skip `semgrep` di Windows, cek `node` untuk guardrails), migrasi otomatis folder lama `config/skills/`, serta menyimpan pilihan Add-on di `~/.gemini/.addons.json` untuk `update` & `verify`.
- **Token-Efficient English Prompts + Personal Profile Ramping (`GEMINI.md`):** Seluruh `agents/*.md`, `plugins/antigravity-sdlc/skills/*/SKILL.md`, dan `ENGINEERING_RULES.md` ditulis dalam Bahasa Inggris ringkas, sementara `GEMINI.md` tetap ringan (hanya Tech Stack, bahasa balasan `-ResponseLanguage`/`--response-language`, dan Tone pribadi Anda).

---

## 📦 Struktur Repositori

```text
antigravity-custom-agents/
├── agents/                     # 9 definisi custom agent (.md, English token-efficient)
│   ├── sdlc-team-lead.md       # Main Agent: Arsitek & koordinator SDLC
│   ├── pr-review-fixer.md      # Main Agent: Auto-fixer PR/AI code review
│   ├── dotnet-cqrs-dev.md      # Subagent: Backend C# / .NET Core / CQRS
│   ├── dotnet-webforms-dev.md  # Subagent: Legacy .NET Framework / ASP.NET WebForms
│   ├── frontend-mobile-dev.md  # Subagent: SvelteKit & .NET MAUI Hybrid Blazor
│   ├── db-data-engineer.md     # Subagent: SQLite (WAL) & SQL Server (T-SQL)
│   ├── devops-git-ops.md       # Subagent: Git, CI/CD, Docker/Portainer/Harbor, VPS
│   ├── ui-prototyper.md        # Subagent: Prototyping UI HTML + Package Alignment
│   └── qa-code-reviewer.md     # Subagent: Auditor kualitas kode, build, security & parity
├── plugins/                    # 2 plugin Antigravity independen
│   ├── antigravity-sdlc/       # Bundle SDLC modular (skills, rules, PreToolUse guardrails)
│   │   ├── plugin.json         # Metadata plugin (v2.0.0)
│   │   ├── hooks.json          # Konfigurasi hook PreToolUse (path di-resolve saat install)
│   │   ├── hooks/
│   │   │   └── sdlc-guardrails.mjs # Guardrail Node.js (protected branch, DB CLI, EF migrations)
│   │   ├── rules/
│   │   │   └── ENGINEERING_RULES.md # Aturan engineering statis (auto-update)
│   │   └── skills/             # 3 domain skills terbundel
│   │       ├── dotnet-webforms-patterns/SKILL.md
│   │       ├── frontend-mobile-patterns/SKILL.md
│   │       └── portainer-harbor-deploy/SKILL.md
│   └── rtk/                    # Plugin RTK token optimizer independen
│       ├── plugin.json         # Metadata plugin RTK
│       ├── hooks.json          # PreToolUse hook (rtk hook antigravity)
│       └── rules/AGENTS.md     # Aturan penggunaan & recovery output RTK
├── scripts/                    # Skrip Deterministic Gate & SSH Tunnel opsional
│   ├── verify-gate.ps1         # Deterministic build/test + security scanner gate
│   ├── qdrant-tunnel.ps1       # Auto-reconnecting SSH tunnel (env/param-based)
│   └── qdrant-tunnel-hidden.vbs# Launcher hidden Task Scheduler (%USERPROFILE%)
├── mcp/                        # Central Memory MCP Server (Opsional)
│   ├── central_memory_mcp.py   # MCP Qdrant + fastembed (staleness git_tree_hash)
│   └── requirements.txt        # Dependensi Python (qdrant-client[fastembed], fastmcp)
├── memory/                     # Referensi aturan & catatan arsitektur global (Opsional)
│   ├── GLOBAL_RULES.md
│   └── ARCHITECTURE_NOTES.md
├── templates/                  # Starter template untuk proyek tim
│   ├── .antigravityignore      # Ignore rule hemat token (bin/, obj/, node_modules/, dll.)
│   └── AGENTS.md               # Template instruksi & konvensi proyek
├── CHEATSHEET.md / .id.md      # Contoh prompt nyata (English & Bahasa Indonesia)
├── mcp_config.example.json     # Contoh konfigurasi MCP (context7, fetch, sqlite, central_memory)
├── GEMINI.md                   # Personal Developer Profile ramping (Tech Stack & Bahasa/Tone)
├── install.ps1                 # Modular Installer Windows (Core + Add-ons + Env Check)
├── install.sh                  # Modular Installer Linux / macOS (Core + Add-ons + Env Check)
├── verify.ps1 / verify.sh      # Health-check Core & Add-ons terpasang
├── update.ps1 / update.sh      # Sinkronisasi & update bundle sesuai profil ~/.gemini/.addons.json
├── uninstall.ps1 / uninstall.sh# Rollback aman hanya untuk komponen bundle
├── LICENSE                     # MIT License
├── .gitignore
└── README.md / README.id.md    # Dokumentasi bilingual (English & Bahasa Indonesia)
```

### Daftar Custom Agents (9 Agent)

| Agent | Peran | Tugas Utama |
| :--- | :--- | :--- |
| `sdlc-team-lead` | **Main Agent** | Perencanaan terisolasi per fitur, 4-Lane Matrix, deteksi stack otomatis, Contract Freeze Gate, conditional prototype handover, dan Progressive Model Escalation. |
| `pr-review-fixer` | **Main Agent** | Single-agent hemat kuota untuk eksekusi perbaikan komentar AI Code Review / PR bot secara presisi serta membuat draft balasan markdown. |
| `dotnet-cqrs-dev` | Subagent | Pengembangan backend C#, .NET Core / .NET 6–11, ASP.NET Core, Vertical Slice Architecture, CQRS, custom mediator, LINQ/EF Core, dan `ISqliteConnectionFactory` / Dapper. |
| `dotnet-webforms-dev` | Subagent | Maintenance & fitur baru legacy .NET Framework 4.x dan ASP.NET WebForms (`.aspx`, `.ascx`, `.aspx.cs`, `.designer.cs`, `Web.config`, EF6/ADO.NET). |
| `frontend-mobile-dev` | Subagent | Pengembangan frontend SvelteKit (UI, routing, server routes, Tailwind) dan aplikasi mobile/desktop .NET MAUI Hybrid Blazor dengan Prototype Fidelity 1:1. |
| `db-data-engineer` | Subagent | Desain skema SQL, migrasi DB-first, indexing, optimasi query SQLite (WAL mode, batch SQL) dan SQL Server (T-SQL, stored procedures). |
| `devops-git-ops` | Subagent | Git workflow, GitHub Actions CI/CD, Dockerfile & Portainer Stack, Harbor registry, `systemd`, `cloudflared` di Ubuntu VPS, serta CI/CD build `.NET MAUI Hybrid Blazor`. |
| `ui-prototyper` | Subagent | Pembuatan prototipe UI/UX interaktif standalone HTML yang selaras dengan CSS framework, icon, dan chart library proyek. |
| `qa-code-reviewer` | Subagent | Audit kualitas kode, deterministic gate (`verify-gate.ps1`), sinkronisasi kontrak API, Prototype Parity, DRY, Zero Regression, Doc Sync, dan keamanan. |

### Daftar Plugin (2 Plugin Modular)

1. **`plugins/antigravity-sdlc/` (SDLC Bundle — v2.0.0):**
   - **Bundled Skills (`skills/`):**
     - **`dotnet-webforms-patterns`**: Pola implementasi & verifikasi statis proyek legacy .NET Framework 4.x / ASP.NET WebForms (`.csproj` non-SDK, sinkronisasi `.designer.cs`, EF6/LINQ/ADO.NET).
     - **`frontend-mobile-patterns`**: Panduan implementasi SvelteKit (Svelte 4 vs Svelte 5 runes) dan .NET MAUI Hybrid Blazor (lifecycle, `BlazorWebView`, JS Interop, target build).
     - **`portainer-harbor-deploy`**: SOP & template standar Docker/Portainer Stack hemat RAM di Ubuntu VPS dan workflow GitHub Actions push image ke Harbor private registry.
   - **Engineering Rules (`rules/ENGINEERING_RULES.md`):** Aturan statis (DB-first, Git branching, searchable dropdown, DRY/KISS, Zero Regression, Doc Sync, PowerShell & RTK) yang otomatis di-inject dan di-update tanpa menyentuh `GEMINI.md` pribadi Anda.
   - **Deterministic `PreToolUse` Guardrails (`hooks/sdlc-guardrails.mjs`):** Hook Node.js zero-dependency yang memblokir `git push` ke `main`/`master`/`develop`, eksekusi langsung CLI DB (`sqlcmd`, `sqlite3`, `psql`, `mysql`), dan migrasi EF Core Code-First (`dotnet ef migrations` / `dotnet ef database update`). Membutuhkan `node`; jika tidak ada, installer otomatis menyetel `"enabled": false`.
2. **`plugins/rtk/` (RTK Token Optimizer — Independen):**
   - Berisi `plugin.json`, `hooks.json`, dan `rules/AGENTS.md` untuk *transparent command rewriting* (`PreToolUse` hook `rtk hook antigravity` pada `run_command`) guna mengompresi output terminal panjang dan menghemat token AI.

> **Penting untuk RTK:** Plugin RTK membutuhkan binary CLI **`rtk`** terpasang di sistem Anda agar hook berjalan penuh:
> - **Windows (`winget`):**
>   ```powershell
>   winget install --id rtk-ai.rtk -e
>   ```
>   *(Atau jalankan installer dengan `powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallRtk`.)*
> - **Linux / macOS:**
>   - Homebrew: `brew install rtk`
>   - Cargo (Rust): `cargo install --git https://github.com/rtk-ai/rtk`
>   - Release binary: unduh dari `https://github.com/rtk-ai/rtk/releases` dan masukkan ke `PATH`.

---

## 🚀 Cara Instalasi Otomatis — Modular (Core + Add-ons)

Installer v2.0 memisahkan instalasi menjadi **Core** (wajib: `agents/`, `plugins/antigravity-sdlc/`, `plugins/rtk/`, `scripts/verify-gate.ps1`, `GEMINI.md`) dan **3 Add-on Opsional** dengan **OS/Environment Preflight Check** otomatis:
- **Add-on A (Security Scanners):** `gitleaks` & `trivy` (via `winget` di Windows; `semgrep` otomatis di-skip di Windows karena tidak didukung native, namun tersedia di Linux/macOS).
- **Add-on B (Central Memory MCP / Qdrant — 3 Mode):** Menyalin `mcp/` & `memory/`, cek Python 3 terlebih dahulu, opsi `.venv` + `requirements.txt`, serta pilihan 3 mode Qdrant:
  - **`Local` (Embedded — Default):** Zero-setup tanpa VPS/Docker/service; menyimpan vector di `~/.gemini/memory/qdrant_local` via env `QDRANT_LOCAL_PATH` (otomatis skip Add-on C).
  - **`Localhost` (Native Server `127.0.0.1:6333`):** Mengunduh binary resmi Qdrant ke `~/.gemini/bin/` + `qdrant-config.yaml` untuk multi-session & Web Dashboard lokal tanpa Docker (otomatis skip Add-on C).
  - **`Remote` (VPS):** Menggunakan `QDRANT_URL` + `QDRANT_API_KEY` (menawarkan Add-on C SSH Tunnel di Windows).
- **Add-on C (Qdrant SSH Tunnel Auto-Start — Khusus Windows, Mode `Remote`):** Menyalin `scripts/qdrant-tunnel.ps1` & `scripts/qdrant-tunnel-hidden.vbs` untuk lingkungan jaringan kantor/restricted.

Pilihan add-on (`centralMemory`, `qdrantMode`, `sshTunnel`, `responseLanguage`) disimpan di `~/.gemini/.addons.json` agar `update` dan `verify` otomatis menyinkronkan modul yang Anda pilih saja.

### Windows (PowerShell)

```powershell
# Mode interaktif (memilih bahasa balasan, Add-on A/B/C & mode Qdrant satu per satu):
powershell -ExecutionPolicy Bypass -File .\install.ps1

# Mode non-interaktif dengan Central Memory Local Embedded (tanpa VPS):
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GeminiMdMode Skip -ResponseLanguage "Bahasa Indonesia" -WithSecurityTools -WithMemory -QdrantMode Local

# Mode non-interaktif dengan Central Memory Remote VPS + SSH Tunnel:
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GeminiMdMode Skip -ResponseLanguage "English" -WithSecurityTools -WithMemory -QdrantMode Remote -WithTunnel
```

> **Parameter Windows (`install.ps1`):**
> - `-GeminiMdMode Prompt|Overwrite|Merge|Skip`
> - `-ResponseLanguage <Language>` (bahasa balasan agent di `GEMINI.md`; default: `English`, interaktif menyediakan `English`, `Bahasa Indonesia`, atau `Custom`)
> - `-InstallRtk` (install binary CLI `rtk` via `winget`)
> - `-WithSecurityTools` (install `gitleaks` & `trivy` via `winget`; `semgrep` otomatis di-skip di Windows)
> - `-WithMemory` (pasang Central Memory MCP + `memory/*.md` + opsi `.venv`)
> - `-QdrantMode Local|Localhost|Remote` (default: `Local` bila `-WithMemory` diset)
> - `-WithTunnel` (pasang skrip Qdrant SSH Tunnel Windows; hanya untuk mode `Remote`)

### Linux / macOS (Bash)

```bash
chmod +x install.sh
# Mode interaktif:
bash install.sh

# Mode non-interaktif dengan Add-on (Local Embedded / Localhost / Remote):
bash install.sh --gemini-mode=skip --response-language="Bahasa Indonesia" --with-security-tools --with-memory --qdrant-mode=local
```

> **Parameter Unix/macOS (`install.sh`):** `--gemini-mode=prompt|overwrite|merge|skip`, `--response-language=<lang>` (default: `English`), `--with-security-tools`, `--with-memory`, `--qdrant-mode=local|localhost|remote`.

---

## 📋 Prerequisites Windows & Setup Lanjutan (Opsional)

### 1. Security Scanners Lokal (Deterministic Gate)
```powershell
winget install Gitleaks.Gitleaks
winget install AquaSecurity.Trivy
```
*(Bila belum terpasang, `scripts/verify-gate.ps1` tetap berjalan aman dan melewati scanner yang belum tersedia.)*

### 2. Central Memory MCP (Python 3.13 + Qdrant)
1. Pastikan **Python 3.13** (atau 3.10+) terpasang, lalu buat virtual environment di `%USERPROFILE%\.gemini\mcp\.venv`:
   ```powershell
   python -m venv "$env:USERPROFILE\.gemini\mcp\.venv"
   & "$env:USERPROFILE\.gemini\mcp\.venv\Scripts\pip.exe" install -r "$env:USERPROFILE\.gemini\mcp\requirements.txt"
   ```
2. Salin entri dari `mcp_config.example.json` ke `%USERPROFILE%\.gemini\antigravity\mcp_config.json` sesuai mode Qdrant pilihan Anda:
   - **Mode `Local` (Embedded, tanpa VPS):** gunakan entri `central_memory_local` (set `QDRANT_LOCAL_PATH` ke `<USER_HOME>/.gemini/memory/qdrant_local`, tanpa `QDRANT_URL`/`QDRANT_API_KEY`).
   - **Mode `Localhost` (Native Server):** gunakan entri `central_memory` dengan `QDRANT_URL=http://127.0.0.1:6333` (jalankan `~/.gemini/bin/qdrant(.exe) --config-path ~/.gemini/bin/qdrant-config.yaml`).
   - **Mode `Remote` (VPS):** gunakan entri `central_memory` dan ganti placeholder `<USER_HOME>`, `<QDRANT_URL>`, serta `<QDRANT_API_KEY>`.

### 3. Auto-Start SSH Tunnel di Windows Task Scheduler (Jaringan Kantor / Restricted)
1. Set environment variable user (sekali saja):
   ```powershell
   [Environment]::SetEnvironmentVariable("QDRANT_SSH_HOST", "<SSH_USER>@<VPS_IP>", "User")
   [Environment]::SetEnvironmentVariable("QDRANT_SSH_PORT", "22", "User")
   ```
2. Buat Task di **Windows Task Scheduler** bernama `Antigravity-Qdrant-Tunnel`:
   - **Trigger:** *At log on* (user Anda).
   - **Action:** *Start a program* → Program: `wscript.exe`, Arguments: `"%USERPROFILE%\.gemini\scripts\qdrant-tunnel-hidden.vbs"`.
   - Tunnel akan berjalan 100% hidden di background (`127.0.0.1:6333` → VPS) dengan named Mutex single-instance guard dan auto-reconnect.

### 4. Ringkasan Setup Qdrant Native (Non-Docker) di Ubuntu VPS
Untuk VPS hemat RAM tanpa Docker:
1. Unduh static binary release resmi Qdrant Linux (`qdrant-x86_64-unknown-linux-musl.tar.gz`) ke `/usr/local/bin/qdrant` dan buat `/etc/qdrant/config.yaml` dengan bind **`host: 127.0.0.1`**, **`http_port: 6333`**, dan `service.api_key: "<QDRANT_API_KEY>"`.
2. Jalankan sebagai service `systemd` (`/etc/systemd/system/qdrant.service`) dengan pembatasan memori **`MemoryMax=300M`**, `Restart=always`, lalu aktifkan via `systemctl enable --now qdrant`.
3. Akses dari laptop secara aman melalui SSH port forwarding (`127.0.0.1:6333`), sehingga port Qdrant tidak perlu diekspos ke internet publik.

---

## 🛠️ Cara Instalasi Manual

Jika Anda ingin menyalin file secara manual tanpa menjalankan skrip installer:

1. **Salin seluruh file agent (`agents/*.md`)** ke kedua direktori berikut:
   - Windows: `%USERPROFILE%\.gemini\config\agents\` & `%USERPROFILE%\.gemini\antigravity\agents\`
   - Linux / macOS: `~/.gemini/config/agents/` & `~/.gemini/antigravity/agents/` (boleh berupa symlink)
2. **Salin plugin `antigravity-sdlc` (`plugins/antigravity-sdlc/`)** ke `%USERPROFILE%\.gemini\config\plugins\antigravity-sdlc\` atau `~/.gemini/config/plugins/antigravity-sdlc/`, lalu ganti `__HOOK_SCRIPT_PATH__` di `hooks.json` dengan path absolut ke `hooks/sdlc-guardrails.mjs` (set `"enabled": false` jika `node` tidak terpasang).
3. **Salin folder plugin RTK (`plugins/rtk/`)** ke `%USERPROFILE%\.gemini\config\plugins\rtk\` atau `~/.gemini/config/plugins/rtk/`.
4. **Salin `scripts/verify-gate.ps1`** ke `~/.gemini/scripts/verify-gate.ps1`.
5. **Salin atau gabungkan `GEMINI.md`** ke `~/.gemini/GEMINI.md`.

---

## ✅ Verifikasi, Update & Rollback

### 1. Health-Check Instalasi (`verify`)
```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```
```bash
# macOS / Linux
bash verify.sh
```

### 2. Sinkronisasi / Update Bundle (`update`)
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

- **Contoh Prompt Nyata ([CHEATSHEET.id.md](CHEATSHEET.id.md) | [English](CHEATSHEET.md)):** Berisi 6 skenario siap pakai untuk memicu `sdlc-team-lead`, `dotnet-webforms-dev`, `db-data-engineer`, `devops-git-ops`, `qa-code-reviewer`, `pr-review-fixer`, dan `ui-prototyper`.
- **Template Proyek Tim (`templates/`):**
  - Salin `templates/.antigravityignore` ke root proyek tim sebagai `.antigravityignore` agar folder build (`bin/`, `obj/`, `node_modules/`, `.svelte-kit/`, `*.db-wal`, dll.) tidak memakan kuota token.
  - Salin `templates/AGENTS.md` ke root proyek tim sebagai `AGENTS.md` lalu sesuaikan placeholder Tech Stack dan perintah build/test.
- **Konfigurasi MCP (`mcp_config.example.json`):** Referensi konfigurasi MCP server (`context7`, `fetch`, `sqlite`, `central_memory`, `central_memory_local`) untuk digabungkan ke `~/.gemini/antigravity/mcp_config.json`.

---

## ✅ Cara Memverifikasi di Antigravity / Gemini CLI

1. Tutup dan buka kembali **Antigravity** (atau mulai sesi Gemini CLI baru).
2. Pastikan agent utama (`sdlc-team-lead` dan `pr-review-fixer`) muncul di daftar pilihan agent/mode atau dapat dipanggil.
3. Jalankan prompt uji singkat ke `sdlc-team-lead`, misalnya:
   > *"Cek daftar subagent dan skill yang tersedia di konfigurasi saya saat ini."*
4. Pastikan agent mengenali ke-7 subagent (`dotnet-cqrs-dev`, `dotnet-webforms-dev`, `frontend-mobile-dev`, `db-data-engineer`, `devops-git-ops`, `ui-prototyper`, `qa-code-reviewer`) serta aturan global di `GEMINI.md`.

---

## ❓ FAQ & Troubleshooting

- **PowerShell menolak menjalankan `install.ps1` ("running scripts is disabled on this system"):**
  Jalankan dengan `powershell -ExecutionPolicy Bypass -File .\install.ps1`.
- **Error izin SymbolicLink di Windows (`PrivilegeNotHeld`):**
  Skrip `install.ps1` otomatis fallback menyalin file langsung ke `.gemini\antigravity\agents\`.
- **`install.sh` error `\r: command not found` di Linux/macOS:**
  Jalankan `sed -i 's/\r$//' install.sh` atau `bash install.sh`.
- **Saya sudah punya `GEMINI.md` pribadi:**
  Installer tidak langsung menimpa `GEMINI.md` Anda—skrip menanyakan apakah ingin backup + `overwrite`, backup + `merge`, atau `skip`.
