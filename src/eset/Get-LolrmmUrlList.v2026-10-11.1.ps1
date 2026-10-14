<#
.SYNOPSIS
  Build an ESET "List of blocked addresses" import file from the LOLRMM catalogue (https://lolrmm.io). READ-ONLY.

.DESCRIPTION
  Downloads (or reads) lolrmm.io/api/rmm_tools.json and turns each tool's Artifacts.Network domains into a
  text file you import into ESET (consumer: NOD32 / Internet Security / Security Ultimate / "ESET Security"):
    Advanced setup > Protections > Web access protection > URL list management > List of blocked addresses
    > Edit > Import  (one entry per line, UTF-8)

  ESET mask rules used here (ESET help, "URL address list"): a leading "*." also matches the bare domain, so
  "*.anydesk.com" blocks anydesk.com and every subdomain; "*" = any text, "?" = one character; no http(s)://
  prefix needed (applies to both).

  Output (in -OutDir):
    eset-blocked-urls.txt  the import file
    url-review.csv         every entry + which tool(s) it came from - REVIEW THIS, delete tools you use
    skipped.csv            everything dropped, with the reason
    ips.txt                raw IPs from the catalogue (ESET's URL list takes addresses, not IPs - for reference)
    summary.txt

  It NEVER touches ESET: no ecmd, no import, no registry. It only writes files.

  Safety filters (so the list cannot break ordinary browsing):
    - big shared platforms are never blocked at their root (github.com, githubusercontent.com, google.com,
      zoho.com, amazonaws.com, windows.net, cloudflare.com ...). A specific host UNDER them (e.g. one S3 bucket,
      remotedesktop.google.com) is kept because it only blocks that host.
    - placeholders ("user_managed", "<operator-configured ...>") and malformed masks are skipped.
    - entries already covered by a broader "*.domain" entry are folded into it.

.PARAMETER JsonPath     Use this local copy instead of downloading.
.PARAMETER OutDir       Output folder. Default: %USERPROFILE%\LOLRMM-UrlList\<yyyy-MM-dd_HHmmss>
.PARAMETER ExcludeTool  Tool-name patterns (-like, case-insensitive) to leave out. Default: TeamViewer, AnyDesk, Splashtop, RustDesk, mstsc, NVDA
.PARAMETER AllowDomain  Domains never to block, including everything under them. Default: teamviewer.com, anydesk.com, rustdesk.com, splashtop.com, splashtop.eu, eset.com
.PARAMETER ExtraDomain  Extra domains to block (download sites the catalogue only lists via Details.Website - it has
                        e.g. *.net.anydesk.com but NOT anydesk.com). Default: a short list of tools abused in
                        tech-support scams. Every other catalogue website goes to website-candidates.csv for review only.
.PARAMETER OptionalDomain  Domains that ARE remote-access related but also legitimately used by clients (AV updates, chat
                        widgets, SaaS, VPNs). Entries under these remain in the combined import file and are marked optional in url-review.csv.
#>
[CmdletBinding()]
param(
    [string]$JsonPath,
    [string]$OutDir,
    [string[]]$ExcludeTool = @('TeamViewer', 'AnyDesk', 'Splashtop', 'RustDesk', 'mstsc', 'NVDA'),
    [string[]]$AllowDomain = @('teamviewer.com', 'anydesk.com', 'rustdesk.com', 'splashtop.com', 'splashtop.eu', 'eset.com'),
    [string[]]$ExtraDomain = @('anydesk.com', 'atera.com', 'beyondtrust.com', 'realvnc.com', 'uvnc.com', 'aspia.org',
        'superops.com', 'netlockrmm.com', 'remoteripple.com', 'setme.net', 'controlio.net', 'xelvarunetio.pro'),
    [string[]]$OptionalDomain = @('sophos.com', 'sophosupd.com', 'sophosupd.net', 'basecamp.com', 'freshworks.com',
        'freshchat.com', 'myfreshworks.com', 'freshworksapi.com', 'freshdev.io', 'freshcloud.io', 'ninite.com', 'idrive.com',
        'metaquest.com', 'adobeconnect.com', 'goto.com', 'getgo.com', 'parallels.com', 'ghcr.io', 'ivanti.com',
        'fortra.com', 'zabbix.com', 'stunserver.stunprotocol.org', 'tailscale.com', 'tailscale.io', 'zerotier.com',
        'duetdisplay.com', 'parsec.app', 'parsec.gg', 'manageengine.com', 'connectwise.com', 'guacamole.apache.org',
        'devtunnels.ms', 'rel.tunnels.api.visualstudio.com', 'msp360.com', 'mspbackups.com', 'cloudberrylab.com',
        'downloads.zohocdn.com', 'downloads.zohodl.com.cn')
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-14.1-test'

# powershell.exe -File (the .bat launcher) passes "a,b,c" as ONE string - split list params ourselves
function Split-List([string[]]$v) { @($v | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$ExcludeTool = Split-List $ExcludeTool
$AllowDomain = Split-List $AllowDomain
$ExtraDomain = Split-List $ExtraDomain
$OptionalDomain = Split-List $OptionalDomain
$Url = 'https://lolrmm.io/api/rmm_tools.json'

# Roots that must never be blocked as a whole (bare or "*.root"). Hosts deeper under them are allowed.
$ProtectedRoot = @(
    'github.com', 'githubusercontent.com', 'raw.githubusercontent.com', 'objects.githubusercontent.com',
    'google.com', 'googleapis.com', 'gstatic.com', 'microsoft.com', 'live.com', 'office.com', 'windows.net',
    'blob.core.windows.net', 'servicebus.windows.net', 'azurewebsites.net', 'azureedge.net', 'azure.com',
    'amazonaws.com', 's3.amazonaws.com', 'cloudfront.net', 'cloudflare.com', 'api.cloudflare.com', 'cloudflare.net',
    'cdn.cloudflare.net', 'cloudflarestorage.com', 'r2.cloudflarestorage.com', 'pages.dev', 'workers.dev',
    'firebaseapp.com', 'appspot.com', 'herokuapp.com', 'vercel.app', 'netlify.app', 'pubnubapi.com',
    'zoho.com', 'zoho.com.au', 'zoho.com.cn', 'zoho.com.eu', 'zoho.eu', 'zoho.in',
    'taobao.com', 'softonic.com', 'en.softonic.com', 'apple.com', 'icloud.com', 'dropbox.com', 'box.com',
    'visualstudio.com', 'api.visualstudio.com', 'amazon.com', 'akamaized.net', 'akamaiedge.net'
)

if (-not $OutDir) {
    # USERPROFILE may be unset (service accounts, some elevated/RDP contexts). Falling back
    # to a folder beside this script is better than throwing: the output folder is the thing
    # the operator is looking for, so it must not be the thing that fails.
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $PSScriptRoot }
    $OutDir = Join-Path $base ('LOLRMM-UrlList\' + (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Get-LolrmmUrlList v$ScriptVersion  ->  $OutDir"

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

$protected = @{}
foreach ($r in $ProtectedRoot) { $protected[$r.ToLowerInvariant()] = $true }
$allow = @($AllowDomain | ForEach-Object { $_.Trim().TrimStart('*', '.').ToLowerInvariant() } | Where-Object { $_ })

function Test-Under([string]$h, [string]$root) { return ($h -eq $root -or $h.EndsWith('.' + $root)) }

# ---------------------------------------------------------------- collect + normalise
$entries = @{}          # mask -> @{ Tools = hashset; Originals = hashset }
$skipped = New-Object System.Collections.ArrayList
$ips = New-Object System.Collections.ArrayList
$excluded = New-Object System.Collections.ArrayList

function Add-Skip($tool, $orig, $reason) {
    [void]$skipped.Add([pscustomobject]@{ Tool = $tool; Entry = $orig; Reason = $reason })
}

$extra = @{}
foreach ($x in $ExtraDomain) { $extra[$x.Trim().TrimStart('*', '.').ToLowerInvariant()] = $true }
$websites = New-Object System.Collections.ArrayList
$excludedHosts = New-Object System.Collections.ArrayList
# -ExtraDomain entries always go in (as their own pseudo-tool), even if no catalogue website matches them
$tools = @($tools) + [pscustomobject]@{
    Name = '(-ExtraDomain)'; Details = [pscustomobject]@{ Website = '' }
    Artifacts = [pscustomobject]@{ Network = @([pscustomobject]@{ Domains = @($extra.Keys) }) }
}

foreach ($t in $tools) {
    $name = [string]$t.Name
    $skipTool = $false
    foreach ($pat in $ExcludeTool) { if ($name -like "*$pat*") { $skipTool = $true } }
    if ($skipTool) {
        [void]$excluded.Add($name)
        if (([string]$t.Details.Website).ToLowerInvariant() -match '^(?:[a-z]+://)?(?:www\.)?([^/:?#]+)') { [void]$excludedHosts.Add($Matches[1]) }
        continue
    }

    # Website host: blocked only if listed in -ExtraDomain (credits the tool), else recorded for review
    $doms = New-Object System.Collections.ArrayList
    $w = ([string]$t.Details.Website).Trim().ToLowerInvariant()
    if ($w -match '^(?:[a-z]+://)?([^/:?#]+)') {
        $wh = $Matches[1] -replace '^www\.', ''
        if ($extra.ContainsKey($wh)) { [void]$doms.Add($wh) }
        else { [void]$websites.Add([pscustomobject]@{ Tool = $name; Website = $wh }) }
    }
    foreach ($n in @($t.Artifacts.Network)) { if ($n) { foreach ($d in @($n.Domains)) { if ($d) { [void]$doms.Add($d) } } } }

    foreach ($d in $doms) {
        $orig = [string]$d
        if ($name -eq '(-ExtraDomain)' -and @($excludedHosts | Where-Object { Test-Under $orig $_ }).Count -gt 0) {
            Add-Skip $name $orig 'website of a tool in -ExcludeTool'; continue
        }
        $s = $orig.Trim().ToLowerInvariant()
        $s = $s -replace '^[a-z]+://', ''
        $s = ($s -split '[/:]')[0]
        $s = $s.TrimEnd('.')

        if ($s -eq '' -or $s -match '[<> ]' -or $s -eq 'user_managed') { Add-Skip $name $orig 'placeholder (operator-configured, no fixed domain)'; continue }
        if ($s -match '^\d{1,3}(\.\d{1,3}){3}$') { [void]$ips.Add("$s`t$name"); Add-Skip $name $orig 'IP address (see ips.txt)'; continue }
        if ($s.StartsWith('_')) { Add-Skip $name $orig 'DNS SRV record, not a web address'; continue }
        if ($s -notmatch '^[a-z0-9*?.\-]+$' -or $s -match '\.\.|(^|\.)-|-(\.|$)|\*\*') { Add-Skip $name $orig 'malformed mask'; continue }

        $hostPart = $s -replace '^\*\.', ''
        if ($hostPart -match '\*|\?') {
            # mid-label wildcard (relay-*.net.anydesk.com): keep the mask as written, check its fixed suffix
            $fixed = ($hostPart -split '[*?]')[-1].TrimStart('.', '-')
            $mask = $s
        } else {
            $hostPart = $hostPart -replace '^www\.', ''
            $fixed = $hostPart
            $mask = '*.' + $hostPart
        }
        if ($fixed -notmatch '\.') { Add-Skip $name $orig 'too broad (no fixed domain part)'; continue }
        if ($protected.ContainsKey($hostPart) -or $protected.ContainsKey($fixed)) { Add-Skip $name $orig 'shared platform root - would break normal sites'; continue }
        $allowed = $false
        foreach ($a in $allow) { if (Test-Under $fixed $a) { $allowed = $true } }
        if ($allowed) { Add-Skip $name $orig 'under -AllowDomain'; continue }

        if (-not $entries.ContainsKey($mask)) {
            $entries[$mask] = @{ Tools = New-Object System.Collections.Generic.HashSet[string]; Originals = New-Object System.Collections.Generic.HashSet[string]; Host = $fixed; Wild = ($hostPart -match '\*|\?') }
        }
        [void]$entries[$mask].Tools.Add($name)
        [void]$entries[$mask].Originals.Add($orig)
    }
}

# ---------------------------------------------------------------- fold entries covered by a broader "*.domain"
$plainRoots = @($entries.Keys | Where-Object { -not $entries[$_].Wild } | ForEach-Object { $entries[$_].Host })
$final = New-Object System.Collections.ArrayList
foreach ($k in $entries.Keys) {
    $e = $entries[$k]
    $cover = $null
    foreach ($r in $plainRoots) {
        if ($r -ne $e.Host -and $e.Host.EndsWith('.' + $r)) { $cover = $r; break }
        if ($e.Wild -and $r -eq $e.Host) { $cover = $r; break }
    }
    if ($cover) {
        Add-Skip (($e.Tools | Sort-Object) -join '; ') $k "covered by *.$cover"
        foreach ($tl in $e.Tools) { [void]$entries['*.' + $cover].Tools.Add($tl) }
        continue
    }
    $tier = 'main'
    foreach ($o in $OptionalDomain) { if (Test-Under $e.Host $o.Trim().TrimStart('*', '.').ToLowerInvariant()) { $tier = 'optional' } }
    [void]$final.Add([pscustomobject]@{
        Entry = $k
        Tier = $tier
        Tools = (($e.Tools | Sort-Object) -join '; ')
        Originals = (($e.Originals | Sort-Object) -join '; ')
    })
}
# refresh Tools column after folding
foreach ($f in $final) { $f.Tools = (($entries[$f.Entry].Tools | Sort-Object) -join '; ') }
$final = @($final | Sort-Object Tier, Entry)
$main = @($final | Where-Object { $_.Tier -eq 'main' })
$optional = @($final | Where-Object { $_.Tier -eq 'optional' })

# ---------------------------------------------------------------- write
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM - a BOM would become part of the first entry
[IO.File]::WriteAllLines((Join-Path $OutDir 'eset-blocked-urls.txt'), [string[]]@($final | Sort-Object Entry | ForEach-Object { $_.Entry }), $utf8)
# Remove only the legacy second import file when rebuilding the same output folder.
$legacyOptional = Join-Path $OutDir 'eset-blocked-urls-optional.txt'
if (Test-Path -LiteralPath $legacyOptional) { Remove-Item -LiteralPath $legacyOptional -Force }
$final | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'url-review.csv')
$websites | Sort-Object Website, Tool | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'website-candidates.csv')
if ($skipped.Count -gt 0) {
    $skipped | Sort-Object Reason, Tool | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'skipped.csv')
} else { Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'skipped.csv') -Value 'Tool,Entry,Reason' }
[IO.File]::WriteAllLines((Join-Path $OutDir 'ips.txt'), [string[]]@($ips | Sort-Object -Unique), $utf8)

$sum = @()
$sum += "Get-LolrmmUrlList v$ScriptVersion  -  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$sum += "Catalogue : $($tools.Count - 1) tools  SHA256 $sha"
$sum += "Excluded  : $(@($excluded | Sort-Object -Unique).Count) tool(s) by -ExcludeTool [$($ExcludeTool -join ', ')]: $(($excluded | Sort-Object -Unique) -join '; ')"
$sum += "Allowed   : $($AllowDomain -join ', ')"
$sum += "eset-blocked-urls.txt : $($final.Count) entries from $(@($final | ForEach-Object { $_.Tools -split '; ' } | Sort-Object -Unique).Count) tools  -> import this"
$sum += "Combined list includes $($optional.Count) entries clients may legitimately use (AV, SaaS, VPN). Review optional-tier rows in url-review.csv before import."
$sum += "website-candidates.csv : $($websites.Count) tool websites NOT blocked (review; add with -ExtraDomain)"
$sum += "skipped.csv           : $($skipped.Count) rows (Reason column says why)"
$sum += "ips.txt               : $(@($ips | Sort-Object -Unique).Count) raw IPs (not importable into the URL list)"
$sum += "NOTE: nothing was changed in ESET. Review url-review.csv; remove lines for any tool a client legitimately uses."
Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'summary.txt') -Value $sum
$sum | ForEach-Object { Write-Host $_ }
Write-Host "Done. Files in: $OutDir"
