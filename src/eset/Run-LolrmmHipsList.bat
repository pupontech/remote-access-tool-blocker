@echo off
rem Launcher for Get-LolrmmHipsList; auto-detects the newest Get-LolrmmHipsList.v*.ps1 next to it.
rem Extra args pass through, e.g.:  Run-LolrmmHipsList.bat -ScanDisk -ExcludeTool Splashtop,Kaseya
pushd "%~dp0"
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Get-LolrmmHipsList.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Get-LolrmmHipsList.v*.ps1 found next to this launcher.
    popd
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
set "RC=%ERRORLEVEL%"
popd
pause
exit /b %RC%
