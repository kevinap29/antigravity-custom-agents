<#
.SYNOPSIS
    Auto-reconnecting SSH Local Port Forwarding tunnel for Qdrant VPS (127.0.0.1:6333).
    Designed to run hidden at Windows logon via Task Scheduler.
.PARAMETER SshHost
    Target SSH host (<user>@<vps-ip>). Defaults to $env:QDRANT_SSH_HOST or '<SSH_USER>@<VPS_IP>'.
.PARAMETER SshPort
    Target SSH port. Defaults to $env:QDRANT_SSH_PORT or '22'.
#>
param(
    [string]$SshHost = $(if (-not [string]::IsNullOrWhiteSpace($env:QDRANT_SSH_HOST)) { $env:QDRANT_SSH_HOST } else { "<SSH_USER>@<VPS_IP>" }),
    [string]$SshPort = $(if (-not [string]::IsNullOrWhiteSpace($env:QDRANT_SSH_PORT)) { $env:QDRANT_SSH_PORT } else { "22" })
)

$ErrorActionPreference = "Continue"

$localPort = 6333
$remoteTarget = "127.0.0.1:6333"

$logDir = Join-Path $env:USERPROFILE ".gemini\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir "qdrant-tunnel.log"

if ([string]::IsNullOrWhiteSpace($SshHost) -or $SshHost -match '<SSH_USER>|<VPS_IP>') {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$ts] ERROR: Set QDRANT_SSH_HOST (e.g. user@vps-ip) or pass -SshHost before starting the tunnel."
    exit 1
}

# Single-instance guard via named Mutex
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, "Global\AntigravityQdrantTunnelMutex", [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

try {
    while ($true) {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logFile -Value "[$ts] Starting SSH tunnel to ${SshHost}:${SshPort} (local $localPort -> $remoteTarget)"

        & ssh.exe -N `
            -p $SshPort `
            -L "127.0.0.1:${localPort}:${remoteTarget}" `
            -o "BatchMode=yes" `
            -o "ExitOnForwardFailure=yes" `
            -o "ServerAliveInterval=30" `
            -o "ServerAliveCountMax=3" `
            -o "ConnectTimeout=10" `
            -o "StrictHostKeyChecking=accept-new" `
            $SshHost 2>> $logFile

        $tsEnd = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logFile -Value "[$tsEnd] Tunnel exited (code $LASTEXITCODE). Reconnecting in 5s..."
        Start-Sleep -Seconds 5
    }
}
finally {
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
