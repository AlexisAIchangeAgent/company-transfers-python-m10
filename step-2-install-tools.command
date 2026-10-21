#!/bin/bash
# Training material. Double-click this file in Finder to run step-2-install-tools.sh: install the missing tools.
# The window stays open at the end, so you can read the result.
cd "$(dirname "$0")" || exit 1
bash ./step-2-install-tools.sh "$@"
echo
read -r -n 1 -s -p 'Press any key to close this window...'
echo
