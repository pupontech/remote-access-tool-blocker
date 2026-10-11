<#
.SYNOPSIS
  Build a HIPS-ready path list from the LOLRMM catalogue (https://lolrmm.io). READ-ONLY.

.DESCRIPTION
  Downloads (or reads) lolrmm.io/api/rmm_tools.json and turns each tool's install paths into three lists:
    hips-exact.csv      absolute .exe paths  -> usable as an ESET HIPS rule target (one rule per path)
    hips-folder.csv     install folders      -> CANDIDATE 'folder\*' targets, wildcard behaviour is UNVERIFIED on ESET 19.2
    name-only.csv       bare exe names       -> HIPS cannot match these by name; use -ScanDisk to find them on this PC
  plus skipped.csv (everything dropped, with the reason) and summary.txt.

  It NEVER touches ESET: no ecmd, no import, no registry, no rules. It only writes files under -OutDir.
  Tools matching -ExcludeTool (your own remote-access tools) are left out of every list.

.PARAMETER JsonPath    Use this local copy instead of downloading.
.PARAMETER OutDir      Output folder. Default: %USERPROFILE%\LOLRMM-HipsList\<yyyy-MM-dd_HHmmss>
.PARAMETER ExcludeTool Tool-name patterns (-like, case-insensitive) to leave out. Default: Splashtop, mstsc, NVDA
.PARAMETER ScanDisk    Also search Program Files, ProgramData and user profiles on THIS PC for the name-only exes
                       and add the exact paths found (slow: a few minutes; run elevated to see all user profiles).
#>
[CmdletBinding()]
param(
    [string]$JsonPath,
    [string]$OutDir,
    [string[]]$ExcludeTool = @('Splashtop', 'mstsc', 'NVDA'),
    [switch]$ScanDisk
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-08.1'
$Url = 'https://lolrmm.io/api/rmm_tools.json'

if (-not $OutDir) {
    $OutDir = Join-Path $env:USERPROFILE ('LOLRMM-HipsList\' + (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Get-LolrmmHipsList v$ScriptVersion  ->  $OutDir"

# ---------------------------------------------------------------- load catalogue
if ($JsonPath) {
    if (-not (Test-Path -LiteralPath $JsonPath)) { throw "JsonPath not found: $JsonPath" }
    $jsonFile = $JsonPath
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $jsonFile = Join-Path $OutDir 'rmm_tools.json'
    Write-Host "Downloading $Url ..."
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $jsonFile
}
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $jsonFile).Hash
$tools = Get-Content -Raw -Encoding UTF8 -LiteralPath $jsonFile | ConvertFrom-Json
if (-not $tools -or $tools.Count -lt 100) { throw "Catalogue looks wrong ($($tools.Count) entries) - refusing to continue." }
Write-Host ("Catalogue: {0} tools, SHA256 {1}" -f $tools.Count, $sha)

# ---------------------------------------------------------------- user profiles (for C:\Users\* / USERNAME expansion)
$usersRoot = Join-Path $env:SystemDrive 'Users'
$profiles = @()
if (Test-Path -LiteralPath $usersRoot) {
    $profiles = @(Get-ChildItem -LiteralPath $usersRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') -and $_.Name -notmatch '^(TEMP|UMFD-\d+)(\.|$)' } |
        ForEach-Object { $_.FullName })
}

function Expand-Candidate([string]$raw) {
    # returns @{ Paths = string[]; Note = string } - Paths empty when nothing usable
    $p = $raw.Trim().Trim('"')
    while ($p -match '\\\\') { $p = $p -replace '\\\\', '\' }
    $p = $p -replace '(?i)%USERPROFILE%', 'C:\Users\*'
    $p = $p -replace '(?i)%LOCALAPPDATA%', 'C:\Users\*\AppData\Local'
    $p = $p -replace '(?i)%APPDATA%', 'C:\Users\*\AppData\Roaming'
    $p = $p -replace '(?i)%TEMP%', 'C:\Users\*\AppData\Local\Temp'
    $p = [Environment]::ExpandEnvironmentVariables($p)
    $p = $p -replace '(?i)^([A-Za-z]:\\Users\\)USERNAME(\\|$)', '$1*$2'
    if ($p -match '^([A-Za-z]):\\Users\\\*(\\.*)?$') {
        $tail = $Matches[2]
        $out = @()
        foreach ($pr in $profiles) { $out += ($pr + $tail) }
        return @{ Path = $p; Expanded = $out; PerUser = $true }
    }
    return @{ Path = $p; Expanded = @($p); PerUser = $false }
}

# ---------------------------------------------------------------- classify
$exact = New-Object System.Collections.ArrayList
$folder = New-Object System.Collections.ArrayList
$nameOnly = New-Object System.Collections.ArrayList
$skipped = New-Object System.Collections.ArrayList
$excluded = New-Object System.Collections.ArrayList
$seen = @{}

function Add-Row($list, $tool, $cat, $kind, $path, $src, $orig) {
    $key = ($tool + '|' + $kind + '|' + $path).ToLowerInvariant()
    if ($seen.ContainsKey($key)) { return }
    $seen[$key] = $true
    [void]$list.Add([pscustomobject]@{
        Tool = $tool; Category = $cat; Path = $path; Source = $src; Original = $orig
    })
}

foreach ($t in $tools) {
    $name = [string]$t.Name
    $cat = [string]$t.Category
    $skipTool = $false
    foreach ($pat in $ExcludeTool) { if ($name -like "*$pat*") { $skipTool = $true } }
    if ($skipTool) { [void]$excluded.Add($name); continue }

    $cands = New-Object System.Collections.ArrayList
    foreach ($p in @($t.Details.InstallationPaths)) { if ($p) { [void]$cands.Add(@($p, 'InstallationPaths')) } }
    foreach ($a in @($t.Artifacts.Disk)) { if ($a -and $a.File) { [void]$cands.Add(@([string]$a.File, 'Artifacts.Disk')) } }

    foreach ($c in $cands) {
        $orig = [string]$c[0]; $src = [string]$c[1]
        $t0 = $orig.Trim()
        if ($t0.StartsWith('/') -or $t0 -match '(?i)\.(sh|service|plist|deb|rpm|pkg|dmg|so|app)$') {
            Add-Row $skipped $name $cat 'skip' $orig $src 'non-Windows path'; continue
        }
        $e = Expand-Candidate $orig
        $p = $e.Path
        if ($p -match '[<>"|?]') {
            Add-Row $skipped $name $cat 'skip' $orig $src 'placeholder / illegal characters in path'; continue
        }

        if ($p -match '^[A-Za-z]:\\') {
            if ($e.PerUser) {
                if ($e.Expanded.Count -eq 0) { Add-Row $skipped $name $cat 'skip' $orig $src 'per-user path but no profiles found'; continue }
                $targets = $e.Expanded
            } else { $targets = @($p) }
            foreach ($tp in $targets) {
                if ($tp -match '\*[^\\]|[^\\]\*' -and $tp -notmatch '\\\*$') {
                    Add-Row $skipped $name $cat 'skip' $tp $src 'wildcard inside file/folder name'; continue
                }
                if ($tp -match '\\\*$') {
                    $base = $tp.Substring(0, $tp.Length - 2)
                    if ($base -match '\*') { Add-Row $skipped $name $cat 'skip' $tp $src 'wildcard in folder path'; continue }
                    Add-Row $folder $name $cat 'folder' ($base + '\*') $src $orig; continue
                }
                if ($tp -match '\*') { Add-Row $skipped $name $cat 'skip' $tp $src 'wildcard in path'; continue }
                if ($tp -match '(?i)\.exe$') {
                    if ($tp -match '(?i)^[A-Za-z]:\\Windows\\(System32|SysWOW64)\\[^\\]+$') {
                        Add-Row $skipped $name $cat 'skip' $tp $src 'Windows OS component - blocking it would break Windows'; continue
                    }
                    Add-Row $exact $name $cat 'exact' $tp $src $orig; continue
                }
                if ($tp.EndsWith('\')) { Add-Row $folder $name $cat 'folder' ($tp + '*') $src $orig; continue }
                $leaf = Split-Path -Leaf $tp
                if ($leaf -notmatch '\.') { Add-Row $folder $name $cat 'folder' ($tp + '\*') $src $orig; continue }
                Add-Row $skipped $name $cat 'skip' $tp $src 'not an executable (config/log/installer file)'
            }
            continue
        }

        # not drive-absolute
        $leaf = $p -replace '^\*\\', ''
        if ($leaf -match '^[^\\/*]+\.exe$') { Add-Row $nameOnly $name $cat 'name' $leaf $src $orig; continue }
        Add-Row $skipped $name $cat 'skip' $orig $src 'not a usable Windows exe path or name'
    }
}

# ---------------------------------------------------------------- optional disk scan for name-only exes
$found = New-Object System.Collections.ArrayList
if ($ScanDisk) {
    $names = @{}
    foreach ($n in $nameOnly) { $names[$n.Path.ToLowerInvariant()] = $n }
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) + $profiles | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    Write-Host ("Scanning {0} root(s) for {1} exe names (this takes a few minutes) ..." -f $roots.Count, $names.Count)
    foreach ($r in $roots) {
        Write-Host "  $r"
        Get-ChildItem -LiteralPath $r -Recurse -File -Force -Filter '*.exe' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $k = $_.Name.ToLowerInvariant()
                if ($names.ContainsKey($k)) {
                    $n = $names[$k]
                    Add-Row $exact $n.Tool $n.Category 'exact' $_.FullName 'disk-scan' $n.Path
                    [void]$found.Add([pscustomobject]@{ Tool = $n.Tool; ExeName = $n.Path; FullPath = $_.FullName })
                }
            }
    }
}

# ---------------------------------------------------------------- flag what already exists here, write files
$genericStems = @('setup', 'install', 'installer', 'update', 'updater', 'agent', 'client', 'server', 'service',
    'connect', 'helper', 'launcher', 'remote', 'viewer', 'support', 'host', 'start', 'main', 'app', 'run')
foreach ($x in $exact) {
    if ($x.Source -eq 'disk-scan') {
        $stem = [IO.Path]::GetFileNameWithoutExtension($x.Path).ToLowerInvariant()
        if ($stem.Length -lt 8 -or $genericStems -contains $stem) {
            $conf = 'LOW - generic file name, probably another program'
        } else { $conf = 'MEDIUM - matched by file name only, verify' }
    } else { $conf = 'HIGH - full path from catalogue' }
    $x | Add-Member -NotePropertyName Confidence -NotePropertyValue $conf
}
function Test-Exists([string]$p) {
    try { return [bool](Test-Path -LiteralPath $p -ErrorAction Stop) } catch { return $false }
}
foreach ($x in $exact) { $x | Add-Member -NotePropertyName PresentHere -NotePropertyValue (Test-Exists $x.Path) }
foreach ($x in $folder) { $x | Add-Member -NotePropertyName PresentHere -NotePropertyValue (Test-Exists ($x.Path -replace '\\\*$', '')) }

function Save-Csv($rows, $file) {
    $path = Join-Path $OutDir $file
    if ($rows.Count -gt 0) { $rows | Sort-Object Tool, Path | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $path }
    else { Set-Content -Encoding UTF8 -LiteralPath $path -Value 'Tool,Category,Path,Source,Original' }
}
Save-Csv $exact 'hips-exact.csv'
Save-Csv $folder 'hips-folder.csv'
Save-Csv $nameOnly 'name-only.csv'
$skipOut = Join-Path $OutDir 'skipped.csv'
if ($skipped.Count -gt 0) {
    $skipped | Sort-Object Tool, Path |
        Select-Object Tool, Category, Path, Source, @{ Name = 'Reason'; Expression = { $_.Original } } |
        Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $skipOut
} else { Set-Content -Encoding UTF8 -LiteralPath $skipOut -Value 'Tool,Category,Path,Source,Reason' }

$sum = @()
$sum += "Get-LolrmmHipsList v$ScriptVersion  -  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$sum += "Catalogue : $($tools.Count) tools  SHA256 $sha"
$sum += "Excluded  : $($excluded.Count) tool(s) by -ExcludeTool [$($ExcludeTool -join ', ')]: $(($excluded | Sort-Object -Unique) -join '; ')"
$sum += "hips-exact.csv   : $($exact.Count) rows ($(@($exact | Where-Object PresentHere).Count) exist on this PC)  -> one HIPS rule each"
$sum += "hips-folder.csv  : $($folder.Count) rows ($(@($folder | Where-Object PresentHere).Count) exist on this PC) -> UNVERIFIED folder\* rules"
$sum += "name-only.csv    : $($nameOnly.Count) rows -> HIPS cannot match by name alone$(if (-not $ScanDisk) { ' (re-run with -ScanDisk to find them on this PC)' })"
$sum += "skipped.csv      : $($skipped.Count) rows (Reason column says why each was dropped)"
if ($ScanDisk) { $sum += "disk-scan       : $($found.Count) name-only exe(s) found on this PC and added to hips-exact.csv ($(@($exact | Where-Object { $_.Confidence -like 'LOW*' }).Count) are LOW confidence - check the Confidence column)" }
$sum += "NOTE: nothing was changed in ESET. Review hips-exact.csv first; delete rows for software you use."
Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'summary.txt') -Value $sum
$sum | ForEach-Object { Write-Host $_ }
Write-Host "Done. Files in: $OutDir"
