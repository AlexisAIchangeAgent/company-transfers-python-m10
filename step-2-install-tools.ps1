param([switch]$Yes)

# step-2-install-tools.ps1 - install the tools that step-1-check.ps1 reports as missing or too old.
# company-transfers-python. Training material. Invented bank.
#
# Run it in PowerShell 5.1 or 7, from the repository folder:
#   powershell -ExecutionPolicy Bypass -File .\step-2-install-tools.ps1 [-Yes]
#
# It uses winget (Windows 10 1809 or newer, Windows 11). A tool that is there and
# recent enough is never touched. It asks before each install; -Yes installs
# without asking. Some installs show a Windows prompt for administrator rights:
# accept it, or give INSTALL-TOOLS.md to your IT team.

# Tools write warnings on stderr: do not stop on them, check the exit codes instead.
$ErrorActionPreference = 'Continue'
# Work in the repository folder, wherever the script is called from.
Set-Location -LiteralPath $PSScriptRoot
# Allow TLS 1.2 for the network checks (needed by Windows PowerShell 5.1 on old settings).
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Print the title of a step.
function Step([string]$text) { Write-Host ''; Write-Host "==> $text" -ForegroundColor Cyan }
# Print an error and stop the script.
function Fail([string]$text) { Write-Host "FAILED: $text" -ForegroundColor Red; exit 1 }
# Run a program, and stop the script if it fails.
function Invoke-Checked([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { Fail "exit code $LASTEXITCODE for: $exe $($arguments -join ' ')" }
}

# Version of a tool that answers to --version, or $null when it is not installed.
function Get-ToolVersion([string]$exe) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { return $null }
    $text = (& $exe --version 2>&1 | ForEach-Object { "$_" }) -join ' '
    $m = [regex]::Match($text, '\d+\.\d+(\.\d+)?')
    if ($m.Success) { return [version]$m.Value }
    return [version]'0.0'
}

# Find Python: the py launcher first, then python and python3. Returns the first one
# that is at least $min, else the first one found (too old), else $null.
function Find-Python([version]$min) {
    $first = $null
    $candidates = @(
        @{ Exe = 'py'; Pre = @('-3') },
        @{ Exe = 'python'; Pre = @() },
        @{ Exe = 'python3'; Pre = @() }
    )
    foreach ($c in $candidates) {
        if (-not (Get-Command $c.Exe -ErrorAction SilentlyContinue)) { continue }
        $pre = $c.Pre
        $out = & $c.Exe @pre -c 'import sys; print(*sys.version_info[:3], sep=chr(46))' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $out) { continue }
        try { $v = [version]("$out".Trim()) } catch { continue }
        $found = @{ Exe = $c.Exe; Pre = $pre; Version = $v }
        if ($v -ge $min) { return $found }
        if (-not $first) { $first = $found }
    }
    return $first
}

# Read the PATH again from Windows, so that the tools just installed are found.
function Update-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

$script:installed = @()
$script:failed = @()
# Ask before an install, unless -Yes.
function Confirm-Install([string]$what) {
    if ($Yes) { return $true }
    $answer = Read-Host "Install $what now? [y/N]"
    return ($answer -match '^(y|yes|o|oui)$')
}
# Install a package with winget, then read the PATH again.
function Install-WithWinget([string]$id, [string]$what) {
    if (-not (Confirm-Install $what)) { Write-Host "Skipped: $what."; return }
    $wargs = @('install', '--id', $id, '--exact', '--source', 'winget')
    if ($Yes) { $wargs += @('--silent', '--accept-package-agreements', '--accept-source-agreements') }
    & winget @wargs
    $code = $LASTEXITCODE
    Update-Path
    if ($code -eq 0) { $script:installed += $what }
    else { Write-Host "winget ended with code $code for $what." -ForegroundColor Yellow; $script:failed += $what }
}

Step 'winget'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail 'winget not found. Install "App Installer" from the Microsoft Store, or give INSTALL-TOOLS.md to your IT team.'
}
winget --version

Step 'Git for Windows'
if (Get-ToolVersion 'git') { Write-Host 'Already there: kept.' }
else { Install-WithWinget 'Git.Git' 'Git for Windows' }

Step 'Claude Code'
if (Get-ToolVersion 'claude') { Write-Host 'Already there: kept.' }
elseif (Confirm-Install 'Claude Code') {
    # Official installer of Anthropic, in its own PowerShell. No administrator rights needed.
    powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex'
    Update-Path
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $env:Path += ";$env:USERPROFILE\.local\bin" }
    if (Get-ToolVersion 'claude') { $script:installed += 'Claude Code' } else { $script:failed += 'Claude Code' }
}
else { Write-Host 'Skipped: Claude Code.' }

Step 'Python, 3.10 or newer'
$py = Find-Python ([version]'3.10')
if ($py -and $py.Version -ge [version]'3.10') { Write-Host "Python $($py.Version): kept." }
else {
    if ($py) { Write-Host "Python $($py.Version) is too old." }
    Install-WithWinget 'Python.Python.3.13' 'Python 3.13'
}

Step 'Summary'
if ($script:installed.Count -gt 0) { Write-Host "Installed: $($script:installed -join ', ')" -ForegroundColor Green }
if ($script:failed.Count -gt 0) { Write-Host "Not installed: $($script:failed -join ', '). See INSTALL-TOOLS.md." -ForegroundColor Red }
if ($script:installed.Count -eq 0 -and $script:failed.Count -eq 0) { Write-Host 'Nothing installed.' }
Write-Host 'Open a NEW terminal, so that the PATH is up to date, then run:'
Write-Host '  powershell -ExecutionPolicy Bypass -File .\step-1-check.ps1'
if ($script:failed.Count -gt 0) { exit 1 }
exit 0
