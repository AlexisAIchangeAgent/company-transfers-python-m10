# Starts the Company transfers service on this computer (Windows, PowerShell 5.1 and 7).
#   .\run-local.ps1        start the service, check it, print the URL
#   .\run-local.ps1 stop   stop the service started by this script
# No package, no network: without RATES_BASE_URL the service uses FixedRateClient.
param([string]$Action = 'start')

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

# Run command and port, from CLAUDE.md (Commands table).
$Port = 8000
$Python = '.venv\Scripts\python.exe'
$RunArgs = '-m uvicorn company_transfers.main:app --reload --port 8000'

$LogFile = Join-Path $PSScriptRoot 'run-local.log'
$PidFile = Join-Path $PSScriptRoot 'run-local.pid'
$BaseUrl = "http://127.0.0.1:$Port"
$HealthUrl = "$BaseUrl/health"
$TimeoutSeconds = 120

function Test-Health {
    try {
        $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 2
        return ($r.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Test-PortOpen {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', $Port)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Get-SavedPid {
    if (-not (Test-Path -LiteralPath $PidFile)) { return $null }
    $text = (Get-Content -LiteralPath $PidFile -Raw).Trim()
    if ($text -match '^\d+$') { return [int]$text }
    return $null
}

function Test-ProcessAlive([int]$ProcessId) {
    return [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
}

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

if ($Action -eq 'stop') {
    $savedPid = Get-SavedPid
    if ($null -eq $savedPid) {
        Write-Host 'Nothing to stop: no run-local.pid.'
        exit 0
    }
    if (Test-ProcessAlive $savedPid) {
        # /T also ends the children (uvicorn reloader and server).
        & taskkill.exe /PID $savedPid /T /F | Out-Null
        Start-Sleep -Milliseconds 500
        if (Test-ProcessAlive $savedPid) {
            Fail "cannot stop the process $savedPid (see run-local.pid)."
        }
    }
    Remove-Item -LiteralPath $PidFile -Force
    Write-Host "Service stopped (process $savedPid)."
    exit 0
}

if ($Action -ne 'start') {
    Fail "unknown argument '$Action'. Use no argument to start, or 'stop'."
}

if (Test-Health) {
    Write-Host "The service already answers on port $Port. Nothing to do."
    Write-Host "Health: $HealthUrl"
    Write-Host 'Stop it with: .\run-local.ps1 stop'
    exit 0
}
if (Test-PortOpen) {
    Fail "port $Port is used by another program that does not answer on /health."
}
if (-not (Test-Path -LiteralPath $Python)) {
    Fail "$Python not found. Set up first (CLAUDE.md, Commands: Set up)."
}

# Keep the run offline: no RATES_BASE_URL means FixedRateClient.
Remove-Item Env:RATES_BASE_URL -ErrorAction SilentlyContinue

# cmd redirects stdout and stderr to the same log file; its pid is the root of the tree.
$command = "/c `"`"$Python`" $RunArgs > `"$LogFile`" 2>&1`""
$process = Start-Process -FilePath 'cmd.exe' -ArgumentList $command -WindowStyle Hidden -PassThru
Set-Content -LiteralPath $PidFile -Value $process.Id -Encoding ascii

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    if (-not (Test-ProcessAlive $process.Id)) {
        Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
        Fail "the service stopped at start-up. See run-local.log."
    }
    if (Test-Health) { $ready = $true; break }
    Start-Sleep -Seconds 1
}
if (-not $ready) {
    & taskkill.exe /PID $process.Id /T /F | Out-Null
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Fail "GET /health did not answer within $TimeoutSeconds seconds. See run-local.log."
}

Write-Host "Service started (process $($process.Id)), log in run-local.log."
Write-Host "Health: $HealthUrl"

# Scenario "Instant MDL transfer for a retail customer", amount 2000.00: fee MDL 20.00.
$body = '{"amount": "2000.00", "currency": "MDL", "type": "instant", "customer_segment": "retail"}'
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/fees" -Method Post -Body $body `
        -ContentType 'application/json' -UseBasicParsing -TimeoutSec 10
    $answer = $response.Content
} catch {
    Fail "POST /fees failed: $($_.Exception.Message)"
}
Write-Host "POST /fees $body"
Write-Host "Answer:       $answer"
Write-Host 'Expected fee: MDL 20.00 (instant-fee.feature, retail, MDL 2000.00)'
Write-Host 'Stop it with: .\run-local.ps1 stop'
