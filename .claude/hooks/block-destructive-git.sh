#!/bin/zsh
# PreToolUse hook (Bash), macOS: block `git reset --hard` and `git clean`.
# Same rules as block-destructive-git.ps1 (Windows). Reads the hook JSON on stdin.
# Answers deny, or ask when it cannot decide. JSON is read with the Python of the project.
emulate -L zsh

decision() {  # $1 = deny or ask, $2 = reason (plain text, no double quote)
  print -r -- "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"$1\",\"permissionDecisionReason\":\"$2\"}}"
  exit 0
}

root=${CLAUDE_PROJECT_DIR:-$PWD}
py=$root/.venv/bin/python
[[ -x $py ]] || decision ask "Git guard hook: no .venv in this project, cannot read the command. Allow?"

# Prints "block" if the command deletes work, else nothing.
verdict=$(cat | "$py" -c '
import json, re, sys
cmd = (json.load(sys.stdin).get("tool_input") or {}).get("command") or ""
# Tolerate extra options between git and the subcommand, e.g. `git -C dir clean -fd`.
hard = re.search(r"\bgit\b[^;&|\r\n]*\sreset\b[^;&|\r\n]*\s--hard\b", cmd, re.I)
clean = re.search(r"\bgit\b[^;&|\r\n]*\sclean\b", cmd, re.I)
print("block" if hard or clean else "")
' 2>/dev/null) || decision ask "Git guard hook could not read this command. Allow?"

[[ $verdict == block ]] && decision deny "this command deletes work, ask a human first"
exit 0
