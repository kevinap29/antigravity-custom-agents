<#
.SYNOPSIS
    Installer otomatis Antigravity Custom Agents, Skills, dan Global Rules (GEMINI.md) untuk Windows.
.DESCRIPTION
    Menyalin 9 definisi custom agent, 3 custom skills, dan Global Developer Profile (GEMINI.md)
    ke direktori konfigurasi Antigravity / Gemini CLI milik user (~/.gemini).
.PARAMETER GeminiMdMode
    Mode penanganan jika GEMINI.md sudah ada: Prompt (default), Overwrite, Merge, atau Skip.
.PARAMETER InstallRtk
    Jika diset, otomatis menjalankan instalasi binary CLI 'rtk' via winget bila belum terpasang.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

[CmdletBinding()]
param(
    [ValidateSet("Prompt", "Overwrite", "Merge", "Skip")]
    [string]$GeminiMdMode = "Prompt",
    [switch]$InstallRtk
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$sourceAgents = Join-Path $scriptRoot "agents"
$sourceSkills = Join-Path $scriptRoot "skills"
$sourcePluginsRtk = Join-Path $scriptRoot "plugins\rtk"
$sourceGeminiMd = Join-Path $scriptRoot "GEMINI.md"

if (-not (Test-Path $sourceAgents)) {
    throw "Folder sumber agents tidak ditemukan di: $sourceAgents"
}
if (-not (Test-Path $sourceSkills)) {
    throw "Folder sumber skills tidak ditemukan di: $sourceSkills"
}
if (-not (Test-Path $sourcePluginsRtk)) {
    throw "Folder sumber plugins\rtk tidak ditemukan di: $sourcePluginsRtk"
}
if (-not (Test-Path $sourceGeminiMd)) {
    throw "File sumber GEMINI.md tidak ditemukan di: $sourceGeminiMd"
}

$geminiDir = Join-Path $HOME ".gemini"
$targetConfigAgents = Join-Path $geminiDir "config\agents"
$targetConfigSkills = Join-Path $geminiDir "config\skills"
$targetConfigPluginsRtk = Join-Path $geminiDir "config\plugins\rtk"
$targetAntigravityAgents = Join-Path $geminiDir "antigravity\agents"
$targetGeminiMd = Join-Path $geminiDir "GEMINI.md"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Antigravity Custom Agents & Skills Installer (Windows)    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Target direktori: $geminiDir`n" -ForegroundColor Gray

# 1. Menyiapkan direktori target
$dirsToCreate = @($targetConfigAgents, $targetConfigSkills, $targetConfigPluginsRtk, $targetAntigravityAgents)
foreach ($dir in $dirsToCreate) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "[+] Direktori dibuat: $dir" -ForegroundColor DarkCyan
    }
}

# Cek apakah shell berjalan sebagai Administrator (elevated)
$isElevated = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isElevated = $false
}

# 2. Menyalin file agent ke config\agents dan sinkronisasi ke antigravity\agents
$agentFiles = Get-ChildItem -Path $sourceAgents -Filter "*.md" -File
$linkedCount = 0
$copiedCount = 0

Write-Host "`n[1/4] Menginstal Custom Agents ($($agentFiles.Count) file)..." -ForegroundColor Yellow
foreach ($agent in $agentFiles) {
    $destConfigPath = Join-Path $targetConfigAgents $agent.Name
    $destAntigravityPath = Join-Path $targetAntigravityAgents $agent.Name

    $existingConfigItem = Get-Item -LiteralPath $destConfigPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $existingConfigItem) {
        Remove-Item -LiteralPath $destConfigPath -Force
    }
    Copy-Item -LiteralPath $agent.FullName -Destination $destConfigPath -Force

    $existingAntigravityItem = Get-Item -LiteralPath $destAntigravityPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $existingAntigravityItem) {
        Remove-Item -LiteralPath $destAntigravityPath -Force
    }

    $symlinkCreated = $false
    if ($isElevated) {
        try {
            New-Item -ItemType SymbolicLink -Path $destAntigravityPath -Target $destConfigPath -ErrorAction Stop | Out-Null
            $symlinkCreated = $true
            $linkedCount++
        } catch {
            $symlinkCreated = $false
        }
    }

    if (-not $symlinkCreated) {
        Copy-Item -Path $destConfigPath -Destination $destAntigravityPath -Force
        $copiedCount++
    }

    Write-Host "  - $($agent.Name)" -ForegroundColor Gray
}

if ($linkedCount -gt 0) {
    Write-Host "  [OK] $linkedCount agent ditautkan via SymbolicLink ke antigravity\agents." -ForegroundColor Green
}
if ($copiedCount -gt 0) {
    Write-Host "  [OK] $copiedCount agent disalin langsung ke antigravity\agents." -ForegroundColor Green
}

# 3. Menyalin folder skills ke config\skills
$skillDirs = Get-ChildItem -Path $sourceSkills -Directory
Write-Host "`n[2/4] Menginstal Custom Skills ($($skillDirs.Count) skill)..." -ForegroundColor Yellow
foreach ($skill in $skillDirs) {
    $destSkillPath = Join-Path $targetConfigSkills $skill.Name
    if (Test-Path $destSkillPath) {
        Remove-Item -Path $destSkillPath -Recurse -Force
    }
    Copy-Item -Path $skill.FullName -Destination $destSkillPath -Recurse -Force
    Write-Host "  - $($skill.Name)" -ForegroundColor Gray
}
Write-Host "  [OK] Semua skill berhasil disalin ke $targetConfigSkills." -ForegroundColor Green

# 4. Menyalin plugin RTK ke config\plugins\rtk dan cek binary rtk
Write-Host "`n[3/4] Menginstal Plugin RTK (Token Optimizer)..." -ForegroundColor Yellow
Copy-Item -Path "$sourcePluginsRtk\*" -Destination $targetConfigPluginsRtk -Recurse -Force
Write-Host "  [OK] Konfigurasi plugin RTK disalin ke $targetConfigPluginsRtk." -ForegroundColor Green

$rtkCmd = Get-Command rtk -ErrorAction SilentlyContinue
if ($null -ne $rtkCmd) {
    Write-Host "  [OK] CLI 'rtk' terdeteksi ($($rtkCmd.Source))" -ForegroundColor Green
} else {
    Write-Host "  [!] Binary CLI 'rtk' belum terpasang di sistem." -ForegroundColor Yellow
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -ne $wingetCmd) {
        $shouldInstallRtk = $InstallRtk.IsPresent
        if (-not $shouldInstallRtk -and [Environment]::UserInteractive -and ($GeminiMdMode -eq "Prompt")) {
            $rtkAnswer = Read-Host "      Winget terdeteksi. Install binary 'rtk' sekarang via winget? (y/N)"
            if ($rtkAnswer -match '^(y|yes)$') {
                $shouldInstallRtk = $true
            }
        }
        if ($shouldInstallRtk) {
            Write-Host "  [*] Menjalankan: winget install --id rtk-ai.rtk -e" -ForegroundColor Cyan
            & winget install --id rtk-ai.rtk -e
        } else {
            Write-Host "      Untuk mengaktifkan hook kompresi output RTK, jalankan:" -ForegroundColor White
            Write-Host "      winget install --id rtk-ai.rtk -e" -ForegroundColor Cyan
        }
    } else {
        Write-Host "      Pasang binary 'rtk' dengan: winget install --id rtk-ai.rtk -e (atau dari repositori rtk-ai/rtk)." -ForegroundColor White
    }
}

# 5. Menangani GEMINI.md
Write-Host "`n[4/4] Mengatur Global Profile & Guardrails (GEMINI.md)..." -ForegroundColor Yellow
if (-not (Test-Path $targetGeminiMd)) {
    Copy-Item -Path $sourceGeminiMd -Destination $targetGeminiMd -Force
    Write-Host "  [OK] GEMINI.md baru dibuat di $targetGeminiMd." -ForegroundColor Green
} else {
    $selectedMode = $GeminiMdMode
    if ($selectedMode -eq "Prompt") {
        Write-Host "  [!] File $targetGeminiMd sudah ada." -ForegroundColor Yellow
        Write-Host "      Pilih tindakan:" -ForegroundColor White
        Write-Host "      [1] Backup & Timpa (Overwrite) dengan GEMINI.md dari bundle" -ForegroundColor White
        Write-Host "      [2] Backup & Gabungkan (Append/Merge) isi baru ke bagian bawah" -ForegroundColor White
        Write-Host "      [3] Lewati (Pertahankan GEMINI.md yang sudah ada)" -ForegroundColor White
        $choice = Read-Host "      Masukkan pilihan (1/2/3) [Default: 3]"
        switch ($choice) {
            "1" { $selectedMode = "Overwrite" }
            "2" { $selectedMode = "Merge" }
            default { $selectedMode = "Skip" }
        }
    }

    if ($selectedMode -eq "Overwrite") {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$targetGeminiMd.bak.$timestamp"
        Copy-Item -Path $targetGeminiMd -Destination $backupPath -Force
        Copy-Item -Path $sourceGeminiMd -Destination $targetGeminiMd -Force
        Write-Host "  [OK] Backup disimpan ke: $backupPath" -ForegroundColor DarkCyan
        Write-Host "  [OK] GEMINI.md berhasil ditimpa." -ForegroundColor Green
    } elseif ($selectedMode -eq "Merge") {
        $existingContent = Get-Content -Path $targetGeminiMd -Raw -Encoding UTF8
        if ($null -eq $existingContent) { $existingContent = "" }
        $incomingContent = Get-Content -Path $sourceGeminiMd -Raw -Encoding UTF8
        if ($existingContent -match "Global Developer Profile & Rules") {
            Write-Host "  [!] Bagian 'Global Developer Profile & Rules' sudah terdeteksi di GEMINI.md. Melewati duplikasi." -ForegroundColor Yellow
        } else {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupPath = "$targetGeminiMd.bak.$timestamp"
            Copy-Item -Path $targetGeminiMd -Destination $backupPath -Force
            $merged = $existingContent.TrimEnd() + "`r`n`r`n---`r`n`r`n" + $incomingContent
            Set-Content -Path $targetGeminiMd -Value $merged -Encoding UTF8
            Write-Host "  [OK] Backup disimpan ke: $backupPath" -ForegroundColor DarkCyan
            Write-Host "  [OK] Konten GEMINI.md berhasil digabungkan." -ForegroundColor Green
        }
    } else {
        Write-Host "  [SKIP] GEMINI.md eksisting dipertahankan tanpa perubahan." -ForegroundColor DarkYellow
    }
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  INSTALASI SELESAI!                                        " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Ringkasan lokasi terpasang:" -ForegroundColor Green
Write-Host "  - Agents (Config)      : $targetConfigAgents" -ForegroundColor Green
Write-Host "  - Agents (Antigravity) : $targetAntigravityAgents" -ForegroundColor Green
Write-Host "  - Skills               : $targetConfigSkills" -ForegroundColor Green
Write-Host "  - Plugin (RTK)         : $targetConfigPluginsRtk" -ForegroundColor Green
Write-Host "  - Global Rules         : $targetGeminiMd" -ForegroundColor Green
Write-Host "`nLangkah berikutnya:" -ForegroundColor Cyan
Write-Host "  1. Restart / buka ulang Antigravity atau sesi Gemini CLI Anda." -ForegroundColor White
Write-Host "  2. Cek agent aktif dengan memanggil 'sdlc-team-lead' atau 'pr-review-fixer'." -ForegroundColor White
