# step-1-check.ps1 - check that this computer has the tools of the training. It changes nothing.
# company-transfers-python. Training material. Invented bank.
#
# Run it in PowerShell 5.1 or 7, from the repository folder:
#   powershell -ExecutionPolicy Bypass -File .\step-1-check.ps1
#
# Each line says:
#   OK    the tool is there, in the recommended version or newer;
#   WARN  the tool works for the training, but it is older than recommended;
#   KO    the tool is missing or too old: run step-2-install-tools.ps1, or give
#         INSTALL-TOOLS.md to your IT team;
#   INFO  for your information, nothing to do.
# Next step when there is no KO: step-3-setup.ps1.

# Tools write warnings on stderr: do not stop on them, check the exit codes instead.
$ErrorActionPreference = 'Continue'
# Work in the repository folder, wherever the script is called from.
Set-Location -LiteralPath $PSScriptRoot
# Allow TLS 1.2 for the network checks (needed by Windows PowerShell 5.1 on old settings).
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$script:ko = 0
$script:warn = 0
# Print one result line, and count the warnings and the errors.
function Report([string]$status, [string]$what, [string]$detail) {
    $color = 'Green'
    if ($status -eq 'WARN') { $color = 'Yellow'; $script:warn++ }
    if ($status -eq 'KO') { $color = 'Red'; $script:ko++ }
    if ($status -eq 'INFO') { $color = 'Gray' }
    Write-Host ('{0,-5} {1,-40} {2}' -f $status, $what, $detail) -ForegroundColor $color
}
# Compare a version with the minimum and the recommended one.
function Report-Version([string]$what, [version]$found, [version]$min, [version]$rec) {
    if ($found -lt $min) { Report 'KO' $what "$found found, $min or newer needed." }
    elseif ($found -lt $rec) { Report 'WARN' $what "$found found: it works, $rec or newer is recommended." }
    else { Report 'OK' $what "$found" }
}

# Version of a tool that answers to --version, or $null when it is not installed.
function Get-ToolVersion([string]$exe) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { return $null }
    $text = (& $exe --version 2>&1 | ForEach-Object { "$_" }) -join ' '
    $m = [regex]::Match($text, '\d+\.\d+(\.\d+)?')
    if ($m.Success) { return [version]$m.Value }
    return [version]'0.0'
}

# True when the address answers, whatever the HTTP code: the network path is open.
function Test-Url([string]$url) {
    try { $null = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 15; return $true }
    catch { return [bool]$_.Exception.Response }
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

Write-Host 'Check of the training tools: company-transfers-python, Windows' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Tools for everyone'
$git = Get-ToolVersion 'git'
if ($git) { Report 'OK' 'Git' "$git" } else { Report 'KO' 'Git' 'not found. Claude Code on Windows needs Git for Windows.' }
$claude = Get-ToolVersion 'claude'
if ($claude) { Report 'OK' 'Claude Code' "$claude" } else { Report 'KO' 'Claude Code' 'not found.' }
if ($git) {
    # Claude Code commits in cycle 1: git needs a name and an e-mail.
    $gname = git config user.name
    $gmail = git config user.email
    if ($gname -and $gmail) { Report 'OK' 'Git identity' "$gname <$gmail>" }
    else { Report 'KO' 'Git identity' 'missing. Run: git config --global user.name "Your Name" and git config --global user.email "you@example.com"' }
}

if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) { Report 'INFO' 'Git repository' 'not yet (ZIP download): step-3-setup.ps1 creates it, with one commit.' }
Write-Host ''
Write-Host 'Tools of the Python project'

$py = Find-Python ([version]'3.10')
if (-not $py) { Report 'KO' 'Python' 'not found: 3.10 or newer needed.' }
else { Report-Version 'Python' $py.Version ([version]'3.10') ([version]'3.12') }
# hookify (cycle 3, P3d, optional) runs its hooks with the command python3.
$p3 = cmd /c "python3 --version 2>&1"
if ($LASTEXITCODE -eq 0 -and "$p3" -match 'Python 3') { Report 'OK' 'python3 command' "$p3" }
else { Report 'WARN' 'python3 command' 'missing: hookify (cycle 3, P3d, optional) blocks nothing without it. See INSTALL-TOOLS.md.' }

Write-Host ''
Write-Host 'Claude Code configuration'
if ($claude) {
    switch (Get-SuperpowersState) {
        'disabled' { Report 'OK' 'Plugin superpowers' 'installed, switched off.' }
        'enabled' { Report 'INFO' 'Plugin superpowers' 'switched on: step-3-setup.ps1 switches it off.' }
        'missing' { Report 'INFO' 'Plugin superpowers' 'not installed yet: step-3-setup.ps1 installs it.' }
        default { Report 'INFO' 'Plugin superpowers' 'state unknown: step-3-setup.ps1 handles it.' }
    }
}
else { Report 'INFO' 'Plugin superpowers' 'checked once Claude Code is installed.' }
if (Get-Command winget -ErrorAction SilentlyContinue) { Report 'INFO' 'winget' 'available, for step-2-install-tools.ps1.' }
else { Report 'INFO' 'winget' 'not found: step-2-install-tools.ps1 needs it (App Installer, Microsoft Store).' }

Write-Host ''
Write-Host 'Network (any answer means the path is open)'
$hosts = @(
    @('https://api.anthropic.com', 'api.anthropic.com'),
    @('https://claude.ai', 'claude.ai'),
    @('https://github.com', 'github.com'),
    @('https://pypi.org/simple/', 'pypi.org'),
    @('https://files.pythonhosted.org', 'files.pythonhosted.org'),
    @('https://cdn.playwright.dev', 'cdn.playwright.dev'),
    @('https://playwright.download.prss.microsoft.com', 'playwright.download.prss.microsoft.com')
)
foreach ($h in $hosts) {
    if (Test-Url $h[0]) { Report 'OK' $h[1] 'reachable' }
    else { Report 'KO' $h[1] 'no answer: check the proxy (see INSTALL-TOOLS.md, Network).' }
}

Write-Host ''
if ($script:ko -gt 0) {
    Write-Host "Not ready yet: $($script:ko) KO, $($script:warn) WARN." -ForegroundColor Red
    Write-Host 'Missing or old tools: powershell -ExecutionPolicy Bypass -File .\step-2-install-tools.ps1'
    Write-Host 'or give INSTALL-TOOLS.md to your IT team. Network KO: see INSTALL-TOOLS.md, Network.'
    Write-Host 'Then open a new terminal and run step-1-check.ps1 again.'
    exit 1
}
Write-Host "Ready for setup ($($script:warn) WARN)." -ForegroundColor Green
Write-Host 'Before the training, run Claude Code once and log in: claude'
Write-Host 'Next: powershell -ExecutionPolicy Bypass -File .\step-3-setup.ps1'
exit 0
