#!/usr/bin/env bash
# step-1-check.sh - check that this computer has the tools of the training. It changes nothing.
# company-transfers-python. Training material. Invented bank.
#
# Run it in Terminal, from the repository folder:
#   bash step-1-check.sh
#
# Each line says:
#   OK    the tool is there, in the recommended version or newer;
#   WARN  the tool works for the training, but it is older than recommended;
#   KO    the tool is missing or too old: run step-2-install-tools.sh, or give
#         INSTALL-TOOLS.md to your IT team;
#   INFO  for your information, nothing to do.
# Next step when there is no KO: step-3-setup.sh.

# Work in the repository folder, wherever the script is called from.
cd "$(dirname "$0")" || exit 1
# Keep the PATH of your terminal, then add the usual install folders, so that a tool
# installed a minute ago is found even before you open a new terminal.
ORIG_PATH=$PATH
for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.dotnet"; do
  [ -d "$d" ] || continue
  case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
done
export PATH
# Colours only in a terminal.
if [ -t 1 ]; then
  red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; cyan=$'\033[36m'; grey=$'\033[90m'; reset=$'\033[0m'
else
  red=''; green=''; yellow=''; cyan=''; grey=''; reset=''
fi

# version_ge 3.12.1 3.11 is true when the first version is the same or newer.
version_ge() {
  local IFS=.
  local -a a b
  read -r -a a <<< "$1"
  read -r -a b <<< "$2"
  local i x y
  for i in 0 1 2; do
    x=${a[i]:-0}; y=${b[i]:-0}
    x=${x%%[!0-9]*}; y=${y%%[!0-9]*}
    x=${x:-0}; y=${y:-0}
    if (( 10#$x > 10#$y )); then return 0; fi
    if (( 10#$x < 10#$y )); then return 1; fi
  done
  return 0
}

ko=0
warn=0
# Print one result line, and count the warnings and the errors.
report() {
  local color=$green
  case "$1" in
    WARN) color=$yellow; warn=$((warn + 1)) ;;
    KO) color=$red; ko=$((ko + 1)) ;;
    INFO) color=$grey ;;
  esac
  printf '%s%-5s %-40s %s%s\n' "$color" "$1" "$2" "$3" "$reset"
}
# Compare a version with the minimum and the recommended one: report_version what found min recommended
report_version() {
  if ! version_ge "$2" "$3"; then report KO "$1" "$2 found, $3 or newer needed."
  elif ! version_ge "$2" "$4"; then report WARN "$1" "$2 found: it works, $4 or newer is recommended."
  else report OK "$1" "$2"
  fi
}
# True when the folder of a program is on the PATH of your terminal.
on_user_path() { case ":$ORIG_PATH:" in *":$(dirname "$1"):"*) return 0 ;; esac; return 1; }

# On macOS, /usr/bin/git and /usr/bin/python3 only open an install dialog when the
# Command Line Tools are missing: do not call them in that case.
is_stub() {
  [ "$(uname -s)" = Darwin ] || return 1
  case "$1" in /usr/bin/git|/usr/bin/python3) ;; *) return 1 ;; esac
  xcode-select -p >/dev/null 2>&1 && return 1
  return 0
}

# Version of a tool that answers to --version, empty when it is not installed.
tool_version() {
  local path
  path=$(command -v "$1" 2>/dev/null) || return 1
  is_stub "$path" && return 1
  "$path" --version 2>&1 | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

# True when the address answers, whatever the HTTP code: the network path is open.
test_url() { curl -sS -o /dev/null -I --max-time 15 "$1" >/dev/null 2>&1; }

# Find Python: the newest python3.x first, then python3 and python. Sets PY_EXE and
# PY_VERSION to the first one that is at least $1 (PY_OK=1), else to the first one
# found (PY_OK=0, too old). Returns 1 when there is no Python at all.
find_python() {
  PY_EXE=''; PY_VERSION=''; PY_OK=0
  local name path v
  for name in python3.14 python3.13 python3.12 python3.11 python3.10 python3 python; do
    path=$(command -v "$name" 2>/dev/null) || continue
    is_stub "$path" && continue
    v=$("$path" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null) || continue
    [ -n "$v" ] || continue
    if version_ge "$v" "$1"; then PY_EXE=$path; PY_VERSION=$v; PY_OK=1; return 0; fi
    if [ -z "$PY_EXE" ]; then PY_EXE=$path; PY_VERSION=$v; fi
  done
  [ -n "$PY_EXE" ]
}

# State of the superpowers plugin for your user: missing, enabled, disabled or unknown.
# Needs PY_EXE to read the JSON.
superpowers_state() {
  local json
  json=$(claude plugin list --json 2>/dev/null) || { echo unknown; return; }
  [ -n "$PY_EXE" ] || { echo unknown; return; }
  printf '%s' "$json" | "$PY_EXE" -c '
import json, sys
try:
    items = json.load(sys.stdin)
except Exception:
    print("unknown"); sys.exit(0)
sp = [p for p in items if str(p.get("id", "")).startswith("superpowers@") and p.get("scope") == "user"]
print("missing" if not sp else ("enabled" if sp[0].get("enabled") else "disabled"))'
}

printf '%sCheck of the training tools: company-transfers-python, %s%s\n\n' "$cyan" "$(uname -s)" "$reset"
printf 'Tools for everyone\n'
git_v=$(tool_version git)
if [ -n "$git_v" ]; then report OK Git "$git_v"
elif [ "$(uname -s)" = Darwin ]; then report KO Git 'not found. Install the Command Line Tools: xcode-select --install'
else report KO Git 'not found.'
fi
claude_v=$(tool_version claude)
if [ -z "$claude_v" ]; then report KO 'Claude Code' 'not found.'
elif on_user_path "$(command -v claude)"; then report OK 'Claude Code' "$claude_v"
else report WARN 'Claude Code' "$claude_v, but $(dirname "$(command -v claude)") is not on your PATH: open a new terminal."
fi
if [ -n "$git_v" ]; then
  # Claude Code commits in cycle 1: git needs a name and an e-mail.
  gname=$(git config user.name); gmail=$(git config user.email)
  if [ -n "$gname" ] && [ -n "$gmail" ]; then report OK 'Git identity' "$gname <$gmail>"
  else report KO 'Git identity' 'missing. Run: git config --global user.name "Your Name" and git config --global user.email "you@example.com"'
  fi
fi

[ -d .git ] || report INFO 'Git repository' 'not yet (ZIP download): step-3-setup.sh creates it, with one commit.'
printf '\nTools of the Python project\n'

if find_python 3.10; then report_version 'Python' "$PY_VERSION" 3.10 3.12
else report KO 'Python' 'not found: 3.10 or newer needed.'
fi
# hookify (cycle 3, P3d, optional) runs its hooks with the command python3.
p3=$(command -v python3 2>/dev/null)
if [ -n "$p3" ] && ! is_stub "$p3" && "$p3" --version >/dev/null 2>&1; then report OK 'python3 command' "$("$p3" --version 2>&1)"
else report WARN 'python3 command' 'missing: hookify (cycle 3, P3d, optional) blocks nothing without it. See INSTALL-TOOLS.md.'
fi

printf '\nClaude Code configuration\n'
if [ -n "$claude_v" ]; then
  case "$(superpowers_state)" in
    disabled) report OK 'Plugin superpowers' 'installed, switched off.' ;;
    enabled) report INFO 'Plugin superpowers' 'switched on: step-3-setup.sh switches it off.' ;;
    missing) report INFO 'Plugin superpowers' 'not installed yet: step-3-setup.sh installs it.' ;;
    *) report INFO 'Plugin superpowers' 'state unknown: step-3-setup.sh handles it.' ;;
  esac
else
  report INFO 'Plugin superpowers' 'checked once Claude Code is installed.'
fi
if [ "$(uname -s)" = Darwin ]; then
  if command -v brew >/dev/null 2>&1; then report INFO Homebrew 'available, for step-2-install-tools.sh.'
  else report INFO Homebrew 'not found: step-2-install-tools.sh needs it (see INSTALL-TOOLS.md).'
  fi
fi

printf '\nNetwork (any answer means the path is open)\n'
for entry in \
  "https://api.anthropic.com api.anthropic.com" \
  "https://claude.ai claude.ai" \
  "https://github.com github.com" \
  "https://pypi.org/simple/ pypi.org" \
  "https://files.pythonhosted.org files.pythonhosted.org" \
  "https://cdn.playwright.dev cdn.playwright.dev" \
  "https://playwright.download.prss.microsoft.com playwright.download.prss.microsoft.com"
do
  url=${entry%% *}; name=${entry#* }
  if test_url "$url"; then report OK "$name" 'reachable'
  else report KO "$name" 'no answer: check the proxy (see INSTALL-TOOLS.md, Network).'
  fi
done

echo
if [ "$ko" -gt 0 ]; then
  printf '%sNot ready yet: %s KO, %s WARN.%s\n' "$red" "$ko" "$warn" "$reset"
  echo 'Missing or old tools: bash step-2-install-tools.sh'
  echo 'or give INSTALL-TOOLS.md to your IT team. Network KO: see INSTALL-TOOLS.md, Network.'
  echo 'Then open a new terminal and run bash step-1-check.sh again.'
  exit 1
fi
printf '%sReady for setup (%s WARN).%s\n' "$green" "$warn" "$reset"
echo 'Before the training, run Claude Code once and log in: claude'
echo 'Next: bash step-3-setup.sh'
exit 0
