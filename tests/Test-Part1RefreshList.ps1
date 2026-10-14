param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert($ok, [string]$message) { if (-not $ok) { throw $message }; Write-Host "PASS: $message" }
$p1 = Get-ChildItem "$RepoRoot/kits/1/Block-The-Programs.v*.ps1" | Select-Object -First 1
$text = Get-Content -Raw $p1.FullName

# Static contract: the button exists, is wired, is disabled while busy, and rebuilds with optional vendors.
Assert ($text.Contains("`$btnRefresh.Text = 'Refresh list'")) 'part 1 has a Refresh list button'
Assert ($text.Contains('$btnRefresh.Add_Click(')) 'Refresh list button has a click handler'
Assert ($text -match 'foreach \(\$b in \$btnDo, \$btnUndo, \$btnTest, \$btnLog, \$btnRefresh\)') 'Busy covers the Refresh list button'
Assert ($text.Contains("@('-IncludeOptional')")) 'Refresh list rebuilds including optional vendors'
Assert ($text.IndexOf('$btnRefresh.Add_Click(') -lt $text.IndexOf('# ---------------------------------------------------------------- start')) 'handler is defined before the window is shown'

if ($env:OS -ne 'Windows_NT') { Write-Host 'Windows UI assertions deferred to Windows CI'; return }

$work = Join-Path ([IO.Path]::GetTempPath()) ('blocker-refresh-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $work | Out-Null
try {
    $guiCopy = Join-Path $work $p1.Name
    $source = (Get-Content -Raw $p1.FullName).Replace('[void]$form.ShowDialog()', '# window suppressed by test')
    [IO.File]::WriteAllText($guiCopy, $source)
    . $guiCopy

    $fakeBuild = Join-Path $work 'Build-RmmAppControl.v-test.ps1'
    Set-Content -LiteralPath $fakeBuild -Value '# fake'
    $script:runCalls = @()
    function Find-Newest { param($pattern, $dir) return $fakeBuild }
    function Run-Script { param($path, $scriptArgs) $script:runCalls += , ([pscustomobject]@{ Path = $path; Args = $scriptArgs }); return 0 }

    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($guiCopy, [ref]$tokens, [ref]$errors)
    $handler = $ast.Find({ param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Extent.Text.StartsWith('$btnRefresh.Add_Click(') }, $true)
    Assert ($null -ne $handler) 'Refresh list handler found in the real script'
    $body = $handler.Arguments[0].ScriptBlock.Extent.Text
    $action = [scriptblock]::Create($body.Substring(1, $body.Length - 2))

    # Declining the confirmation must change nothing at all.
    function Confirm { param($text, $caption) return $false }
    $script:runCalls = @(); $log.Clear()
    & $action
    Assert ($script:runCalls.Count -eq 0) 'declining the confirm runs nothing'
    Assert ($log.Text.Trim() -eq '') 'declining the confirm logs nothing'

    # Accepting rebuilds the list with optional vendors and tells the operator to re-install.
    function Confirm { param($text, $caption) return $true }
    $script:runCalls = @(); $log.Clear()
    & $action
    Assert ($script:runCalls.Count -eq 1 -and $script:runCalls[0].Path -eq $fakeBuild) 'confirm runs the real build script'
    Assert ($script:runCalls[0].Args -contains '-IncludeOptional') 'build is asked for the optional vendors'
    Assert ($log.Text -match 'list rebuilt' -and $log.Text -match 'BLOCK') 'success text tells the operator to press BLOCK'
    Assert ($btnRefresh.Enabled -and $btnDo.Enabled -and $btnLog.Enabled) 'buttons re-enabled after the rebuild'

    # A PC that cannot build must say so instead of silently doing nothing.
    function Get-Command { param([string]$Name, $ErrorAction) return $null }
    $script:runCalls = @(); $log.Clear()
    & $action
    Assert ($script:runCalls.Count -eq 0) 'no build attempted on a PC that cannot build'
    Assert ($log.Text -match 'cannot rebuild the list') 'clear message when the PC cannot rebuild'
    $form.Dispose()
} finally { Remove-Item -LiteralPath $work -Recurse -Force }
