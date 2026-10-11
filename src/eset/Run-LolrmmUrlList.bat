@echo off
rem Launcher for Get-LolrmmUrlList; auto-detects the newest Get-LolrmmUrlList.v*.ps1 next to it.
rem Extra args pass through, e.g.:  Run-LolrmmUrlList.bat -ExcludeTool Splashtop,TeamViewer -AllowDomain splashtop.com,teamviewer.com
pushd "%~dp0"
set "TARGET="
for /f "delims=" %%F in ('dir /b /o-n "%~dp0Get-LolrmmUrlList.v*.ps1" 2^>nul') do (
    if not defined TARGET set "TARGET=%~dp0%%F"
)
if not defined TARGET (
    echo No Get-LolrmmUrlList.v*.ps1 found next to this launcher.
    popd
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" %*
set "RC=%ERRORLEVEL%"
popd
pause
exit /b %RC%
