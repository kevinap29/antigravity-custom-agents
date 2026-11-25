<#
.SYNOPSIS
    Modular Installer Antigravity Custom Agents, Skills, Deterministic Gate, dan Add-ons (Windows).
.DESCRIPTION
    Menjalankan OS/Env Preflight Check, memasang Core bundle (9 agents, 3 skills, RTK plugin,
    scripts/verify-gate.ps1, GEMINI.md), serta mendukung 3 modular add-on opsional:
    Add-on A (Security Scanners: gitleaks & trivy), Add-on B (Central Memory MCP / Qdrant
    dengan mode Local, Localhost, atau Remote), dan Add-on C (Qdrant SSH Tunnel untuk Windows).
    Menyimpan profil add-on aktif ke ~/.gemini/.addons.json.
.PARAMETER GeminiMdMode
    Mode penanganan jika GEMINI.md sudah ada: Prompt (default), Overwrite, Merge, atau Skip.
.PARAMETER InstallRtk
    Jika diset, otomatis menjalankan instalasi binary CLI 'rtk' via winget bila belum terpasang.
.PARAMETER WithSecurityTools
    Jika diset, menawarkan/memasang gitleaks dan trivy via winget (semgrep otomatis di-skip di Windows).
.PARAMETER WithMemory
    Jika diset, memasang Add-on B (Central Memory MCP & memory rules) bila Python 3 tersedia.
.PARAMETER QdrantMode
    Mode Qdrant untuk Add-on B: Local (default embedded), Localhost (binary lokal), atau Remote (VPS).
.PARAMETER WithTunnel
    Jika diset, memasang Add-on C (Qdrant SSH Tunnel scripts untuk Windows, otomatis untuk mode Remote).
.PARAMETER ResponseLanguage
    Bahasa respons default AI yang disubstitusikan ke GEMINI.md (default saat non-interaktif: English).
.PARAMETER NonInteractive
    Menjalankan instalasi tanpa prompt interaktif (default menolak prompt opsional dan skip overwrite GEMINI.md).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithMemory -QdrantMode Local -WithSecurityTools
#>

[CmdletBinding()]
param(
    [ValidateSet("Prompt", "Overwrite", "Merge", "Skip")]
    [string]$GeminiMdMode = "Prompt",
    [switch]$InstallRtk,
    [switch]$WithSecurityTools,
    [switch]$WithMemory,
    [ValidateSet("", "Local", "Localhost", "Remote")]
    [string]$QdrantMode = "",
    [switch]$WithTunnel,
    [string]$ResponseLanguage = "",
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$sourceAgents = Join-Path $scriptRoot "agents"
$sourceSkills = Join-Path $scriptRoot "skills"
$sourcePluginsRtk = Join-Path $scriptRoot "plugins\rtk"
$sourceScripts = Join-Path $scriptRoot "scripts"
$sourceVerifyGate = Join-Path $sourceScripts "verify-gate.ps1"
$sourceTunnelPs1 = Join-Path $sourceScripts "qdrant-tunnel.ps1"
$sourceTunnelVbs = Join-Path $sourceScripts "qdrant-tunnel-hidden.vbs"
$sourceMcp = Join-Path $scriptRoot "mcp"
$sourceMemory = Join-Path $scriptRoot "memory"
$sourceGeminiMd = Join-Path $scriptRoot "GEMINI.md"

foreach ($requiredPath in @($sourceAgents, $sourceSkills, $sourcePluginsRtk, $sourceVerifyGate, $sourceGeminiMd)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Aset Core bundle tidak ditemukan di: $requiredPath"
    }
}

$isInteractive = [Environment]::UserInteractive -and (-not [Console]::IsInputRedirected) -and (-not $NonInteractive.IsPresent)

function Find-Python3Command {
    foreach ($candidate in @("python", "python3", "py")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            try {
                $ver = & $cmd.Source --version 2>$null
                if ($LASTEXITCODE -eq 0 -and ($ver | Out-String) -match 'Python\s+3\.') {
                    return [PSCustomObject]@{
                        Command = $cmd.Source
                        Version = ($ver | Out-String).Trim()
                    }
                }
            } catch {
                # Abaikan alias Windows Store / shim yang tidak aktif
            }
        }
    }
    return $null
}

$geminiDir = Join-Path $HOME ".gemini"
$targetConfigAgents = Join-Path $geminiDir "config\agents"
$targetConfigSkills = Join-Path $geminiDir "config\skills"
$targetConfigPluginsRtk = Join-Path $geminiDir "config\plugins\rtk"
$targetAntigravityAgents = Join-Path $geminiDir "antigravity\agents"
$targetScripts = Join-Path $geminiDir "scripts"
$targetMcp = Join-Path $geminiDir "mcp"
$targetMemory = Join-Path $geminiDir "memory"
$targetBin = Join-Path $geminiDir "bin"
$targetGeminiMd = Join-Path $geminiDir "GEMINI.md"
$addonsProfilePath = Join-Path $geminiDir ".addons.json"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Antigravity Custom Agents & Skills Installer (Windows)    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Target direktori: $geminiDir" -ForegroundColor Gray

# ------------------------------------------------------------
# 0. OS & Environment Preflight Check
# ------------------------------------------------------------
Write-Host "`n[PREFLIGHT] Memeriksa OS & tool lingkungan..." -ForegroundColor Cyan
$osDesc = [System.Environment]::OSVersion.VersionString
Write-Host "  - OS       : Windows ($osDesc)" -ForegroundColor Gray

$pythonInfo = Find-Python3Command
$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
$gitleaksCmd = Get-Command gitleaks -ErrorAction SilentlyContinue
$trivyCmd = Get-Command trivy -ErrorAction SilentlyContinue

if ($null -ne $pythonInfo) {
    Write-Host "  [OK]   python   : $($pythonInfo.Version) ($($pythonInfo.Command))" -ForegroundColor Green
} else {
    Write-Host "  [MISS] python   : Python 3 tidak ditemukan (diperlukan hanya untuk Add-on Central Memory)" -ForegroundColor Yellow
}

if ($null -ne $sshCmd) {
    Write-Host "  [OK]   ssh      : $($sshCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "  [MISS] ssh      : OpenSSH client tidak ditemukan" -ForegroundColor Yellow
}

if ($null -ne $wingetCmd) {
    Write-Host "  [OK]   winget   : $($wingetCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "  [MISS] winget   : tidak tersedia" -ForegroundColor Yellow
}

if ($null -ne $gitleaksCmd) {
    Write-Host "  [OK]   gitleaks : $($gitleaksCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "  [MISS] gitleaks : belum terpasang" -ForegroundColor Yellow
}

if ($null -ne $trivyCmd) {
    Write-Host "  [OK]   trivy    : $($trivyCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "  [MISS] trivy    : belum terpasang" -ForegroundColor Yellow
}

Write-Host "  [SKIP] semgrep  : semgrep tidak didukung native di Windows" -ForegroundColor DarkYellow

# ------------------------------------------------------------
# CORE INSTALLATION (Selalu Terpasang)
# ------------------------------------------------------------
$dirsToCreate = @($targetConfigAgents, $targetConfigSkills, $targetConfigPluginsRtk, $targetAntigravityAgents, $targetScripts)
foreach ($dir in $dirsToCreate) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$isElevated = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isElevated = $false
}

# 1. Custom Agents
function Resolve-DirectoryLinkTarget {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    if ($item.LinkType -and $item.Target) {
        $rawTarget = @($item.Target)[0]
        if (-not [System.IO.Path]::IsPathRooted($rawTarget)) {
            $parent = Split-Path -Path $Path -Parent
            $rawTarget = Join-Path $parent $rawTarget
        }
        return [System.IO.Path]::GetFullPath($rawTarget).TrimEnd('\', '/')
    }
    return [System.IO.Path]::GetFullPath($item.FullName).TrimEnd('\', '/')
}

$resolvedConfigAgents = Resolve-DirectoryLinkTarget -Path $targetConfigAgents
$resolvedAntigravityAgents = Resolve-DirectoryLinkTarget -Path $targetAntigravityAgents
$sameAgentsDir = ($null -ne $resolvedConfigAgents) -and ($null -ne $resolvedAntigravityAgents) -and ($resolvedConfigAgents -ieq $resolvedAntigravityAgents)

$agentFiles = Get-ChildItem -Path $sourceAgents -Filter "*.md" -File
$linkedCount = 0
$copiedCount = 0

Write-Host "`n[CORE 1/5] Menginstal Custom Agents ($($agentFiles.Count) file)..." -ForegroundColor Yellow
foreach ($agent in $agentFiles) {
    $destConfigPath = Join-Path $targetConfigAgents $agent.Name
    $destAntigravityPath = Join-Path $targetAntigravityAgents $agent.Name

    $existingConfigItem = Get-Item -LiteralPath $destConfigPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $existingConfigItem) {
        Remove-Item -LiteralPath $destConfigPath -Force
    }
    Copy-Item -LiteralPath $agent.FullName -Destination $destConfigPath -Force

    if (-not $sameAgentsDir) {
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
    }

    Write-Host "  - $($agent.Name)" -ForegroundColor Gray
}

if ($sameAgentsDir) {
    Write-Host "  [OK] $($agentFiles.Count) agent terpasang ke config\agents (antigravity\agents sudah terhubung via directory link)." -ForegroundColor Green
} else {
    if ($linkedCount -gt 0) {
        Write-Host "  [OK] $linkedCount agent ditautkan via SymbolicLink ke antigravity\agents." -ForegroundColor Green
    }
    if ($copiedCount -gt 0) {
        Write-Host "  [OK] $copiedCount agent disalin langsung ke antigravity\agents." -ForegroundColor Green
    }
}

# 2. Custom Skills
$skillDirs = Get-ChildItem -Path $sourceSkills -Directory
Write-Host "`n[CORE 2/5] Menginstal Custom Skills ($($skillDirs.Count) skill)..." -ForegroundColor Yellow
foreach ($skill in $skillDirs) {
    $destSkillPath = Join-Path $targetConfigSkills $skill.Name
    if (Test-Path $destSkillPath) {
        Remove-Item -Path $destSkillPath -Recurse -Force
    }
    Copy-Item -Path $skill.FullName -Destination $destSkillPath -Recurse -Force
    Write-Host "  - $($skill.Name)" -ForegroundColor Gray
}
Write-Host "  [OK] Semua skill berhasil disalin ke $targetConfigSkills." -ForegroundColor Green

# 3. Plugin RTK
Write-Host "`n[CORE 3/5] Menginstal Plugin RTK (Token Optimizer)..." -ForegroundColor Yellow
Copy-Item -Path "$sourcePluginsRtk\*" -Destination $targetConfigPluginsRtk -Recurse -Force
Write-Host "  [OK] Konfigurasi plugin RTK disalin ke $targetConfigPluginsRtk." -ForegroundColor Green

$rtkCmd = Get-Command rtk -ErrorAction SilentlyContinue
if ($null -ne $rtkCmd) {
    Write-Host "  [OK] CLI 'rtk' terdeteksi ($($rtkCmd.Source))" -ForegroundColor Green
} else {
    Write-Host "  [!] Binary CLI 'rtk' belum terpasang di sistem." -ForegroundColor Yellow
    if ($null -ne $wingetCmd) {
        $shouldInstallRtk = $InstallRtk.IsPresent
        if (-not $shouldInstallRtk -and $isInteractive -and ($GeminiMdMode -eq "Prompt")) {
            $rtkAnswer = Read-Host "      Winget terdeteksi. Install binary 'rtk' sekarang via winget? (y/N)"
            if ($rtkAnswer -match '^(y|yes)$') {
                $shouldInstallRtk = $true
            }
        }
        if ($shouldInstallRtk) {
            Write-Host "  [*] Menjalankan: winget install --id rtk-ai.rtk -e" -ForegroundColor Cyan
            & winget install --id rtk-ai.rtk -e
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [WARN] Instalasi 'rtk' via winget gagal (exit code $LASTEXITCODE)." -ForegroundColor Yellow
            }
        } else {
            Write-Host "      Untuk mengaktifkan hook kompresi output RTK, jalankan:" -ForegroundColor White
            Write-Host "      winget install --id rtk-ai.rtk -e" -ForegroundColor Cyan
        }
    } else {
        Write-Host "      Pasang binary 'rtk' dengan: winget install --id rtk-ai.rtk -e (atau dari repositori rtk-ai/rtk)." -ForegroundColor White
    }
}

# 4. Core Script: verify-gate.ps1
Write-Host "`n[CORE 4/5] Menginstal Deterministic Gate Script (verify-gate.ps1)..." -ForegroundColor Yellow
Copy-Item -LiteralPath $sourceVerifyGate -Destination (Join-Path $targetScripts "verify-gate.ps1") -Force
Write-Host "  [OK] verify-gate.ps1 disalin ke $targetScripts\verify-gate.ps1." -ForegroundColor Green

# 5. GEMINI.md
Write-Host "`n[CORE 5/5] Mengatur Global Profile & Guardrails (GEMINI.md)..." -ForegroundColor Yellow

$resolvedResponseLanguage = "English"
if (-not [string]::IsNullOrWhiteSpace($ResponseLanguage)) {
    $resolvedResponseLanguage = $ResponseLanguage.Trim()
} elseif ($isInteractive) {
    Write-Host "  Pilih bahasa respons AI di GEMINI.md:" -ForegroundColor White
    Write-Host "    [1] English (Default) | [2] Bahasa Indonesia | [3] Custom" -ForegroundColor White
    $langChoice = Read-Host "  Masukkan pilihan (1/2/3) [Default: 1]"
    switch ($langChoice) {
        "2" { $resolvedResponseLanguage = "Bahasa Indonesia" }
        "3" {
            $customLang = Read-Host "  Masukkan bahasa respons (contoh: Japanese)"
            if (-not [string]::IsNullOrWhiteSpace($customLang)) {
                $resolvedResponseLanguage = $customLang.Trim()
            }
        }
        default { $resolvedResponseLanguage = "English" }
    }
}

$incomingGeminiContent = (Get-Content -Path $sourceGeminiMd -Raw -Encoding UTF8) -replace 'Always respond to the user in English\.', "Always respond to the user in $resolvedResponseLanguage."

if (-not (Test-Path $targetGeminiMd)) {
    Set-Content -Path $targetGeminiMd -Value $incomingGeminiContent -Encoding UTF8 -NoNewline
    Write-Host "  [OK] GEMINI.md baru dibuat di $targetGeminiMd (ResponseLanguage=$resolvedResponseLanguage)." -ForegroundColor Green
} else {
    $selectedMode = $GeminiMdMode
    if ($selectedMode -eq "Prompt") {
        if ($isInteractive) {
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
        } else {
            Write-Host "  [!] Mode non-interaktif & GEMINI.md sudah ada; mempertahankan file eksisting (Skip)." -ForegroundColor DarkYellow
            $selectedMode = "Skip"
        }
    }

    if ($selectedMode -eq "Overwrite") {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$targetGeminiMd.bak.$timestamp"
        Copy-Item -Path $targetGeminiMd -Destination $backupPath -Force
        Set-Content -Path $targetGeminiMd -Value $incomingGeminiContent -Encoding UTF8 -NoNewline
        Write-Host "  [OK] Backup disimpan ke: $backupPath" -ForegroundColor DarkCyan
        Write-Host "  [OK] GEMINI.md berhasil ditimpa (ResponseLanguage=$resolvedResponseLanguage)." -ForegroundColor Green
    } elseif ($selectedMode -eq "Merge") {
        $existingContent = Get-Content -Path $targetGeminiMd -Raw -Encoding UTF8
        if ($null -eq $existingContent) { $existingContent = "" }
        if ($existingContent -match "Global Developer Profile & Rules") {
            Write-Host "  [!] Bagian 'Global Developer Profile & Rules' sudah terdeteksi di GEMINI.md. Melewati duplikasi." -ForegroundColor Yellow
        } else {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupPath = "$targetGeminiMd.bak.$timestamp"
            Copy-Item -Path $targetGeminiMd -Destination $backupPath -Force
            $merged = $existingContent.TrimEnd() + "`r`n`r`n---`r`n`r`n" + $incomingGeminiContent
            Set-Content -Path $targetGeminiMd -Value $merged -Encoding UTF8 -NoNewline
            Write-Host "  [OK] Backup disimpan ke: $backupPath" -ForegroundColor DarkCyan
            Write-Host "  [OK] Konten GEMINI.md berhasil digabungkan (ResponseLanguage=$resolvedResponseLanguage)." -ForegroundColor Green
        }
    } else {
        Write-Host "  [SKIP] GEMINI.md eksisting dipertahankan tanpa perubahan." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------
# ADD-ON A: Security Scanners (gitleaks & trivy; skip semgrep)
# ------------------------------------------------------------
Write-Host "`n[ADD-ON A] Security Scanners (gitleaks & trivy)..." -ForegroundColor Yellow
Write-Host "  [SKIP] semgrep tidak didukung native di Windows (hanya dijalankan di Linux/macOS/CI)." -ForegroundColor DarkYellow

$missingSecTools = @()
if ($null -eq $gitleaksCmd) { $missingSecTools += "Gitleaks.Gitleaks" }
if ($null -eq $trivyCmd) { $missingSecTools += "AquaSecurity.Trivy" }

if ($missingSecTools.Count -eq 0) {
    Write-Host "  [OK] gitleaks & trivy sudah terpasang." -ForegroundColor Green
} else {
    $wantSecTools = $WithSecurityTools.IsPresent
    if (-not $wantSecTools -and $isInteractive) {
        $secAnswer = Read-Host "  Install security scanners yang belum ada ($($missingSecTools -join ', ')) via winget? (y/N)"
        if ($secAnswer -match '^(y|yes)$') {
            $wantSecTools = $true
        }
    }

    if ($wantSecTools) {
        if ($null -ne $wingetCmd) {
            foreach ($pkgId in $missingSecTools) {
                Write-Host "  [*] Menjalankan: winget install --id $pkgId -e" -ForegroundColor Cyan
                & winget install --id $pkgId -e
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  [WARN] Instalasi '$pkgId' via winget gagal (exit code $LASTEXITCODE)." -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  [WARN] winget tidak tersedia. Pasang manual: winget install Gitleaks.Gitleaks; winget install AquaSecurity.Trivy" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [SKIP] Instalasi security scanners dilewati." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------
# ADD-ON B: Central Memory MCP (Qdrant: Local / Localhost / Remote)
# ------------------------------------------------------------
Write-Host "`n[ADD-ON B] Central Memory MCP (Qdrant)..." -ForegroundColor Yellow
$enableMemory = $WithMemory.IsPresent
if (-not $enableMemory -and $isInteractive) {
    $memAnswer = Read-Host "  Pasang Add-on Central Memory MCP (Qdrant + memory rules)? (y/N)"
    if ($memAnswer -match '^(y|yes)$') {
        $enableMemory = $true
    }
}

$resolvedQdrantMode = $null

if ($enableMemory) {
    if ($null -eq $pythonInfo) {
        Write-Host "  [WARN] Python 3 tidak ditemukan. Add-on Central Memory MCP dilewati dengan aman." -ForegroundColor Yellow
        $enableMemory = $false
    } elseif (-not (Test-Path (Join-Path $sourceMcp "central_memory_mcp.py")) -or -not (Test-Path $sourceMemory)) {
        Write-Host "  [WARN] Folder sumber mcp/ atau memory/ tidak lengkap. Add-on Central Memory MCP dilewati." -ForegroundColor Yellow
        $enableMemory = $false
    } else {
        if (-not [string]::IsNullOrWhiteSpace($QdrantMode)) {
            $resolvedQdrantMode = $QdrantMode.ToLowerInvariant()
        } elseif ($WithTunnel.IsPresent) {
            $resolvedQdrantMode = "remote"
        } elseif ($isInteractive) {
            Write-Host "  Pilih mode Qdrant untuk Central Memory MCP:" -ForegroundColor White
            Write-Host "    [1] Local Embedded (tanpa server eksternal, simpan di ~/.gemini/memory/qdrant_local) [Default]" -ForegroundColor White
            Write-Host "    [2] Localhost Server (download binary resmi Qdrant ke ~/.gemini/bin/, port 6333)" -ForegroundColor White
            Write-Host "    [3] Remote VPS (QDRANT_URL eksternal / HTTPS / opsional SSH Tunnel)" -ForegroundColor White
            $qChoice = Read-Host "  Masukkan pilihan (1/2/3) [Default: 1]"
            switch ($qChoice) {
                "2" { $resolvedQdrantMode = "localhost" }
                "3" { $resolvedQdrantMode = "remote" }
                default { $resolvedQdrantMode = "local" }
            }
        } else {
            $resolvedQdrantMode = "local"
        }

        Write-Host "  [i] Mode Qdrant terpilih: $resolvedQdrantMode" -ForegroundColor Cyan

        foreach ($dir in @($targetMcp, $targetMemory)) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
        Copy-Item -LiteralPath (Join-Path $sourceMcp "central_memory_mcp.py") -Destination (Join-Path $targetMcp "central_memory_mcp.py") -Force
        Copy-Item -LiteralPath (Join-Path $sourceMcp "requirements.txt") -Destination (Join-Path $targetMcp "requirements.txt") -Force
        Copy-Item -Path (Join-Path $sourceMemory "*.md") -Destination $targetMemory -Force
        Write-Host "  [OK] File MCP & memory rules disalin ke $targetMcp & $targetMemory." -ForegroundColor Green

        if ($resolvedQdrantMode -eq "local") {
            $qdrantLocalDir = Join-Path $targetMemory "qdrant_local"
            if (-not (Test-Path $qdrantLocalDir)) {
                New-Item -ItemType Directory -Path $qdrantLocalDir -Force | Out-Null
            }
            Write-Host "  [OK] Direktori Qdrant Local Embedded siap di $qdrantLocalDir." -ForegroundColor Green
            Write-Host "  [INFO] Contoh konfigurasi env di mcp_config.json:" -ForegroundColor Cyan
            Write-Host "         `"QDRANT_LOCAL_PATH`": `"$($qdrantLocalDir -replace '\\', '/')`"" -ForegroundColor White
        } elseif ($resolvedQdrantMode -eq "localhost") {
            $qdrantStorageDir = Join-Path $targetMemory "qdrant_storage"
            foreach ($dir in @($targetBin, $qdrantStorageDir)) {
                if (-not (Test-Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
            }

            $qdrantConfigPath = Join-Path $targetBin "qdrant-config.yaml"
            $storageYamlPath = $qdrantStorageDir -replace '\\', '/'
            $qdrantConfigYaml = @"
service:
  host: 127.0.0.1
  http_port: 6333
storage:
  storage_path: $storageYamlPath
"@
            Set-Content -Path $qdrantConfigPath -Value $qdrantConfigYaml -Encoding UTF8
            Write-Host "  [OK] Konfigurasi Qdrant lokal dibuat di $qdrantConfigPath." -ForegroundColor Green

            $qdrantExePath = Join-Path $targetBin "qdrant.exe"
            if (Test-Path $qdrantExePath) {
                Write-Host "  [OK] Binary Qdrant sudah tersedia di $qdrantExePath." -ForegroundColor Green
            } else {
                Write-Host "  [*] Mengunduh binary resmi Qdrant (latest release) ke $targetBin..." -ForegroundColor Cyan
                $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) "qdrant-windows-msvc.zip"
                try {
                    $downloadUrl = "https://github.com/qdrant/qdrant/releases/latest/download/qdrant-x86_64-pc-windows-msvc.zip"
                    try {
                        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/qdrant/qdrant/releases/latest" -Headers @{ "User-Agent" = "Antigravity-Installer" } -TimeoutSec 20
                        $asset = $release.assets | Where-Object { $_.name -match '^qdrant-x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1
                        if ($null -ne $asset -and -not [string]::IsNullOrWhiteSpace($asset.browser_download_url)) {
                            $downloadUrl = $asset.browser_download_url
                        }
                    } catch {
                        # Fallback ke URL latest/download langsung
                    }
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -TimeoutSec 120
                    Expand-Archive -Path $tempZip -DestinationPath $targetBin -Force
                    if (Test-Path $qdrantExePath) {
                        Write-Host "  [OK] Binary Qdrant berhasil diunduh ke $qdrantExePath." -ForegroundColor Green
                    } else {
                        Write-Host "  [WARN] Arsip diekstrak namun qdrant.exe tidak ditemukan di $targetBin." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "  [WARN] Gagal mengunduh binary Qdrant (offline/diblokir): $_" -ForegroundColor Yellow
                    Write-Host "         Unduh manual dari https://github.com/qdrant/qdrant/releases (qdrant-x86_64-pc-windows-msvc.zip) dan ekstrak ke $targetBin." -ForegroundColor White
                } finally {
                    if (Test-Path $tempZip) {
                        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            Write-Host "  [INFO] Jalankan Qdrant lokal dengan: `"$qdrantExePath`" --config-path `"$qdrantConfigPath`"" -ForegroundColor Cyan
            Write-Host "         Lalu set QDRANT_URL=http://127.0.0.1:6333 di mcp_config.json." -ForegroundColor White
        } else {
            Write-Host "  [INFO] Mode Remote VPS dipilih. Set QDRANT_URL & QDRANT_API_KEY di mcp_config.json." -ForegroundColor Cyan
        }

        $venvDir = Join-Path $targetMcp ".venv"
        $venvPython = Join-Path $venvDir "Scripts\python.exe"
        if (-not (Test-Path $venvPython)) {
            $wantVenv = $false
            if ($isInteractive) {
                $venvAnswer = Read-Host "  Buat Python .venv & install dependencies (requirements.txt) di $venvDir? (y/N)"
                if ($venvAnswer -match '^(y|yes)$') {
                    $wantVenv = $true
                }
            }
            if ($wantVenv) {
                Write-Host "  [*] Membuat virtual environment di $venvDir..." -ForegroundColor Cyan
                & $pythonInfo.Command -m venv $venvDir
                if ($LASTEXITCODE -eq 0 -and (Test-Path $venvPython)) {
                    Write-Host "  [*] Menginstal dependencies dari requirements.txt..." -ForegroundColor Cyan
                    & $venvPython -m pip install --upgrade pip
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  [WARN] Upgrade pip gagal (exit code $LASTEXITCODE)." -ForegroundColor Yellow
                    }
                    & $venvPython -m pip install -r (Join-Path $targetMcp "requirements.txt")
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  [WARN] Instalasi dependencies requirements.txt gagal (exit code $LASTEXITCODE)." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  [WARN] Pembuatan .venv gagal. Anda dapat setup manual nanti." -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [INFO] Untuk setup venv manual nanti, jalankan:" -ForegroundColor Cyan
                Write-Host "         python -m venv `"$venvDir`"; `"$venvPython`" -m pip install -r `"$targetMcp\requirements.txt`"" -ForegroundColor White
            }
        } else {
            Write-Host "  [OK] Virtual environment .venv sudah ada di $venvDir." -ForegroundColor Green
        }
    }
} else {
    Write-Host "  [SKIP] Add-on Central Memory MCP tidak dipilih." -ForegroundColor DarkYellow
}

# ------------------------------------------------------------
# ADD-ON C: Qdrant SSH Tunnel Auto-Start (Khusus Windows & Mode Remote)
# ------------------------------------------------------------
Write-Host "`n[ADD-ON C] Qdrant SSH Tunnel (Windows)..." -ForegroundColor Yellow
$enableTunnel = $false
if ($enableMemory -and ($resolvedQdrantMode -in @("local", "localhost"))) {
    Write-Host "  [SKIP] Add-on Qdrant SSH Tunnel otomatis dilewati (mode Qdrant '$resolvedQdrantMode')." -ForegroundColor DarkYellow
} else {
    if ($WithTunnel.IsPresent) {
        $enableTunnel = $true
    } elseif ($enableMemory -and $resolvedQdrantMode -eq "remote" -and $isInteractive) {
        $tunnelAnswer = Read-Host "  Pasang Add-on Qdrant SSH Tunnel scripts (qdrant-tunnel.ps1 & .vbs)? (y/N)"
        if ($tunnelAnswer -match '^(y|yes)$') {
            $enableTunnel = $true
        }
    }

    if ($enableTunnel) {
        if ((Test-Path $sourceTunnelPs1) -and (Test-Path $sourceTunnelVbs)) {
            Copy-Item -LiteralPath $sourceTunnelPs1 -Destination (Join-Path $targetScripts "qdrant-tunnel.ps1") -Force
            Copy-Item -LiteralPath $sourceTunnelVbs -Destination (Join-Path $targetScripts "qdrant-tunnel-hidden.vbs") -Force
            Write-Host "  [OK] Tunnel scripts disalin ke $targetScripts." -ForegroundColor Green
            Write-Host "  [INFO] Set env var QDRANT_SSH_HOST (<SSH_USER>@<VPS_IP>) & QDRANT_SSH_PORT (default 22) sebelum menjalankan tunnel." -ForegroundColor Cyan
        } else {
            Write-Host "  [WARN] File sumber tunnel script tidak ditemukan. Melewati Add-on C." -ForegroundColor Yellow
            $enableTunnel = $false
        }
    } else {
        Write-Host "  [SKIP] Add-on Qdrant SSH Tunnel tidak dipilih." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------
# Simpan Profil Add-on ke ~/.gemini/.addons.json
# ------------------------------------------------------------
$addonsProfile = [ordered]@{
    responseLanguage = $resolvedResponseLanguage
    centralMemory    = [bool]$enableMemory
    qdrantMode       = $resolvedQdrantMode
    sshTunnel        = [bool]$enableTunnel
}
$addonsProfile | ConvertTo-Json | Set-Content -Path $addonsProfilePath -Encoding UTF8

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  INSTALASI SELESAI!                                        " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Ringkasan lokasi terpasang:" -ForegroundColor Green
Write-Host "  - Agents (Config)      : $targetConfigAgents" -ForegroundColor Green
Write-Host "  - Agents (Antigravity) : $targetAntigravityAgents" -ForegroundColor Green
Write-Host "  - Skills               : $targetConfigSkills" -ForegroundColor Green
Write-Host "  - Plugin (RTK)         : $targetConfigPluginsRtk" -ForegroundColor Green
Write-Host "  - Deterministic Gate   : $targetScripts\verify-gate.ps1" -ForegroundColor Green
Write-Host "  - Global Rules         : $targetGeminiMd" -ForegroundColor Green
Write-Host "  - Add-ons Profile      : $addonsProfilePath (responseLanguage=$resolvedResponseLanguage, centralMemory=$enableMemory, qdrantMode=$resolvedQdrantMode, sshTunnel=$enableTunnel)" -ForegroundColor Green
if ($enableMemory) {
    Write-Host "  - Central Memory MCP   : $targetMcp & $targetMemory" -ForegroundColor Green
}
if ($enableTunnel) {
    Write-Host "  - Qdrant SSH Tunnel    : $targetScripts\qdrant-tunnel.ps1" -ForegroundColor Green
}
Write-Host "`nLangkah berikutnya:" -ForegroundColor Cyan
Write-Host "  1. Restart / buka ulang Antigravity atau sesi Gemini CLI Anda." -ForegroundColor White
Write-Host "  2. Cek kesehatan instalasi dengan: powershell -ExecutionPolicy Bypass -File .\verify.ps1" -ForegroundColor White
