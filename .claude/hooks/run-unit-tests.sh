#!/bin/zsh
# PostToolUse hook (Edit, Write, MultiEdit), macOS: after a source or test edit, run the unit tests.
# Same behaviour as run-unit-tests.ps1 (Windows): shows PASS or FAIL with the counts to the user,
# and gives the result to Claude. JSON is read and written with the Python of the project.
emulate -L zsh

root=${CLAUDE_PROJECT_DIR:-$PWD}
py=$root/.venv/bin/python
[[ -x $py ]] || {
  print -r -- '{"systemMessage":"Unit test hook error: no .venv in this project"}'
  exit 0
}

# Relative path of the edited file if it is a .py file under src/ or tests/, else nothing.
rel=$(cat | "$py" -c '
import json, os, sys
root = os.path.normpath(sys.argv[1])
p = (json.load(sys.stdin).get("tool_input") or {}).get("file_path") or ""
if p:
    full = os.path.normpath(os.path.join(root, p))
    rel = os.path.relpath(full, root).replace(os.sep, "/")
    if full.lower().endswith(".py") and rel.lower().startswith(("src/", "tests/")):
        print(rel)
' "$root" 2>/dev/null)
[[ -n $rel ]] || exit 0

out=$(cd "$root" && "$py" -m pytest -q 2>&1)
code=$?

print -r -- "$out" | "$py" -c '
import json, re, sys
rel, code = sys.argv[1], int(sys.argv[2])
lines = sys.stdin.read().splitlines()
hits = [l for l in lines if re.search(r"\b(passed|failed|error|errors|no tests ran)\b", l)]
summary = (hits[-1] if hits else "no summary line").strip(" =")
if code == 0:
    msg, ctx = f"Unit tests PASS: {summary}", f"Unit tests after editing {rel}: PASS ({summary})"
else:
    tail = "\n".join(lines[-25:])
    msg = f"Unit tests FAIL: {summary}"
    ctx = f"Unit tests after editing {rel}: FAIL ({summary}). Last output:\n{tail}"
print(json.dumps({"systemMessage": msg,
                  "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ctx}}))
' "$rel" "$code"
exit 0
