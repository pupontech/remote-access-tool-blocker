@echo off
rem PROGRAM 2 - block the remote-access tools' WEBSITES in ESET.
rem Needs ESET installed. No administrator rights needed (it only writes a file and opens windows).
rem Auto-detects the newest Block-The-Websites.v*.ps1 next to this file.
setlocal
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Block-The-Websites.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Block-The-Websites.v*.ps1 found next to this file.
    pause
    exit /b 1
)
start "" /min powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TARGET%"
exit /b 0