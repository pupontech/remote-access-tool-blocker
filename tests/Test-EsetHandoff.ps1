param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert($ok, [string]$message) { if (-not $ok) { throw $message }; Write-Host "PASS: $message" }
$source = (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'kits/2') -Filter 'Block-The-Websites.v*.ps1').FullName
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
$fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Open-EsetAndGuide' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))
$work = Join-Path ([IO.Path]::GetTempPath()) ('eset-handoff-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$oldProgramFiles = $env:ProgramFiles
try {
    $env:ProgramFiles = $work
    $Parts = @{ Eset = $work }
    $script:messages = @(); $script:opened = @()
    function Say($message, $color) { $script:messages += $message }
    function Get-ChildItem { [pscustomobject]@{ FullName = 'egui.exe' } }
    function Find-Newest { return (Join-Path $work 'HOW-TO-IMPORT.txt') }
    Set-Content -LiteralPath (Join-Path $work 'HOW-TO-IMPORT.txt') -Value 'fixture guide'
    function Start-Process {
        param($FilePath, $ArgumentList)
        if ($FilePath -eq 'egui.exe') { throw 'controlled ESET launch failure' }
        $script:opened += [pscustomobject]@{ File = $FilePath; Arguments = $ArgumentList }
    }
    $caught = $null
    try { Open-EsetAndGuide } catch { $caught = $_ }
    Assert ($null -eq $caught) 'ESET launch failure is isolated from guide handoff'
    Assert (@($script:opened | Where-Object { $_.File -eq 'notepad.exe' -and $_.Arguments -eq ('"' + (Join-Path $work 'HOW-TO-IMPORT.txt') + '"') }).Count -eq 1) 'guide opens with exact quoted path after ESET launch failure'
    Assert (($script:messages -join "`n") -match 'controlled ESET launch failure') 'ESET launch error remains visible'

    function Get-ChildItem { }
    function Find-Newest { return $null }
    $script:messages = @(); $script:opened = @(); $caught = $null
    try { Open-EsetAndGuide } catch { $caught = $_ }
    Assert ($null -eq $caught) 'missing ESET and guide do not throw on a null path'
    Assert (@($script:opened).Count -eq 0) 'missing guide never starts Notepad'
    Assert (($script:messages -join "`n") -match 'guide.*not found') 'missing guide is reported'

    function Find-Newest { return (Join-Path $work 'HOW-TO-IMPORT.txt') }
    function Start-Process { param($FilePath, $ArgumentList) throw 'controlled Notepad failure' }
    $script:messages = @(); $caught = $null
    try { Open-EsetAndGuide } catch { $caught = $_ }
    Assert ($null -eq $caught) 'Notepad launch failure is nonfatal'
    Assert (($script:messages -join "`n") -match 'controlled Notepad failure') 'Notepad error remains visible'
} finally {
    $env:ProgramFiles = $oldProgramFiles
    Remove-Item -LiteralPath $work -Recurse -Force
}
