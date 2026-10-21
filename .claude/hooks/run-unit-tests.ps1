# PostToolUse hook (Edit, Write, MultiEdit): after a source or test edit, run the unit tests.
# Shows PASS or FAIL with the counts to the user, and gives the result to Claude.
$ErrorActionPreference = 'Stop'

function Send-Result([string]$Message, [string]$Context) {
    $out = @{
        systemMessage      = $Message
        hookSpecificOutput = @{
            hookEventName     = 'PostToolUse'
            additionalContext = $Context
        }
    }
    [Console]::Out.WriteLine(($out | ConvertTo-Json -Depth 5 -Compress))
    exit 0
}

try {
    $data = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $path = $data.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($path)) { exit 0 }

    $root = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrWhiteSpace($root)) { $root = $data.cwd }
    if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

    $full = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $path))
    $norm = $full.Replace('\', '/').ToLowerInvariant()
    $base = $root.Replace('\', '/').TrimEnd('/').ToLowerInvariant() + '/'
    if (-not $norm.StartsWith($base) -or -not $norm.EndsWith('.py')) { exit 0 }
    $rel = $norm.Substring($base.Length)
    if (-not ($rel.StartsWith('src/') -or $rel.StartsWith('tests/'))) { exit 0 }

    $python = Join-Path $root '.venv\Scripts\python.exe'
    if (-not (Test-Path $python)) { $python = 'python' }

    Push-Location $root
    $ErrorActionPreference = 'Continue'
    $lines = & $python -m pytest -q 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    Pop-Location

    $text = ($lines -join "`n")
    $summary = ($lines | Where-Object { $_ -match '\b(passed|failed|error|errors|no tests ran)\b' } | Select-Object -Last 1)
    if (-not $summary) { $summary = 'no summary line' }
    $summary = $summary.Trim(' ', '=')

    if ($code -eq 0) {
        Send-Result "Unit tests PASS: $summary" "Unit tests after editing ${rel}: PASS ($summary)"
    }
    $tail = (($lines | Select-Object -Last 25) -join "`n")
    Send-Result "Unit tests FAIL: $summary" "Unit tests after editing ${rel}: FAIL ($summary). Last output:`n$tail"
}
catch {
    Send-Result "Unit test hook error: $($_.Exception.Message)" "The unit test hook itself failed: $($_.Exception.Message)"
}
