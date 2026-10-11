@echo off
rem Remote Tools Block (Windows): opens the BLOCK (do) / UNDO / Test mode window. Windows App Control only - no ESET.
rem Asks for administrator rights. Auto-detects the newest Remote-Tools-Block-Windows.v*.ps1 next to this file.
setlocal
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Remote-Tools-Block-Windows.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Remote-Tools-Block-Windows.v*.ps1 found next to this file.
    pause
    exit /b 1
)
net session >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
start "" /min powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TARGET%"
exit /b 0
