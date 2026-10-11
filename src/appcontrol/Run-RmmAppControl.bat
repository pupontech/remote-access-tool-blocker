@echo off
rem Self-elevating launcher for Install-RmmAppControl (auto-detects the newest Install-RmmAppControl.v*.ps1 next to it).
rem   Run-RmmAppControl.bat -Mode Enforce     block the listed remote-access tools
rem   Run-RmmAppControl.bat -Mode Audit       log only (test first)
rem   Run-RmmAppControl.bat -Mode Remove      uninstall
rem   Run-RmmAppControl.bat                   status
setlocal
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Install-RmmAppControl.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Install-RmmAppControl.v*.ps1 found next to this launcher.
    pause
    exit /b 1
)
net session >nul 2>&1
if errorlevel 1 (
    echo Asking for administrator rights ...
    if "%~1"=="" (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    ) else (
        powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -Wait"
    )
    exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%
