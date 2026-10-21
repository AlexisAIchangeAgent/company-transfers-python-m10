#!/usr/bin/env bash
# step-2-install-tools.sh - install the tools that step-1-check.sh reports as missing or too old (macOS).
# company-transfers-python. Training material. Invented bank.
#
# Run it in Terminal, from the repository folder:
#   bash step-2-install-tools.sh [--yes]
#
# It uses Homebrew. A tool that is there and recent enough is never touched.
# It asks before each install; --yes installs without asking. Some installs ask
# for your password (administrator rights), or give INSTALL-TOOLS.md to your IT team.

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

# Print the title of a step.
step() { printf '\n%s==> %s%s\n' "$cyan" "$1" "$reset"; }
# Print an error and stop the script.
fail() { printf '%sFAILED: %s%s\n' "$red" "$1" "$reset"; exit 1; }
# Run a program, and stop the script if it fails.
run() { "$@" || fail "exit code $? for: $*"; }

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

YES=0
case "${1:-}" in --yes|-y) YES=1 ;; esac
installed=''
failed=''
# Ask before an install, unless --yes.
confirm() {
  [ "$YES" = 1 ] && return 0
  printf 'Install %s now? [y/N] ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|o|oui) return 0 ;; esac
  echo "Skipped: $1."
  return 1
}
# Run an install command and remember the result: try_install name command...
try_install() {
  local name=$1; shift
  if "$@"; then installed="$installed $name;"; else failed="$failed $name;"; fi
}

[ "$(uname -s)" = Darwin ] || fail 'step-2-install-tools.sh is for macOS. On Linux, install the tools with your package manager (see INSTALL-TOOLS.md).'

step 'Homebrew'
BREW=$(command -v brew 2>/dev/null || true)
if [ -z "$BREW" ]; then
  echo 'Homebrew not found. Install it first (it asks for your password), then run this script again:'
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo 'At the end, Homebrew prints the lines that add it to your PATH: run them.'
  echo 'Or give INSTALL-TOOLS.md to your IT team.'
  exit 1
fi
"$BREW" --version | head -n 1
case ":$ORIG_PATH:" in
  *":$(dirname "$BREW"):"*) ;;
  *) printf '%sHomebrew is not on your PATH. Add it with:%s\n' "$yellow" "$reset"
     echo "  echo 'eval \"\$($BREW shellenv)\"' >> ~/.zprofile" ;;
esac

step 'Git'
if [ -n "$(tool_version git)" ]; then echo 'Already there: kept.'
elif confirm 'Git'; then try_install Git "$BREW" install git
fi

step 'Claude Code'
if [ -n "$(tool_version claude)" ]; then echo 'Already there: kept.'
elif confirm 'Claude Code'; then
  # Official installer of Anthropic. No administrator rights needed.
  try_install 'Claude Code' bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

step 'Python, 3.10 or newer'
if find_python 3.10 && [ "$PY_OK" = 1 ]; then echo "Python $PY_VERSION: kept."
else
  [ -n "$PY_VERSION" ] && echo "Python $PY_VERSION is too old."
  if confirm 'Python 3.13'; then try_install 'Python 3.13' "$BREW" install python@3.13; fi
fi

step 'Summary'
[ -n "$installed" ] && printf '%sInstalled:%s%s\n' "$green" "$installed" "$reset"
[ -n "$failed" ] && printf '%sNot installed:%s See INSTALL-TOOLS.md.%s\n' "$red" "$failed" "$reset"
[ -z "$installed$failed" ] && echo 'Nothing installed.'
echo 'Open a NEW terminal window, so that the PATH is up to date, then run: bash step-1-check.sh'
[ -z "$failed" ]
