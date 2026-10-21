#!/bin/zsh
# PreToolUse hook (Edit, Write, MultiEdit), macOS: block .github/workflows/ and .env files.
# Same rules as guard-protected-files.ps1 (Windows). Reads the hook JSON on stdin.
# Answers deny, or ask when it cannot decide. JSON is read with the Python of the project.
emulate -L zsh

decision() {  # $1 = deny or ask, $2 = reason (plain text, no double quote)
  print -r -- "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"$1\",\"permissionDecisionReason\":\"$2\"}}"
  exit 0
}

root=${CLAUDE_PROJECT_DIR:-$PWD}
py=$root/.venv/bin/python
[[ -x $py ]] || decision ask "Protection hook: no .venv in this project, cannot read the edit. Allow?"

# Prints the full normalized path of the edited file, or nothing.
full=$(cat | "$py" -c '
import json, os, sys
root = sys.argv[1]
p = (json.load(sys.stdin).get("tool_input") or {}).get("file_path") or ""
print(os.path.normpath(os.path.join(root, p)) if p else "")
' "$root" 2>/dev/null) || decision ask "Protection hook could not read this edit. Allow?"
[[ -n $full ]] || decision ask "Protection hook: no file path in this edit, cannot tell if it touches .github/workflows/ or .env. Allow?"

norm=${full:l}
name=${norm:t}
if [[ $norm == */.github/workflows || $norm == */.github/workflows/* ]]; then
  decision deny "BLOCKED: .github/workflows/ (pipeline files) is protected by CLAUDE.md section 4. A human must edit it or lift this hook."
fi
if [[ $name == .env || $name == .env.* ]]; then
  decision deny "BLOCKED: .env is protected by CLAUDE.md section 4. A human must edit it or lift this hook."
fi
exit 0
