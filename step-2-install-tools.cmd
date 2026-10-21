@echo off
rem Training material. Double-click this file to run step-2-install-tools.ps1: install the missing tools.
rem The window stays open at the end, so you can read the result.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step-2-install-tools.ps1" %*
echo.
pause
