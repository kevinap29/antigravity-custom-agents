<#
.SYNOPSIS
    Rollback / uninstall komponen bundle Antigravity Custom Agents secara aman dan idempoten.
.DESCRIPTION
    Menghapus hanya 9 agent bundle, 3 skill bundle, dan plugin RTK dari ~/.gemini
    tanpa menyentuh file pribadi, custom agent/skill lain, atau GEMINI.md milik user.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$geminiDir = Join-Path $HOME ".gemini"
$configAgentsDir = Join-Path $geminiDir "config\agents"
$antigravityAgentsDir = Join-Path $geminiDir "antigravity\agents"
$configSkillsDir = Join-Path $geminiDir "config\skills"
$configRtkDir = Join-Path $geminiDir "config\plugins\rtk"

$bundleAgents = @(
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

$bundleSkills = @(
    "dotnet-webforms-patterns",
    "frontend-mobile-patterns",
    "portainer-harbor-deploy"
)

$removedCount = 0

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Antigravity Bundle Uninstaller (Windows)                  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Target direktori: $geminiDir`n" -ForegroundColor Gray

Write-Host "[1/3] Menghapus 9 Custom Agents bundle..." -ForegroundColor Yellow
foreach ($agent in $bundleAgents) {
    foreach ($dir in @($configAgentsDir, $antigravityAgentsDir)) {
        $targetPath = Join-Path $dir $agent
        $item = Get-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            Remove-Item -LiteralPath $targetPath -Force
            Write-Host "  [-] Dihapus: $targetPath" -ForegroundColor Gray
            $removedCount++
        }
    }
}

Write-Host "`n[2/3] Menghapus 3 Custom Skills bundle..." -ForegroundColor Yellow
foreach ($skill in $bundleSkills) {
    $skillPath = Join-Path $configSkillsDir $skill
    $item = Get-Item -LiteralPath $skillPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        Remove-Item -LiteralPath $skillPath -Recurse -Force
        Write-Host "  [-] Dihapus: $skillPath" -ForegroundColor Gray
        $removedCount++
    }
}

Write-Host "`n[3/3] Menghapus Plugin RTK bundle..." -ForegroundColor Yellow
$rtkItem = Get-Item -LiteralPath $configRtkDir -Force -ErrorAction SilentlyContinue
if ($null -ne $rtkItem) {
    Remove-Item -LiteralPath $configRtkDir -Recurse -Force
    Write-Host "  [-] Dihapus: $configRtkDir" -ForegroundColor Gray
    $removedCount++
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "  UNINSTALL SELESAI ($removedCount item dihapus)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Catatan: File $geminiDir\GEMINI.md serta agent/skill pribadi Anda tetap dipertahankan." -ForegroundColor Cyan
