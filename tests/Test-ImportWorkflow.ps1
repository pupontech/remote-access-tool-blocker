param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert($ok, [string]$message) { if (-not $ok) { throw $message }; Write-Host "PASS: $message" }
$p1 = Get-ChildItem "$RepoRoot/kits/1/Block-The-Programs.v*.ps1" | Select-Object -First 1
$p2 = Get-ChildItem "$RepoRoot/kits/2/Block-The-Websites.v*.ps1" | Select-Object -First 1
foreach ($p in $p1, $p2) {
    $text = Get-Content -Raw $p.FullName
    foreach ($name in 'TeamViewer', 'AnyDesk', 'Splashtop', 'RustDesk') {
        Assert ($text -match ("New-Chk '" + $name + ''' \d+ \$false')) "$($p.Name): $name defaults unticked"
    }
}
$websiteSource = Get-Content -Raw $p2.FullName
Assert ($websiteSource.Contains("New-Btn 'Open list'")) 'third Open list button exists'
Assert ($websiteSource.IndexOf('Start-Process notepad.exe -ArgumentList', $websiteSource.IndexOf('$btnDo.Add_Click')) -ge 0) 'BUILD opens the import list in Notepad'
Assert ($websiteSource.Contains('Set-Clipboard -Value $UrlListFile')) 'website tool copies import path, not list contents'
Assert ($websiteSource.IndexOf('Open-ListFolder $true', $websiteSource.IndexOf('$btnDo.Add_Click')) -lt $websiteSource.IndexOf('$instEset =')) 'folder opens before optional undo installation'
$work = Join-Path ([IO.Path]::GetTempPath()) ('blocker-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $work | Out-Null
try {
    $fixture = Join-Path $work 'catalogue.json'
    $tools = @(1..100 | ForEach-Object { @{ Name = "Tool$_"; Details = @{ Website = '' }; Artifacts = @{ Network = @(@{ Domains = @("tool$_.example") }) } } })
    $tools[0].Artifacts.Network[0].Domains = @('sophos.com', 'anydesk.com', 'rustdesk.com', 'splashtop.com', 'teamviewer.com', 'github.com')
    $tools | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $fixture
    $out = Join-Path $work 'list folder'
    $gen = (Get-ChildItem "$RepoRoot/src/eset/Get-LolrmmUrlList.v*.ps1" | Select-Object -First 1).FullName
    New-Item -ItemType Directory $out | Out-Null
    Set-Content (Join-Path $out 'eset-blocked-urls-optional.txt') 'stale sentinel'
    & $gen -JsonPath $fixture -OutDir $out
    $entries = @(Get-Content (Join-Path $out 'eset-blocked-urls.txt'))
    Assert ($entries -contains '*.sophos.com') 'combined list includes previously optional entries'
    Assert (-not (Test-Path (Join-Path $out 'eset-blocked-urls-optional.txt'))) 'stale second import list removed'
    foreach ($root in 'anydesk.com', 'rustdesk.com', 'splashtop.com', 'teamviewer.com', 'github.com') {
        Assert ($entries -notcontains "*.$root") "$root excluded from default list"
    }
    Assert ($entries.Count -eq @($entries | Sort-Object -Unique).Count) 'combined list deduplicated'
    if ($env:OS -eq 'Windows_NT') {
        # Instantiate the actual window without showing or installing anything.
        $guiCopy = Join-Path $work $p2.Name
        $source = (Get-Content -Raw $p2.FullName).Replace('[void]$form.ShowDialog()', '# window suppressed by test')
        [IO.File]::WriteAllText($guiCopy, $source)
        . $guiCopy
        $UrlOut = $out; $UrlListFile = Join-Path $out 'eset-blocked-urls.txt'
        $script:opened = @()
        function Start-Process { param($FilePath, $ArgumentList) $script:opened += [pscustomobject]@{ File = $FilePath; Arguments = $ArgumentList } }
        function Find-Newest { param($pattern, $dir) if ($pattern -like 'Get-*') { return $gen }; if ($pattern -like 'Install-*') { return 'installer' } }
        function Run-Script { param($path, $scriptArgs) if ($path -eq 'installer') { throw 'controlled installer failure' }; return 0 }
        function Open-EsetAndGuide { }
        # PerformClick on an unseen window may not dispatch; invoke the actual event body explicitly.
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($guiCopy, [ref]$tokens, [ref]$errors)
        $handler = $ast.Find({ param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Extent.Text.StartsWith('$btnDo.Add_Click(') }, $true)
        $body = $handler.Arguments[0].ScriptBlock.Extent.Text
        & ([scriptblock]::Create($body.Substring(1, $body.Length - 2)))
        Assert ((Get-Clipboard -Raw).TrimEnd("`r", "`n") -eq $UrlListFile) 'clipboard contains exact import file path'
        Assert (@($script:opened | Where-Object { $_.File -eq 'explorer.exe' -and $_.Arguments -eq ('/select,"' + $UrlListFile + '"') }).Count -gt 0) 'Explorer selects import file even when undo installer fails'
        Assert (@($script:opened | Where-Object { $_.File -eq 'notepad.exe' -and $_.Arguments -eq ('"' + $UrlListFile + '"') }).Count -eq 1) 'Notepad opens the quoted import file path even when undo installer fails'
        Assert ($btnDo.Enabled -and $btnFolder.Enabled) 'buttons re-enabled after installer failure'
        # Invoke the real third-button event; opening must not rebuild or change the list.
        function Run-Script { throw 'Open list must not run scripts or rebuild' }
        $script:opened = @()
        $before = (Get-FileHash -LiteralPath $UrlListFile).Hash
        $openHandler = $ast.Find({ param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Extent.Text.StartsWith('$btnList.Add_Click(') }, $true)
        Assert ($null -ne $openHandler) 'Open list button has a click handler'
        $openBody = $openHandler.Arguments[0].ScriptBlock.Extent.Text
        $openAction = [scriptblock]::Create($openBody.Substring(1, $openBody.Length - 2))
        & $openAction
        Assert (@($script:opened).Count -eq 1 -and $script:opened[0].File -eq 'notepad.exe' -and $script:opened[0].Arguments -eq ('"' + $UrlListFile + '"')) 'Open list opens the existing file in Notepad'
        Assert ((Get-FileHash -LiteralPath $UrlListFile).Hash -eq $before) 'Open list leaves import bytes unchanged'
        Busy $true
        Assert (-not $btnList.Enabled) 'Open list disabled while BUILD is busy'
        Busy $false
        Assert ($btnList.Enabled) 'Open list re-enabled after BUILD'
        Remove-Item -LiteralPath $UrlListFile
        $script:opened = @(); $log.Clear()
        & $openAction
        Assert (@($script:opened).Count -eq 0 -and $log.Text -match 'BUILD') 'missing list gives BUILD guidance without launching Notepad'
        $form.Dispose()
    } else { Write-Host 'Windows UI/clipboard assertions deferred to Windows CI' }
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
