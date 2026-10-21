# PreToolUse hook (Bash, PowerShell): block `git reset --hard` and `git clean`.
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
    $command = [string]$data.tool_input.command
    if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

    # Tolerate extra options between git and the subcommand, e.g. `git -C dir clean -fd`.
    if ($command -match '(?i)\bgit\b[^;&|\r\n]*\sreset\b[^;&|\r\n]*\s--hard\b' -or
        $command -match '(?i)\bgit\b[^;&|\r\n]*\sclean\b') {
        Send-Decision 'deny' 'this command deletes work, ask a human first'
    }
    exit 0
}
catch {
    Send-Decision 'ask' "Git guard hook could not decide ($($_.Exception.Message)). Allow this command?"
}
