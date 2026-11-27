<#
.SYNOPSIS
    Verifikasi kesehatan instalasi Antigravity Custom Agents, SDLC Plugin, RTK Plugin,
    Deterministic Gate, GEMINI.md, serta Add-ons aktif (~/.gemini/.addons.json).
.DESCRIPTION
    Memeriksa seluruh komponen Core dan komponen Add-on (Central Memory MCP sesuai qdrantMode
    dan Qdrant SSH Tunnel) berdasarkan profil di ~/.gemini/.addons.json.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$resolvedHome = if (-not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_HOME)) {
    $env:ANTIGRAVITY_HOME
} elseif (-not [string]::IsNullOrWhiteSpace($HOME)) {
    $HOME
} else {
    $env:USERPROFILE
}
$geminiDir = Join-Path $resolvedHome ".gemini"
$configAgentsDir = Join-Path $geminiDir "config\agents"
$antigravityAgentsDir = Join-Path $geminiDir "antigravity\agents"
$configSdlcDir = Join-Path $geminiDir "config\plugins\antigravity-sdlc"
$configRtkDir = Join-Path $geminiDir "config\plugins\rtk"
$scriptsDir = Join-Path $geminiDir "scripts"
$mcpDir = Join-Path $geminiDir "mcp"
$memoryDir = Join-Path $geminiDir "memory"
$binDir = Join-Path $geminiDir "bin"
$geminiMdPath = Join-Path $geminiDir "GEMINI.md"
$addonsProfilePath = Join-Path $geminiDir ".addons.json"

$expectedAgents = @(
    "db-data-engineer.md",
    "devops-git-ops.md",
    "dotnet-cqrs-dev.md",
    "dotnet-webforms-dev.md",
    "frontend-mobile-dev.md",
    "pr-review-fixer.md",
    "qa-code-reviewer.md",
    "sdlc-team-lead.md",
    "ui-prototyper.md"
)

$expectedSdlcFiles = @(
    "plugin.json",
    "hooks.json",
    "hooks\sdlc-guardrails.mjs",
    "rules\ENGINEERING_RULES.md",
    "scripts\verify-gate.mjs",
    "scripts\verify-gate.ps1",
    "skills\dotnet-webforms-patterns\SKILL.md",
    "skills\frontend-mobile-patterns\SKILL.md",
    "skills\portainer-harbor-deploy\SKILL.md"
)

$expectedRtkFiles = @(
    "plugin.json",
    "hooks.json",
    "rules\AGENTS.md"
)

$centralMemoryEnabled = $false
$sshTunnelEnabled = $false
$qdrantMode = ""
if (Test-Path $addonsProfilePath) {
    try {
        $addons = Get-Content -Path $addonsProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $centralMemoryEnabled = ($addons.centralMemory -eq $true)
        $sshTunnelEnabled = ($addons.sshTunnel -eq $true)
        if ($null -ne $addons.qdrantMode) {
            $qdrantMode = ([string]$addons.qdrantMode).ToLowerInvariant()
        } elseif ($centralMemoryEnabled -and $sshTunnelEnabled) {
            $qdrantMode = "remote"
        }
    } catch {
        Write-Host "[WARN] Gagal membaca $addonsProfilePath; hanya memverifikasi Core." -ForegroundColor Yellow
    }
}

$okCount = 0
$warnCount = 0
$failCount = 0
$totalRequired = ($expectedAgents.Count * 2) + $expectedSdlcFiles.Count + $expectedRtkFiles.Count + 3
if ($centralMemoryEnabled) {
    $totalRequired += 4
    if ($qdrantMode -eq "local" -or $qdrantMode -eq "localhost") {
        $totalRequired += 1
    }
}
if ($sshTunnelEnabled) { $totalRequired += 2 }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Antigravity Bundle Health-Check (Windows)                 " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Direktori target: $geminiDir`n" -ForegroundColor Gray

function Test-BundleFile {
    param(
        [string]$Path,
        [string]$Label
    )
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        Write-Host "  [FAIL] $Label -> Tidak ditemukan ($Path)" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  [FAIL] $Label -> Symlink rusak/dangling ($Path)" -ForegroundColor Red
        return $false
    }
    Write-Host "  [OK]   $Label" -ForegroundColor Green
    return $true
}

function Test-BundleDir {
    param(
        [string]$Path,
        [string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Host "  [FAIL] $Label -> Direktori tidak ditemukan ($Path)" -ForegroundColor Red
        return $false
    }
    Write-Host "  [OK]   $Label" -ForegroundColor Green
    return $true
}

Write-Host "[1/7] Memeriksa Agents di config\agents ($($expectedAgents.Count) file)..." -ForegroundColor Cyan
foreach ($agent in $expectedAgents) {
    $path = Join-Path $configAgentsDir $agent
    if (Test-BundleFile -Path $path -Label "config\agents\$agent") { $okCount++ } else { $failCount++ }
}

Write-Host "`n[2/7] Memeriksa Agents di antigravity\agents ($($expectedAgents.Count) file)..." -ForegroundColor Cyan
foreach ($agent in $expectedAgents) {
    $path = Join-Path $antigravityAgentsDir $agent
    if (Test-BundleFile -Path $path -Label "antigravity\agents\$agent") { $okCount++ } else { $failCount++ }
}

Write-Host "`n[3/7] Memeriksa Plugin antigravity-sdlc ($($expectedSdlcFiles.Count) file)..." -ForegroundColor Cyan
foreach ($sdlcFile in $expectedSdlcFiles) {
    $path = Join-Path $configSdlcDir $sdlcFile
    if (Test-BundleFile -Path $path -Label "config\plugins\antigravity-sdlc\$sdlcFile") { $okCount++ } else { $failCount++ }
}

$sdlcHooksPath = Join-Path $configSdlcDir "hooks.json"
if (Test-Path -LiteralPath $sdlcHooksPath) {
    $sdlcHooksRaw = Get-Content -LiteralPath $sdlcHooksPath -Raw -Encoding UTF8
    if ($sdlcHooksRaw -match '__HOOK_SCRIPT_PATH__') {
        Write-Host "  [WARN] hooks.json masih berisi placeholder __HOOK_SCRIPT_PATH__ (jalankan install.ps1 / update.ps1)" -ForegroundColor Yellow
        $warnCount++
    }
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($null -ne $nodeCmd) {
    Write-Host "  [OK]   Binary CLI 'node' tersedia di PATH ($($nodeCmd.Source))" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Binary CLI 'node' belum ada di PATH (hook antigravity-sdlc-guardrails dinonaktifkan)" -ForegroundColor Yellow
    $warnCount++
}

Write-Host "`n[4/7] Memeriksa Plugin RTK & Binary CLI..." -ForegroundColor Cyan
foreach ($rtkFile in $expectedRtkFiles) {
    $path = Join-Path $configRtkDir $rtkFile
    if (Test-BundleFile -Path $path -Label "config\plugins\rtk\$rtkFile") { $okCount++ } else { $failCount++ }
}

$rtkCmd = Get-Command rtk -ErrorAction SilentlyContinue
if ($null -ne $rtkCmd) {
    Write-Host "  [OK]   Binary CLI 'rtk' tersedia di PATH ($($rtkCmd.Source))" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Binary CLI 'rtk' belum ada di PATH (opsional; pasang via: winget install --id rtk-ai.rtk -e)" -ForegroundColor Yellow
    $warnCount++
}

Write-Host "`n[5/7] Memeriksa Core Deterministic Gate & Global Rules..." -ForegroundColor Cyan
if (Test-BundleFile -Path (Join-Path $scriptsDir "verify-gate.mjs") -Label "scripts\verify-gate.mjs") { $okCount++ } else { $failCount++ }
if (Test-BundleFile -Path (Join-Path $scriptsDir "verify-gate.ps1") -Label "scripts\verify-gate.ps1") { $okCount++ } else { $failCount++ }
if (Test-BundleFile -Path $geminiMdPath -Label "GEMINI.md") { $okCount++ } else { $failCount++ }

Write-Host "`n[6/7] Memeriksa Add-on Central Memory MCP..." -ForegroundColor Cyan
if ($centralMemoryEnabled) {
    if (Test-BundleFile -Path (Join-Path $mcpDir "central_memory_mcp.py") -Label "mcp\central_memory_mcp.py") { $okCount++ } else { $failCount++ }
    if (Test-BundleFile -Path (Join-Path $mcpDir "requirements.txt") -Label "mcp\requirements.txt") { $okCount++ } else { $failCount++ }
    if (Test-BundleFile -Path (Join-Path $memoryDir "GLOBAL_RULES.md") -Label "memory\GLOBAL_RULES.md") { $okCount++ } else { $failCount++ }
    if (Test-BundleFile -Path (Join-Path $memoryDir "ARCHITECTURE_NOTES.md") -Label "memory\ARCHITECTURE_NOTES.md") { $okCount++ } else { $failCount++ }

    switch ($qdrantMode) {
        "local" {
            if (Test-BundleDir -Path (Join-Path $memoryDir "qdrant_local") -Label "memory\qdrant_local (mode=local)") { $okCount++ } else { $failCount++ }
        }
        "localhost" {
            if (Test-BundleFile -Path (Join-Path $binDir "qdrant-config.yaml") -Label "bin\qdrant-config.yaml (mode=localhost)") { $okCount++ } else { $failCount++ }
            $qdrantExe = Join-Path $binDir "qdrant.exe"
            if (Test-Path $qdrantExe) {
                Write-Host "  [OK]   bin\qdrant.exe tersedia ($qdrantExe)" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] bin\qdrant.exe belum tersedia di $binDir (unduh manual jika mode=localhost)" -ForegroundColor Yellow
                $warnCount++
            }
        }
        "remote" {
            Write-Host "  [OK]   Mode Qdrant: remote (gunakan QDRANT_URL / QDRANT_API_KEY)" -ForegroundColor Green
        }
        default {
            Write-Host "  [INFO] qdrantMode belum diset di .addons.json (profil lama)" -ForegroundColor Gray
        }
    }

    $venvPython = Join-Path $mcpDir ".venv\Scripts\python.exe"
    if (Test-Path $venvPython) {
        Write-Host "  [OK]   Python .venv tersedia ($venvPython)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Python .venv belum dibuat di $mcpDir\.venv (opsional)" -ForegroundColor Yellow
        $warnCount++
    }
} else {
    Write-Host "  [SKIP] Add-on Central Memory MCP tidak aktif di .addons.json" -ForegroundColor DarkYellow
}

Write-Host "`n[7/7] Memeriksa Add-on Qdrant SSH Tunnel & Security Scanners..." -ForegroundColor Cyan
if ($sshTunnelEnabled) {
    if (Test-BundleFile -Path (Join-Path $scriptsDir "qdrant-tunnel.ps1") -Label "scripts\qdrant-tunnel.ps1") { $okCount++ } else { $failCount++ }
    if (Test-BundleFile -Path (Join-Path $scriptsDir "qdrant-tunnel-hidden.vbs") -Label "scripts\qdrant-tunnel-hidden.vbs") { $okCount++ } else { $failCount++ }

    if (Get-Command ssh -ErrorAction SilentlyContinue) {
        Write-Host "  [OK]   OpenSSH client tersedia di PATH" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] ssh client tidak ditemukan di PATH" -ForegroundColor Yellow
        $warnCount++
    }

    $sshHostEnv = [Environment]::GetEnvironmentVariable("QDRANT_SSH_HOST", "User")
    if ([string]::IsNullOrWhiteSpace($sshHostEnv)) {
        $sshHostEnv = $env:QDRANT_SSH_HOST
    }
    $sshPortEnv = [Environment]::GetEnvironmentVariable("QDRANT_SSH_PORT", "User")
    if ([string]::IsNullOrWhiteSpace($sshPortEnv)) {
        $sshPortEnv = $env:QDRANT_SSH_PORT
    }
    if ([string]::IsNullOrWhiteSpace($sshPortEnv)) {
        $sshPortEnv = "22"
    }

    if (-not [string]::IsNullOrWhiteSpace($sshHostEnv) -and ($sshHostEnv -notmatch '<SSH_USER>|<VPS_IP>')) {
        Write-Host "  [OK]   Env var QDRANT_SSH_HOST tersedia ($sshHostEnv, port $sshPortEnv)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Env var QDRANT_SSH_HOST belum diset (tunnel akan gagal saat logon/restart)" -ForegroundColor Yellow
        $warnCount++
    }
} else {
    Write-Host "  [SKIP] Add-on Qdrant SSH Tunnel tidak aktif di .addons.json" -ForegroundColor DarkYellow
}

foreach ($tool in @("gitleaks", "trivy")) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        Write-Host "  [OK]   Scanner '$tool' tersedia ($($cmd.Source))" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Scanner '$tool' belum terpasang (opsional untuk verify-gate.mjs)" -ForegroundColor Gray
    }
}
Write-Host "  [SKIP] Scanner 'semgrep' tidak didukung native di Windows" -ForegroundColor DarkYellow

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($failCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "  HASIL: $okCount / $totalRequired komponen wajib OK (Semua sehat!)" -ForegroundColor Green
} elseif ($failCount -eq 0) {
    Write-Host "  HASIL: $okCount / $totalRequired komponen wajib OK ($warnCount peringatan)" -ForegroundColor Yellow
} else {
    Write-Host "  HASIL: $okCount / $totalRequired komponen wajib OK ($failCount gagal, $warnCount peringatan)" -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan

if ($failCount -gt 0) {
    exit 1
}
exit 0
