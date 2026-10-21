# step-3-setup.ps1 - install the dependencies of the project, then check that the unit tests pass.
# company-transfers-python. Training material. Invented bank.
#
# Run it in PowerShell 5.1 or 7, from the repository folder:
#   powershell -ExecutionPolicy Bypass -File .\step-3-setup.ps1
#
# What a developer does on a new project: virtual environment .venv, packages of requirements-dev.txt, Playwright browser,
# the superpowers plugin of Claude Code (switched off), then the unit tests.
# Run step-1-check.ps1 first: the tools must be installed.
# It needs network access. Safe to run again: it keeps what is installed.

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

# State of the superpowers plugin for your user: missing, enabled, disabled or unknown.
function Get-SuperpowersState {
    $json = (& claude plugin list --json 2>$null) | Out-String
    if ($LASTEXITCODE -ne 0) { return 'unknown' }
    try { $list = $json | ConvertFrom-Json } catch { return 'unknown' }
    $sp = @($list | Where-Object { "$($_.id)" -like 'superpowers@*' -and $_.scope -eq 'user' })
    if ($sp.Count -eq 0) { return 'missing' }
    if ($sp[0].enabled) { return 'enabled' }
    return 'disabled'
}

Step 'Git repository'
# The ZIP of a GitHub release has no .git folder: create the repository and its first commit.
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git')) { Write-Host 'Already a git repository: kept.' }
else {
    if (-not ((git config user.name) -and (git config user.email))) {
        Fail 'git needs a name and an e-mail first: git config --global user.name "Your Name" and git config --global user.email "you@example.com"'
    }
    Invoke-Checked 'git' @('init', '-q', '-b', 'main')
    Invoke-Checked 'git' @('-c', 'core.safecrlf=false', 'add', '-A')
    Invoke-Checked 'git' @('commit', '-q', '-m', 'Starter repository, training material')
    Write-Host 'Created: a git repository with one commit.'
}

Step 'Python, 3.10 or newer'
$py = Find-Python ([version]'3.10')
if (-not $py -or $py.Version -lt [version]'3.10') { Fail 'Python 3.10 or newer not found. Run step-1-check.ps1, then step-2-install-tools.ps1.' }
$pyExe = $py.Exe
$pyPre = $py.Pre
Write-Host "Python $($py.Version)"

Step 'Virtual environment .venv'
# Create it only if it is not there yet.
$venvPy = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (Test-Path -LiteralPath $venvPy) { Write-Host 'Already there: kept.' }
else { Invoke-Checked $pyExe ($pyPre + @('-m', 'venv', '.venv')) }

Step 'Packages of requirements-dev.txt (about 2 minutes the first time)'
# pip installs only what is missing: pytest, behave, ruff, Playwright, the Claude Agent SDK...
Invoke-Checked $venvPy @('-m', 'pip', 'install', '--disable-pip-version-check', '-r', 'requirements-dev.txt')

Step 'Playwright browser, used in cycle 5'
# Downloads Chromium once. Does nothing if it is already installed.
Invoke-Checked $venvPy @('-m', 'playwright', 'install', 'chromium')

Step 'Plugin superpowers, used in cycle 1: installed, then switched off'
$spNote = ''
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $spNote = 'Claude Code not found: plugin skipped. Run step-1-check.ps1.' }
else {
    # Install only when missing: installing again would switch it on.
    if ((Get-SuperpowersState) -eq 'missing') {
        & claude plugin install superpowers@claude-plugins-official
        if ($LASTEXITCODE -ne 0) {
            # The marketplace of Anthropic is out of date or not registered: update or add it, then try again.
            & claude plugin marketplace update claude-plugins-official
            if ($LASTEXITCODE -ne 0) { & claude plugin marketplace add anthropics/claude-plugins-official }
            & claude plugin install superpowers@claude-plugins-official
        }
    }
    if ((Get-SuperpowersState) -eq 'enabled') { & claude plugin disable superpowers@claude-plugins-official --scope user }
    $state = Get-SuperpowersState
    if ($state -eq 'disabled') { Write-Host 'OK: installed, switched off.' }
    else { $spNote = "superpowers is $state. P1e of cycle 1 (optional) needs it installed and switched off." }
}
if ($spNote) { Write-Host "WARNING: $spNote" -ForegroundColor Yellow }

Step 'Unit tests (all must pass)'
Invoke-Checked $venvPy @('-m', 'pytest', '-q')

Step 'Ready for cycle 1'
if ($spNote) { Write-Host "Except: $spNote" -ForegroundColor Yellow }
Write-Host 'Next: start Claude Code in this folder with: claude'
