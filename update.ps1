<#
.SYNOPSIS
    Sinkronisasi & update Antigravity Custom Agents, SDLC Plugin, RTK Plugin, Deterministic Gate,
    serta Add-ons aktif (~/.gemini/.addons.json) ke ~/.gemini.
.DESCRIPTION
    Menjalankan 'git pull --ff-only' bila dijalankan di dalam repositori Git yang memiliki remote,
    membaca profil add-on (termasuk qdrantMode) dari ~/.gemini/.addons.json, menyalin ulang aset
    terbaru melalui install.ps1, lalu memverifikasi dengan verify.ps1.
.PARAMETER GeminiMdMode
    Mode penanganan jika ~/.gemini/GEMINI.md sudah ada: Skip (default saat update), Prompt, Overwrite, atau Merge.
.PARAMETER WithSecurityTools
    Teruskan flag -WithSecurityTools ke install.ps1.
.PARAMETER WithMemory
    Paksa aktifkan Add-on Central Memory MCP saat update.
.PARAMETER QdrantMode
    Paksa mode Qdrant (Local, Localhost, Remote) saat update.
.PARAMETER WithTunnel
    Paksa aktifkan Add-on Qdrant SSH Tunnel saat update.
.PARAMETER ResponseLanguage
    Bahasa respons AI yang diteruskan ke install.ps1 (fallback dari .addons.json atau English).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\update.ps1
#>

[CmdletBinding()]
param(
    [ValidateSet("Prompt", "Overwrite", "Merge", "Skip")]
    [string]$GeminiMdMode = "Skip",
    [switch]$WithSecurityTools,
    [switch]$WithMemory,
    [ValidateSet("", "Local", "Localhost", "Remote")]
    [string]$QdrantMode = "",
    [switch]$WithTunnel,
    [string]$ResponseLanguage = ""
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

# Baca profil add-on eksisting (~/.gemini/.addons.json)
$resolvedHome = if (-not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_HOME)) {
    $env:ANTIGRAVITY_HOME
} elseif (-not [string]::IsNullOrWhiteSpace($HOME)) {
    $HOME
} else {
    $env:USERPROFILE
}
$addonsProfilePath = Join-Path (Join-Path $resolvedHome ".gemini") ".addons.json"
$enableMemory = $WithMemory.IsPresent
$enableTunnel = $WithTunnel.IsPresent
$resolvedQdrantMode = $QdrantMode
$resolvedResponseLanguage = $ResponseLanguage
if (Test-Path $addonsProfilePath) {
    try {
        $savedAddons = Get-Content -Path $addonsProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($savedAddons.centralMemory -eq $true) { $enableMemory = $true }
        if ($savedAddons.sshTunnel -eq $true) { $enableTunnel = $true }
        if ([string]::IsNullOrWhiteSpace($resolvedResponseLanguage) -and -not [string]::IsNullOrWhiteSpace([string]$savedAddons.responseLanguage)) {
            $resolvedResponseLanguage = ([string]$savedAddons.responseLanguage).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($resolvedQdrantMode) -and $enableMemory) {
            $savedMode = [string]$savedAddons.qdrantMode
            switch ($savedMode.ToLowerInvariant()) {
                "local" { $resolvedQdrantMode = "Local" }
                "localhost" { $resolvedQdrantMode = "Localhost" }
                "remote" { $resolvedQdrantMode = "Remote" }
                default {
                    if ($enableTunnel) { $resolvedQdrantMode = "Remote" } else { $resolvedQdrantMode = "Local" }
                }
            }
        }
        Write-Host "[i] Profil .addons.json ditemukan (responseLanguage=$(if ($resolvedResponseLanguage) { $resolvedResponseLanguage } else { 'English' }), centralMemory=$enableMemory, qdrantMode=$resolvedQdrantMode, sshTunnel=$enableTunnel)." -ForegroundColor Gray
    } catch {
        Write-Host "[WARN] Gagal membaca $addonsProfilePath; menggunakan flag CLI saja." -ForegroundColor Yellow
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedResponseLanguage)) {
    $resolvedResponseLanguage = "English"
}

$installArgs = @{
    GeminiMdMode     = $GeminiMdMode
    ResponseLanguage = $resolvedResponseLanguage
    NonInteractive   = $true
}
if ($WithSecurityTools.IsPresent) { $installArgs["WithSecurityTools"] = $true }
if ($enableMemory) {
    $installArgs["WithMemory"] = $true
    if (-not [string]::IsNullOrWhiteSpace($resolvedQdrantMode)) {
        $installArgs["QdrantMode"] = $resolvedQdrantMode
    }
}
if ($enableTunnel) { $installArgs["WithTunnel"] = $true }

Write-Host "`n[*] Menjalankan installer sinkronisasi (GeminiMdMode=$GeminiMdMode)..." -ForegroundColor Yellow
$global:LASTEXITCODE = 0
& $installScript @installArgs
if ($LASTEXITCODE -ne 0) {
    throw "Proses instalasi/sinkronisasi gagal dengan exit code $LASTEXITCODE."
}

Write-Host "`n[*] Menjalankan verifikasi kesehatan instalasi..." -ForegroundColor Yellow
$global:LASTEXITCODE = 0
& $verifyScript
exit $LASTEXITCODE
