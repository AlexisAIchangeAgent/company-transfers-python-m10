# Hooks of the project (cycle 3 of M5)

Training material. Reference version "end of M5".

| hook | Windows | macOS |
|---|---|---|
| block edits of `.github/workflows/` and `.env` (before Edit, Write, MultiEdit) | `guard-protected-files.ps1` | `guard-protected-files.sh` |
| block `git reset --hard` and `git clean` (before a shell command) | `block-destructive-git.ps1` | `block-destructive-git.sh` |
| run the unit tests after an edit of `src/` or `tests/` | `run-unit-tests.ps1` | `run-unit-tests.sh` |

`.claude/settings.json` runs the Windows scripts (PowerShell).

On macOS: replace the `"hooks"` block of `.claude/settings.json` with the one of
`settings-hooks-macos.json`, then restart Claude Code. The macOS scripts run with zsh and read the
hook data with the Python of the project (`.venv/bin/python`): run the setup script first.
