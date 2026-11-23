# 🚀 Antigravity Custom Agents, Skills & RTK Plugin

[![Antigravity Agent](https://img.shields.io/badge/Antigravity-Custom%20Agents-blueviolet?style=flat-square)](https://github.com/kevinap29/antigravity-custom-agents)
[![.NET](https://img.shields.io/badge/.NET-6--11%20%7C%20WebForms%20%7C%20MAUI-512BD4?style=flat-square&logo=dotnet)](https://dotnet.microsoft.com/)
[![SvelteKit](https://img.shields.io/badge/SvelteKit-TypeScript%20%2B%20Tailwind-FF3E00?style=flat-square&logo=svelte)](https://kit.svelte.dev/)
[![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20SQL%20Server-003B57?style=flat-square&logo=sqlite)](https://www.sqlite.org/)
[![RTK](https://img.shields.io/badge/RTK-Token%20Optimizer-10B981?style=flat-square)](https://github.com/rtk-ai/rtk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

Koleksi siap pakai berisi **9 Custom Agents**, **3 Custom Skills**, **Plugin RTK (Token Optimizer)**, dan **Global Developer Profile & Guardrails (`GEMINI.md`)** untuk **Antigravity / Gemini CLI**. Dirancang untuk alur kerja SDLC full-stack (.NET Core/CQRS, Legacy ASP.NET WebForms, SvelteKit, .NET MAUI Hybrid Blazor, SQLite/SQL Server, hingga Docker/Portainer/Harbor VPS).

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

## ✨ Fitur Utama

- **9 Custom Agents Terstruktur:** Terdiri dari 2 Main Agent (`sdlc-team-lead` & `pr-review-fixer`) dan 7 Subagent spesialis domain yang dapat bekerja paralel.
- **3 Domain Skills:** Panduan pola kode & deployment siap pakai untuk ASP.NET WebForms legacy, SvelteKit & .NET MAUI Hybrid Blazor, serta Portainer/Harbor Docker Stack.
- **Plugin RTK (Token Optimizer):** Hook `PreToolUse` (`rtk hook antigravity`) untuk mengompresi output terminal panjang secara transparan agar kuota token lebih hemat.
- **Global Developer Profile (`GEMINI.md`):** Aturan standar DB-first, DRY, Zero Regression, KISS, dan Doc Sync otomatis di setiap sesi.

---

## 📦 Struktur Repositori

```text
antigravity-custom-agents/
├── agents/                     # 9 definisi custom agent (.md)
│   ├── sdlc-team-lead.md       # Main Agent: Arsitek & koordinator SDLC
│   ├── pr-review-fixer.md      # Main Agent: Auto-fixer PR/AI code review
│   ├── dotnet-cqrs-dev.md      # Subagent: Backend C# / .NET Core / CQRS
│   ├── dotnet-webforms-dev.md  # Subagent: Legacy .NET Framework / ASP.NET WebForms
│   ├── frontend-mobile-dev.md  # Subagent: SvelteKit & .NET MAUI Hybrid Blazor
│   ├── db-data-engineer.md     # Subagent: SQLite (WAL) & SQL Server (T-SQL)
│   ├── devops-git-ops.md       # Subagent: Git, CI/CD, Docker/Portainer/Harbor, VPS
│   ├── ui-prototyper.md        # Subagent: Prototyping UI HTML + Tailwind CDN
│   └── qa-code-reviewer.md     # Subagent: Auditor kualitas kode, build & test
├── skills/                     # 3 domain skills
│   ├── dotnet-webforms-patterns/SKILL.md
│   ├── frontend-mobile-patterns/SKILL.md
│   └── portainer-harbor-deploy/SKILL.md
├── plugins/                    # Plugin tambahan Antigravity
│   └── rtk/
│       ├── plugin.json         # Metadata plugin RTK
│       ├── hooks.json          # PreToolUse hook (rtk hook antigravity)
│       └── rules/AGENTS.md     # Aturan penggunaan & recovery output RTK
├── GEMINI.md                   # Global Developer Profile & Coding Guardrails
├── install.ps1                 # Installer otomatis Windows (PowerShell)
├── install.sh                  # Installer otomatis Linux / macOS (Bash)
├── LICENSE                     # MIT License
├── .gitignore
└── README.md                   # Dokumentasi ini
```

### Daftar Custom Agents (9 Agent)

| Agent | Peran | Tugas Utama |
| :--- | :--- | :--- |
| `sdlc-team-lead` | **Main Agent** | Perencanaan terisolasi per fitur, deteksi stack otomatis, prototyping HTML, delegasi paralel subagent, dan QA auto-fix loop. |
| `pr-review-fixer` | **Main Agent** | Single-agent hemat kuota untuk eksekusi perbaikan komentar AI Code Review / PR bot secara presisi serta membuat draft balasan markdown. |
| `dotnet-cqrs-dev` | Subagent | Pengembangan backend C#, .NET Core / .NET 6–11, ASP.NET Core, Vertical Slice Architecture, CQRS, custom mediator, LINQ/EF Core, dan `ISqliteConnectionFactory` / Dapper. |
| `dotnet-webforms-dev` | Subagent | Maintenance & fitur baru legacy .NET Framework 4.x dan ASP.NET WebForms (`.aspx`, `.ascx`, `.aspx.cs`, `.designer.cs`, `Web.config`, EF6/ADO.NET). |
| `frontend-mobile-dev` | Subagent | Pengembangan frontend SvelteKit (UI, routing, server routes, Tailwind) dan aplikasi mobile/desktop .NET MAUI Hybrid Blazor. |
| `db-data-engineer` | Subagent | Desain skema SQL, migrasi DB-first, indexing, optimasi query SQLite (WAL mode, batch SQL) dan SQL Server (T-SQL, stored procedures). |
| `devops-git-ops` | Subagent | Git workflow, GitHub Actions CI/CD, Dockerfile & Portainer Stack, Harbor registry, `systemd`, `cloudflared` di Ubuntu VPS, serta CI/CD build `.NET MAUI Hybrid Blazor`. |
| `ui-prototyper` | Subagent | Pembuatan prototipe UI/UX interaktif berbasis standalone HTML, Tailwind CDN, dan Vanilla/Alpine JS sebelum implementasi ke SvelteKit atau Blazor. |
| `qa-code-reviewer` | Subagent | Audit kualitas kode, sinkronisasi kontrak API, DRY, Zero Regression, Doc Sync, keamanan, dan verifikasi build/test. |

### Daftar Custom Skills (3 Skill)

1. **`dotnet-webforms-patterns`**: Pola implementasi & verifikasi statis proyek legacy .NET Framework 4.x / ASP.NET WebForms (`.csproj` non-SDK, sinkronisasi `.designer.cs`, EF6/LINQ/ADO.NET).
2. **`frontend-mobile-patterns`**: Panduan implementasi SvelteKit (Svelte 4 vs Svelte 5 runes) dan .NET MAUI Hybrid Blazor (lifecycle, `BlazorWebView`, JS Interop, target build).
3. **`portainer-harbor-deploy`**: SOP & template standar Docker/Portainer Stack hemat RAM di Ubuntu VPS dan workflow GitHub Actions push image ke Harbor private registry.

### Plugin Tambahan: RTK (Token Optimizer)

Folder `plugins/rtk/` berisi plugin **RTK** (`plugin.json`, `hooks.json`, dan `rules/AGENTS.md`) yang berfungsi melakukan *transparent command rewriting* (`PreToolUse` hook `rtk hook antigravity` pada `run_command`) untuk mengompresi output terminal yang panjang (seperti log build, `git status`, test output) dan menghemat pemakaian token AI secara signifikan.

> **Penting:** Plugin ini membutuhkan binary CLI **`rtk`** terpasang di sistem Anda agar hook berjalan penuh:
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

## 🚀 Cara Instalasi Otomatis (Direkomendasikan)

Ekstrak file `antigravity-custom-agents.zip` terlebih dahulu, lalu buka terminal di dalam folder `antigravity-custom-agents`.

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

> **Catatan:** Jika Anda ingin langsung menentukan perilaku terhadap file `GEMINI.md` yang sudah ada tanpa prompt interaktif, tambahkan parameter `-GeminiMdMode`:
> - `-GeminiMdMode Overwrite` (backup file lama lalu timpa)
> - `-GeminiMdMode Merge` (backup file lama lalu gabungkan di bagian bawah)
> - `-GeminiMdMode Skip` (pertahankan `GEMINI.md` yang sudah ada)

### Linux / macOS (Bash)

```bash
chmod +x install.sh
bash install.sh
```

> **Opsi non-interaktif:** `bash install.sh --gemini-mode=merge` (pilihan: `prompt`, `overwrite`, `merge`, `skip`).

---

## 🛠️ Cara Instalasi Manual

Jika Anda ingin menyalin file secara manual tanpa menjalankan skrip installer:

1. **Salin seluruh file agent (`agents/*.md`)** ke kedua direktori berikut:
   - Windows:
     - `%USERPROFILE%\.gemini\config\agents\`
     - `%USERPROFILE%\.gemini\antigravity\agents\`
   - Linux / macOS:
     - `~/.gemini/config/agents/`
     - `~/.gemini/antigravity/agents/` (boleh berupa symlink ke `~/.gemini/config/agents/<nama>.md`)

2. **Salin seluruh folder skill (`skills/*`)** ke:
   - Windows: `%USERPROFILE%\.gemini\config\skills\`
   - Linux / macOS: `~/.gemini/config/skills/`

3. **Salin folder plugin RTK (`plugins/rtk/`)** ke:
   - Windows: `%USERPROFILE%\.gemini\config\plugins\rtk\`
   - Linux / macOS: `~/.gemini/config/plugins/rtk/`

4. **Salin atau gabungkan `GEMINI.md`** ke:
   - Windows: `%USERPROFILE%\.gemini\GEMINI.md`
   - Linux / macOS: `~/.gemini/GEMINI.md`

Pastikan struktur akhir di direktori `.gemini` Anda terlihat seperti ini:

```text
~/.gemini/
├── GEMINI.md
├── antigravity/
│   └── agents/
│       └── (9 file .md atau symlink)
└── config/
    ├── agents/
    │   └── (9 file .md)
    ├── plugins/
    │   └── rtk/
    │       ├── plugin.json
    │       ├── hooks.json
    │       └── rules/AGENTS.md
    └── skills/
        ├── dotnet-webforms-patterns/SKILL.md
        ├── frontend-mobile-patterns/SKILL.md
        └── portainer-harbor-deploy/SKILL.md
```

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
  Jalankan dengan flag bypass khusus untuk perintah tersebut:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  ```
- **Error izin SymbolicLink di Windows (`PrivilegeNotHeld`):**
  PowerShell biasa (non-Administrator) tanpa Developer Mode tidak dapat membuat SymbolicLink. Skrip `install.ps1` sudah menangani ini secara otomatis dengan **fallback menyalin file langsung** ke `.gemini\antigravity\agents\`, sehingga agent tetap berfungsi normal.
- **`install.sh` error `\r: command not found` di Linux/macOS:**
  Jika file mengalami konversi baris CRLF saat transfer, jalankan `sed -i 's/\r$//' install.sh` (Linux) atau gunakan `bash install.sh`.
- **Saya sudah punya `GEMINI.md` pribadi:**
  Jangan khawatir—baik `install.ps1` maupun `install.sh` tidak akan langsung menimpa `GEMINI.md` Anda. Skrip akan menanyakan apakah ingin membuat backup + menimpa, backup + menggabungkan (`merge`), atau melewati (`skip`).
