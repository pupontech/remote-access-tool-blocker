@echo off
rem PROGRAM 1 - block the remote-access scam PROGRAMS on this PC (Windows App Control).
rem No antivirus needed. Elevation required (it installs/removes a Windows App Control policy).
rem Auto-detects the newest Block-The-Programs.v*.ps1 next to this file.
setlocal
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Block-The-Programs.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Block-The-Programs.v*.ps1 found next to this file.
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