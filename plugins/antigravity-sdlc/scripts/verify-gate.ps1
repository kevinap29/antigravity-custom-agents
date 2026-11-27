<#
.SYNOPSIS
    Backward-compatible PowerShell wrapper for verify-gate.mjs.
    Auto-detects .NET (Core/6-11, MAUI Blazor, Legacy .NET Framework), Node/SvelteKit,
    Python, and installed static security scanners (gitleaks, semgrep, trivy) via verify-gate.mjs.
    Exits with code 1 on any failure.
#>
param(
    [string]$TargetDir = ".",
    [switch]$SkipSecurity
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$gateMjs = Join-Path $scriptDir "verify-gate.mjs"
if (-not (Test-Path -LiteralPath $gateMjs)) {
    Write-Error "verify-gate.mjs tidak ditemukan di: $gateMjs"
    exit 1
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $nodeCmd) {
    Write-Error "Node.js ('node') diperlukan untuk menjalankan verify-gate.mjs tetapi tidak ditemukan di PATH."
    exit 1
}

$nodeArgs = @($gateMjs, "--target-dir", $TargetDir)
if ($SkipSecurity.IsPresent) {
    $nodeArgs += "--skip-security"
}

& $nodeCmd.Source @nodeArgs
exit $LASTEXITCODE
