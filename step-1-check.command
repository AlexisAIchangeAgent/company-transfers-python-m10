#!/bin/bash
# Training material. Double-click this file in Finder to run step-1-check.sh: check the tools, changes nothing.
# The window stays open at the end, so you can read the result.
cd "$(dirname "$0")" || exit 1
bash ./step-1-check.sh "$@"
echo
read -r -n 1 -s -p 'Press any key to close this window...'
echo
