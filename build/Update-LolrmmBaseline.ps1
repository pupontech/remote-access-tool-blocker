<#
.SYNOPSIS
  Check the LOLRMM catalogue for changes and refresh the committed baseline. Used by the lolrmm-watch workflow.

.DESCRIPTION
  1. Downloads lolrmm.io/api/rmm_tools.json (or reads -JsonPath) and compares its SHA256 with
     data/lolrmm-baseline/catalogue.sha256. Same hash: nothing to do.
  2. Otherwise runs the repo's own generators against it:
       Get-LolrmmUrlList   -> data/lolrmm-baseline/eset-blocked-urls.txt, url-review.csv
       Build-RmmAppControl -> data/lolrmm-baseline/skipped-signers.csv, and policy/ IF the deny rules changed
     and writes data/lolrmm-baseline/tools.txt (every catalogue tool name).
  3. Writes a Markdown report of what changed (tools, website list, App Control rules, and new vendors
     that need a block/allow decision) to -ReportPath.

  policy/ is only rewritten when the set of deny rules differs from the committed one: a rebuild always
  stamps a new version and timestamp, and that churn would hide real changes.

  The ESET website list is generated live on each technician PC, so its baseline here is a record for
  review, not something the kits ship.

  When it runs under GitHub Actions it writes changed / policy_rebuilt / sha to GITHUB_OUTPUT.
  Needs Windows PowerShell 5.1 with the ConfigCI module (any windows-latest runner) for the policy step.

.PARAMETER JsonPath     Use this local catalogue instead of downloading.
.PARAMETER ReportPath   Where to write the Markdown report. Default: <temp>\lolrmm-report.md
.PARAMETER SkipPolicy   Do not build the App Control policy (no ConfigCI on this machine).
#>
[CmdletBinding()]
param(
    [string]$JsonPath,
    [string]$ReportPath,
    [switch]$SkipPolicy
)

$ErrorActionPreference = 'Stop'
$Url = 'https://lolrmm.io/api/rmm_tools.json'
$Root = Split-Path -Parent $PSScriptRoot
$Base = Join-Path $Root 'data\lolrmm-baseline'
$PolicyDir = Join-Path $Root 'policy'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$ListCap = 150   # rows per report section; a PR body is limited to 65k characters

$Work = Join-Path ([IO.Path]::GetTempPath()) ('lolrmm-watch-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $Work | Out-Null
New-Item -ItemType Directory -Force -Path $Base | Out-Null
if (-not $ReportPath) { $ReportPath = Join-Path ([IO.Path]::GetTempPath()) 'lolrmm-report.md' }

function Set-ActionOutput([string]$Name, [string]$Value) {
    if ($env:GITHUB_OUTPUT) { [IO.File]::AppendAllText($env:GITHUB_OUTPUT, "$Name=$Value`n", $Utf8) }
    Write-Host "output $Name=$Value"
}
function Read-Lines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @([IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8) | Where-Object { $_ -ne '' })
}
function Read-Rows([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @(Import-Csv -LiteralPath $Path -Encoding UTF8)
}
function Get-Delta([string[]]$Old, [string[]]$New) {
    $o = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $n = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($x in $Old) { [void]$o.Add($x) }
    foreach ($x in $New) { [void]$n.Add($x) }
    [pscustomobject]@{
        Added   = @($n | Where-Object { -not $o.Contains($_) } | Sort-Object)
        Removed = @($o | Where-Object { -not $n.Contains($_) } | Sort-Object)
    }
}
function Invoke-Generator([string]$Pattern, [string[]]$Arguments) {
    $script = @(Get-ChildItem -Path (Join-Path $Root 'src') -Recurse -Filter $Pattern -File | Sort-Object Name -Descending)[0]
    if (-not $script) { throw "No $Pattern under src" }
    Write-Host "--- $($script.Name) $($Arguments -join ' ')"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script.FullName @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$($script.Name) failed with exit code $LASTEXITCODE" }
}

# ------------------------------------------------------------ catalogue + hash gate
if ($JsonPath) {
    $json = (Resolve-Path -LiteralPath $JsonPath).Path
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $json = Join-Path $Work 'rmm_tools.json'
    Write-Host "Downloading $Url"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $json
}
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $json).Hash
$oldSha = (@(Read-Lines (Join-Path $Base 'catalogue.sha256')) + '')[0].Trim()
Set-ActionOutput 'sha' $sha
if ($sha -eq $oldSha) {
    Write-Host "Catalogue unchanged ($sha)."
    Set-ActionOutput 'changed' 'false'
    Set-ActionOutput 'policy_rebuilt' 'false'
    return
}

# assign first: PS 5.1 ConvertFrom-Json emits the whole array as ONE pipeline object, so @(...) around it gives 1 item
$tools = Get-Content -Raw -Encoding UTF8 -LiteralPath $json | ConvertFrom-Json
$tools = @($tools)
if ($tools.Count -lt 100) { throw "Catalogue looks wrong ($($tools.Count) entries) - refusing to continue." }

# ------------------------------------------------------------ old baseline (read before overwriting)
$oldTools = Read-Lines (Join-Path $Base 'tools.txt')
$oldBlock = Read-Lines (Join-Path $Base 'eset-blocked-urls.txt')
$oldReview = Read-Rows (Join-Path $Base 'url-review.csv')
$oldSkipped = Read-Rows (Join-Path $Base 'skipped-signers.csv')
$oldRules = Read-Rows (Join-Path $PolicyDir 'signers.csv')

# ------------------------------------------------------------ run the generators
$urlOut = Join-Path $Work 'urls'
Invoke-Generator 'Get-LolrmmUrlList.v*.ps1' @('-JsonPath', $json, '-OutDir', $urlOut)

$newTools = @($tools | ForEach-Object { [string]$_.Name } | Sort-Object -Unique)
$newBlock = Read-Lines (Join-Path $urlOut 'eset-blocked-urls.txt')
$newReview = Read-Rows (Join-Path $urlOut 'url-review.csv')

$polOut = Join-Path $Work 'policy'
$rebuilt = $false
$ruleDelta = $null
$newSkipped = $oldSkipped
if (-not $SkipPolicy) {
    Invoke-Generator 'Build-RmmAppControl.v*.ps1' @('-JsonPath', $json, '-OutDir', $polOut)
    $ruleKey = { '{0} | {1} | {2} | {3}' -f $_.Tier, $_.Kind, $_.Publisher, $_.CertRoot }
    $ruleLabel = @{}
    $newRules = Read-Rows (Join-Path $polOut 'signers.csv')
    foreach ($r in @($oldRules) + @($newRules)) { $ruleLabel[(& $ruleKey $r)] = "$($r.Tier) $($r.Kind): $($r.Publisher) - $($r.Tools)" }
    $ruleDelta = Get-Delta @($oldRules | ForEach-Object $ruleKey) @($newRules | ForEach-Object $ruleKey)
    $newSkipped = Read-Rows (Join-Path $polOut 'skipped-signers.csv')
    if ($ruleDelta.Added.Count -or $ruleDelta.Removed.Count) {
        Write-Host 'Deny rules changed - replacing policy/'
        Get-ChildItem -LiteralPath $PolicyDir -Recurse -File | Remove-Item -Force
        Copy-Item -Path (Join-Path $polOut '*') -Destination $PolicyDir -Recurse -Force
        $rebuilt = $true
    }
    Copy-Item -LiteralPath (Join-Path $polOut 'skipped-signers.csv') -Destination (Join-Path $Base 'skipped-signers.csv') -Force
}

# ------------------------------------------------------------ write the baseline
[IO.File]::WriteAllText((Join-Path $Base 'catalogue.sha256'), "$sha`n", $Utf8)
[IO.File]::WriteAllText((Join-Path $Base 'tools.txt'), (($newTools -join "`n") + "`n"), $Utf8)
Copy-Item -LiteralPath (Join-Path $urlOut 'eset-blocked-urls.txt') -Destination (Join-Path $Base 'eset-blocked-urls.txt') -Force
Copy-Item -LiteralPath (Join-Path $urlOut 'url-review.csv') -Destination (Join-Path $Base 'url-review.csv') -Force

# ------------------------------------------------------------ report
$md = New-Object System.Collections.Generic.List[string]
function Add-Section([string]$Title, [string[]]$Items, [string]$Prefix) {
    if (-not $Items -or $Items.Count -eq 0) { return }
    $md.Add(''); $md.Add("**$Title** ($($Items.Count))"); $md.Add('')
    foreach ($i in @($Items | Select-Object -First $ListCap)) { $md.Add("- $Prefix``$i``") }
    if ($Items.Count -gt $ListCap) { $md.Add("- ... and $($Items.Count - $ListCap) more (see the diff)") }
}

$md.Add('## LOLRMM catalogue update')
$md.Add('')
$md.Add("Catalogue: $($tools.Count) tools, SHA256 ``$sha``" + $(if ($oldSha) { " (was ``$oldSha``)" } else { ' (first baseline)' }))

$md.Add(''); $md.Add('### Tools')
$td = Get-Delta $oldTools $newTools
if (-not ($td.Added.Count + $td.Removed.Count)) { $md.Add(''); $md.Add('No tools added or removed.') }
Add-Section 'Added' $td.Added ''
Add-Section 'Removed' $td.Removed ''

$md.Add(''); $md.Add('### ESET website list')
$md.Add(''); $md.Add("Block list: $($oldBlock.Count) -> $($newBlock.Count) entries. Technicians already get this on their next run; nothing to ship.")
$bd = Get-Delta $oldBlock $newBlock
Add-Section 'Now blocked' $bd.Added ''
Add-Section 'No longer blocked' $bd.Removed ''
$optKey = { "$($_.Entry) ($($_.Tools))" }
$od = Get-Delta @($oldReview | Where-Object Tier -ne 'main' | ForEach-Object $optKey) @($newReview | Where-Object Tier -ne 'main' | ForEach-Object $optKey)
Add-Section 'Optional (not blocked by default) - added' $od.Added ''
Add-Section 'Optional (not blocked by default) - removed' $od.Removed ''

$md.Add(''); $md.Add('### App Control policy')
$md.Add('')
if ($SkipPolicy) {
    $md.Add('Not checked (-SkipPolicy).')
} elseif ($rebuilt) {
    $md.Add("**Deny rules changed - policy/ rebuilt.** Before merging: test-install on a PC (Audit first), bump VERSION and add a CHANGELOG entry.")
    Add-Section 'Rules added' @($ruleDelta.Added | ForEach-Object { $ruleLabel[$_] }) ''
    Add-Section 'Rules removed' @($ruleDelta.Removed | ForEach-Object { $ruleLabel[$_] }) ''
} else {
    $md.Add('Deny rules identical to the committed policy - policy/ not rebuilt.')
}

if (-not $SkipPolicy) {
    $sk = { "$($_.Tool) -> $($_.Signer)" }
    $sd = Get-Delta @($oldSkipped | Where-Object Reason -like 'not on the hand-checked*' | ForEach-Object $sk) @($newSkipped | Where-Object Reason -like 'not on the hand-checked*' | ForEach-Object $sk)
    $md.Add(''); $md.Add('### Vendors that need a decision')
    $md.Add('')
    if ($sd.Added.Count) {
        $md.Add('These signers are new in the catalogue and are not blocked because they are on neither vendor list. To block one, add it to $MainSigners (or $OptionalSigners) in Build-RmmAppControl and rebuild.')
        Add-Section 'Unreviewed signers' $sd.Added ''
    } else {
        $md.Add('None.')
    }
}
$md.Add(''); $md.Add('_Opened by the lolrmm-watch workflow. Merging this PR accepts the new baseline._')
[IO.File]::WriteAllText($ReportPath, (($md -join "`n") + "`n"), $Utf8)
Write-Host "Report: $ReportPath"

Set-ActionOutput 'changed' 'true'
Set-ActionOutput 'policy_rebuilt' ([string]$rebuilt).ToLowerInvariant()
Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
