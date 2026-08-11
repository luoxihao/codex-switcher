@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0codex-switcher-main.ps1" %*
exit /b %ERRORLEVEL%
