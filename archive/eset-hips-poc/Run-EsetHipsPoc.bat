@echo off
rem Self-elevating launcher; auto-detects newest Invoke-EsetHipsPoc.v*.ps1 next to it.
pushd "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    popd & exit /b
)
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Invoke-EsetHipsPoc.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET ( echo No Invoke-EsetHipsPoc.v*.ps1 found. & pause & exit /b 1 )
powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
echo Exit code: %errorlevel%
pause
popd
