@echo off
setlocal
set "SCRIPT=%~dp0scripts\rammap\Clear-RAMMapCaches.ps1"
where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)
