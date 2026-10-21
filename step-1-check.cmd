@echo off
rem Training material. Double-click this file to run step-1-check.ps1: check the tools, changes nothing.
rem The window stays open at the end, so you can read the result.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step-1-check.ps1" %*
echo.
pause
