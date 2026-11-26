<#
.SYNOPSIS
    Global Deterministic Quality & Security Gate for Antigravity SDLC Workflow.
    Auto-detects .NET (Core/6-11, MAUI Blazor, Legacy .NET Framework), Node/SvelteKit,
    Python, and installed static security scanners (gitleaks, semgrep, trivy).
    Exits with code 1 on any failure.
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
        $global:LASTEXITCODE = 0
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

function Find-MsBuild {
    $cmd = Get-Command msbuild -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2>$null | Select-Object -First 1
        if ($found -and (Test-Path $found)) { return $found }
    }
    return $null
}

try {
    # 1. .NET Detection (Modern .NET, MAUI Blazor, or Legacy .NET Framework)
    $csprojFiles = @(Get-ChildItem -Path . -Filter *.csproj -Recurse -Depth 3 -ErrorAction SilentlyContinue)
    $slnFile = Get-ChildItem -Path . -Filter *.sln -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($csprojFiles.Count -gt 0 -or $slnFile) {
        $isLegacyFramework = $false
        $mauiWinTfm = $null
        $mauiProjPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($proj in $csprojFiles) {
            $rawProj = Get-Content $proj.FullName -Raw -ErrorAction SilentlyContinue
            if ($rawProj -match '<TargetFrameworkVersion>v4\.') {
                $isLegacyFramework = $true
            }
            if ($rawProj -match '<UseMaui>\s*true\s*</UseMaui>') {
                [void]$mauiProjPaths.Add($proj.FullName)
                if ($rawProj -match '(net\d+\.\d+-windows[\d\.]+)') {
                    $mauiWinTfm = $Matches[1]
                }
            }
        }

        if ($isLegacyFramework) {
            $msbuildPath = Find-MsBuild
            if ($msbuildPath) {
                $target = if ($slnFile) { $slnFile.FullName } else { $csprojFiles[0].FullName }
                Run-Step "MSBuild (.NET Framework)" { & $msbuildPath $target /nologo /v:minimal }
            } else {
                $summary += "[SKIP] MSBuild (.NET Framework detected, MSBuild unavailable in environment - rely on static verification)"
            }
        } elseif ($mauiWinTfm -and (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            foreach ($mauiProj in $mauiProjPaths) {
                $projName = [System.IO.Path]::GetFileName($mauiProj)
                Run-Step ".NET MAUI Build ($($projName) / $mauiWinTfm)" { dotnet build $mauiProj -f $mauiWinTfm --nologo --verbosity minimal }
            }
            $testProjs = @($csprojFiles | Where-Object { $_.Name -like "*Test*.csproj" -and -not $mauiProjPaths.Contains($_.FullName) })
            foreach ($testProj in $testProjs) {
                Run-Step ".NET Test ($($testProj.Name))" { dotnet test $testProj.FullName --nologo --verbosity minimal }
            }
        } elseif (Get-Command dotnet -ErrorAction SilentlyContinue) {
            Run-Step ".NET Build" { dotnet build --nologo --verbosity minimal }
            $testProj = $csprojFiles | Where-Object { $_.Name -like "*Test*.csproj" } | Select-Object -First 1
            if ($testProj) {
                Run-Step ".NET Test" { dotnet test --no-build --nologo --verbosity minimal }
            }
        }
    }

    # 2. Node / SvelteKit Detection
    if ((Test-Path "package.json") -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        $pkgRaw = Get-Content "package.json" -Raw
        $pkg = $pkgRaw | ConvertFrom-Json
        if ($pkg.scripts -and $pkg.scripts.check) {
            Run-Step "npm run check" { npm run check }
        }
        if ($pkg.scripts -and $pkg.scripts.build) {
            Run-Step "npm run build" { npm run build }
        }
        if ($pkg.scripts -and $pkg.scripts.test) {
            $isVitest = ($pkg.scripts.test -match '\bvitest\b')
            if ($isVitest) {
                Run-Step "npm test (vitest)" { npm test -- --run }
            } else {
                Run-Step "npm test" { npm test }
            }
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
