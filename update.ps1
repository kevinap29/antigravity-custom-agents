<#
.SYNOPSIS
    Sinkronisasi & update Antigravity Custom Agents, Skills, dan RTK Plugin ke ~/.gemini.
.DESCRIPTION
    Menjalankan 'git pull --ff-only' bila dijalankan di dalam repositori Git yang memiliki remote,
    menyalin ulang aset terbaru melalui install.ps1, lalu memverifikasi dengan verify.ps1.
.PARAMETER GeminiMdMode
    Mode penanganan jika ~/.gemini/GEMINI.md sudah ada: Skip (default saat update), Prompt, Overwrite, atau Merge.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\update.ps1
#>

[CmdletBinding()]
param(
    [ValidateSet("Prompt", "Overwrite", "Merge", "Skip")]
    [string]$GeminiMdMode = "Skip"
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$installScript = Join-Path $scriptRoot "install.ps1"
$verifyScript = Join-Path $scriptRoot "verify.ps1"

if (-not (Test-Path $installScript) -or -not (Test-Path $verifyScript)) {
    throw "Skrip install.ps1 atau verify.ps1 tidak ditemukan di $scriptRoot"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Antigravity Bundle Updater (Windows)                      " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$gitDir = Join-Path $scriptRoot ".git"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ((Test-Path $gitDir) -and ($null -ne $gitCmd)) {
    $remotes = & git -C $scriptRoot remote 2>$null
    if (-not [string]::IsNullOrWhiteSpace(($remotes | Out-String))) {
        Write-Host "[*] Menarik pembaruan terbaru dari Git remote..." -ForegroundColor Yellow
        & git -C $scriptRoot pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            throw "git pull --ff-only gagal. Pastikan tidak ada perubahan lokal yang konflik."
        }
    } else {
        Write-Host "[i] Repositori Git belum memiliki remote; melewati git pull." -ForegroundColor Gray
    }
} else {
    Write-Host "[i] Bukan repositori Git (mode arsip/ZIP); langsung menyinkronkan file lokal." -ForegroundColor Gray
}

Write-Host "`n[*] Menjalankan installer sinkronisasi (GeminiMdMode=$GeminiMdMode)..." -ForegroundColor Yellow
& $installScript -GeminiMdMode $GeminiMdMode
if ($LASTEXITCODE -ne 0) {
    throw "Proses instalasi/sinkronisasi gagal dengan exit code $LASTEXITCODE."
}

Write-Host "`n[*] Menjalankan verifikasi kesehatan instalasi..." -ForegroundColor Yellow
& $verifyScript
exit $LASTEXITCODE
