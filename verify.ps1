<#
.SYNOPSIS
    Verifikasi kesehatan instalasi Antigravity Custom Agents, Skills, RTK Plugin, dan GEMINI.md.
.DESCRIPTION
    Memeriksa 9 agent di ~/.gemini/config/agents & ~/.gemini/antigravity/agents,
    3 skill di ~/.gemini/config/skills, 3 file plugin RTK di ~/.gemini/config/plugins/rtk,
    keberadaan binary 'rtk' di PATH, dan ~/.gemini/GEMINI.md.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$geminiDir = Join-Path $HOME ".gemini"
$configAgentsDir = Join-Path $geminiDir "config\agents"
$antigravityAgentsDir = Join-Path $geminiDir "antigravity\agents"
$configSkillsDir = Join-Path $geminiDir "config\skills"
$configRtkDir = Join-Path $geminiDir "config\plugins\rtk"
$geminiMdPath = Join-Path $geminiDir "GEMINI.md"

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

$expectedSkills = @(
    "dotnet-webforms-patterns",
    "frontend-mobile-patterns",
    "portainer-harbor-deploy"
)

$expectedRtkFiles = @(
    "plugin.json",
    "hooks.json",
    "rules\AGENTS.md"
)

$okCount = 0
$warnCount = 0
$failCount = 0
$totalRequired = ($expectedAgents.Count * 2) + $expectedSkills.Count + $expectedRtkFiles.Count + 1

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

Write-Host "[1/5] Memeriksa Agents di config\agents ($($expectedAgents.Count) file)..." -ForegroundColor Cyan
foreach ($agent in $expectedAgents) {
    $path = Join-Path $configAgentsDir $agent
    if (Test-BundleFile -Path $path -Label "config\agents\$agent") { $okCount++ } else { $failCount++ }
}

Write-Host "`n[2/5] Memeriksa Agents di antigravity\agents ($($expectedAgents.Count) file)..." -ForegroundColor Cyan
foreach ($agent in $expectedAgents) {
    $path = Join-Path $antigravityAgentsDir $agent
    if (Test-BundleFile -Path $path -Label "antigravity\agents\$agent") { $okCount++ } else { $failCount++ }
}

Write-Host "`n[3/5] Memeriksa Custom Skills ($($expectedSkills.Count) skill)..." -ForegroundColor Cyan
foreach ($skill in $expectedSkills) {
    $path = Join-Path $configSkillsDir "$skill\SKILL.md"
    if (Test-BundleFile -Path $path -Label "config\skills\$skill\SKILL.md") { $okCount++ } else { $failCount++ }
}

Write-Host "`n[4/5] Memeriksa Plugin RTK & Binary CLI..." -ForegroundColor Cyan
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

Write-Host "`n[5/5] Memeriksa Global Rules (GEMINI.md)..." -ForegroundColor Cyan
if (Test-BundleFile -Path $geminiMdPath -Label "GEMINI.md") { $okCount++ } else { $failCount++ }

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
