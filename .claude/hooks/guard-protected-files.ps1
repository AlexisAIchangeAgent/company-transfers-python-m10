# PreToolUse hook (Edit, Write, MultiEdit): block .github/workflows/ and .env files.
# Reads the hook JSON on stdin. Answers deny, or ask when it cannot decide.
$ErrorActionPreference = 'Stop'

function Send-Decision([string]$Decision, [string]$Reason) {
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = $Reason
        }
    }
    [Console]::Out.WriteLine(($out | ConvertTo-Json -Depth 5 -Compress))
    exit 0
}

try {
    $raw = [Console]::In.ReadToEnd()
    $data = $raw | ConvertFrom-Json
    $path = $data.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($path)) {
        Send-Decision 'ask' 'Protection hook: no file path in this edit, cannot tell if it touches .github/workflows/ or .env. Allow?'
    }

    $root = $env:CLAUDE_PROJECT_DIR
    if ([string]::IsNullOrWhiteSpace($root)) { $root = $data.cwd }
    if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

    $full = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $path))
    $norm = $full.Replace('\', '/').ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($full).ToLowerInvariant()

    if ($norm -match '/\.github/workflows(/|$)') {
        Send-Decision 'deny' 'BLOCKED: .github/workflows/ (pipeline files) is protected by CLAUDE.md section 4. A human must edit it or lift this hook.'
    }
    if ($name -eq '.env' -or $name.StartsWith('.env.')) {
        Send-Decision 'deny' 'BLOCKED: .env is protected by CLAUDE.md section 4. A human must edit it or lift this hook.'
    }
    exit 0
}
catch {
    Send-Decision 'ask' "Protection hook could not decide ($($_.Exception.Message)). Allow this edit?"
}
