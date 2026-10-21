@echo off
rem Training material. Double-click this file to run step-3-setup.ps1: install the dependencies of the project.
rem The window stays open at the end, so you can read the result.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0step-3-setup.ps1" %*
echo.
pause
