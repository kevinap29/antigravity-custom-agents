<#
.SYNOPSIS
    Global Deterministic Quality & Security Gate for Antigravity SDLC Workflow.
    Auto-detects .NET, Node/SvelteKit, Python, and installed static security scanners
    (gitleaks, semgrep, trivy). Exits with code 1 on any failure.
#>
param(
    [string]$TargetDir = ".",
    [switch]$SkipSecurity
)

$ErrorActionPreference = "Stop"
$resolvedDir = (Resolve-Path $TargetDir).Path
Push-Location $resolvedDir

$failed = $false
$summary = @()

function Run-Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Host "`n[GATE] Running: $Name ..." -ForegroundColor Cyan
    try {
        & $Action
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] $Name (exit code $LASTEXITCODE)" -ForegroundColor Red
            $script:failed = $true
            $script:summary += "[FAIL] $Name"
        } else {
            Write-Host "[PASS] $Name" -ForegroundColor Green
            $script:summary += "[PASS] $Name"
        }
    } catch {
        Write-Host "[FAIL] $Name : $_" -ForegroundColor Red
        $script:failed = $true
        $script:summary += "[FAIL] $Name"
    }
}

try {
    # 1. .NET Detection
    $slnOrCsproj = Get-ChildItem -Path . -Include *.sln,*.csproj -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($slnOrCsproj -and (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Run-Step ".NET Build" { dotnet build --nologo --verbosity minimal }
        $testProj = Get-ChildItem -Path . -Filter *Test*.csproj -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($testProj) {
            Run-Step ".NET Test" { dotnet test --no-build --nologo --verbosity minimal }
        }
    }

    # 2. Node / SvelteKit Detection
    if ((Test-Path "package.json") -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
        if ($pkg.scripts.check) {
            Run-Step "npm run check" { npm run check }
        }
        if ($pkg.scripts.build) {
            Run-Step "npm run build" { npm run build }
        }
        if ($pkg.scripts.test) {
            Run-Step "npm test" { npm test -- --run }
        }
    }

    # 3. Python Detection
    if (((Test-Path "pyproject.toml") -or (Test-Path "requirements.txt")) -and (Get-Command pytest -ErrorAction SilentlyContinue)) {
        Run-Step "pytest" { pytest -q }
    }

    # 4. Static Security Scanners (Optional — runs if installed on host)
    if (-not $SkipSecurity) {
        if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
            Run-Step "Gitleaks (Secrets Scan)" { gitleaks detect --source . --no-git --redact }
        } else {
            $summary += "[SKIP] Gitleaks (not installed)"
        }

        if (Get-Command semgrep -ErrorAction SilentlyContinue) {
            Run-Step "Semgrep (SAST Scan)" { semgrep scan --config auto --error --quiet }
        } else {
            $summary += "[SKIP] Semgrep (not installed)"
        }

        if (Get-Command trivy -ErrorAction SilentlyContinue) {
            Run-Step "Trivy (Dependency Scan)" { trivy fs --severity HIGH,CRITICAL --exit-code 1 --quiet . }
        } else {
            $summary += "[SKIP] Trivy (not installed)"
        }
    }

    Write-Host "`n========== VERIFY GATE SUMMARY ==========" -ForegroundColor Yellow
    $summary | ForEach-Object { Write-Host $_ }
    Write-Host "=========================================" -ForegroundColor Yellow

    if ($failed) {
        exit 1
    }
    exit 0
}
finally {
    Pop-Location
}
