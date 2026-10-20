param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert($ok, [string]$message) { if (-not $ok) { throw $message }; Write-Host "PASS: $message" }
$source = (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'kits/2') -Filter 'Block-The-Websites.v*.ps1').FullName
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
$handler = $ast.Find({ param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Extent.Text.StartsWith('$btnDo.Add_Click(') }, $true)
$body = $handler.Arguments[0].ScriptBlock.Extent.Text
$action = [scriptblock]::Create($body.Substring(1, $body.Length - 2))
$Parts = @{ Eset = 'fixture' }
$chkT = $chkA = $chkS = $chkR = [pscustomobject]@{ Checked = $false }
$log = New-Object PSObject
$log | Add-Member ScriptMethod Clear { }
$script:busy = $false; $script:messages = @()
function Busy([bool]$on) { $script:busy = $on }
function Say($message, $color) { $script:messages += $message }
function Find-Newest { return $null }
function Update-Status { throw 'controlled unreadable list status failure' }
$caught = $null
try { & $action } catch { $caught = $_ }
Assert (-not $script:busy) 'BUILD always restores controls after status refresh failure'
Assert ($null -eq $caught) 'status refresh failure does not escape the click handler'
Assert (($script:messages -join "`n") -match 'controlled unreadable list status failure') 'status failure is reported instead of hidden'
