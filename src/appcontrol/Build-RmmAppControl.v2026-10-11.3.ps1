<#
.SYNOPSIS
  Build a Windows App Control (WDAC) policy that BLOCKS remote-access tools by their code-signing certificate,
  from the LOLRMM catalogue (https://lolrmm.io). Builds files only - it does NOT install anything.

.DESCRIPTION
  lolrmm.io/api/rmm_tools.json carries each tool's code-signing certificate (CodeSigning.certificates[].
  certificate_der_base64). From those this script builds deny rules that match the SIGNATURE, not the file name or
  folder - so a renamed copy, an email attachment or a portable exe in Downloads is blocked the same as an install.

  Per certificate, two deny rules (same format ConfigCI's New-CIPolicy produces - verified 2026-10-11 against it):
    leaf      CertRoot = TBS hash of the vendor's certificate                (blocks that exact certificate)
    publisher CertRoot = TBS hash of the issuing CA + CertPublisher = vendor CN (also blocks the vendor's renewed
              certificates from the same CA - this is what keeps the block working after a vendor renews)
  TBS hash = hash of the certificate's to-be-signed part, using the hash of its own signature algorithm.

  Policy = Microsoft's AllowAll template (%windir%\schemas\CodeIntegrity\ExamplePolicies\AllowAll.xml) + these
  denies in the user-mode scenario only. Everything not denied keeps running. Script enforcement stays disabled
  (template default), so PowerShell is NOT put into Constrained Language Mode. Same layout as Microsoft's own
  recommended block-rules policy, which Microsoft documents as safe to deploy standalone.

  ONLY vendors on the hand-checked lists below are used. The catalogue attaches some unrelated certificates to
  tools (WinRAR, PuTTY, Unity, OpenVPN, Symantec, Microsoft ...) - blocking those would break ordinary software,
  so nothing is taken from the catalogue automatically.

  TOGGLES: TeamViewer (T), AnyDesk (A) and Splashtop (S) can each be blocked (1) or allowed (0) per PC. Every one of
  the 8 combinations is pre-built, so a PC can switch without ConfigCI (Home). Variant code e.g. T1A1S0 = block
  TeamViewer + AnyDesk, allow Splashtop (the default).

  Output (default: .\policy next to this script, which is where Install-RmmAppControl / START-HERE look):
    variants\RmmBlock-{Enforce,Audit}-T?A?S?.cip / .xml   all 8 toggle combinations, both modes
    RmmBlock-Enforce.cip / RmmBlock-Audit.cip             copies of the default variant (T1A1S0)
    signers.csv                   every rule, its vendor, tools, tier and certificate dates
    summary.txt

  Needs the ConfigCI module (ConvertFrom-CIPolicy) - present on Windows 10/11 Pro/Enterprise. Build on a Pro PC,
  then copy the policy folder to Home PCs; the .cip files are portable.

.PARAMETER JsonPath         Use this local copy of rmm_tools.json instead of downloading.
.PARAMETER OutDir           Output folder. Default: <script folder>\policy
.PARAMETER IncludeOptional  Also block the OPTIONAL vendors (legit software some clients use: NetSupport School,
                            Impero/Netop, Veyon, GoTo, Zoho, AOMEI, RealVNC, Radmin/Advanced IP Scanner ...).
.PARAMETER ExcludeSigner    Vendor names to leave out even if listed (e.g. a client really uses TeamViewer).
.PARAMETER NoPublisherRules Leaf-certificate rules only (no issuing-CA lookups; the block then stops working when the
                            vendor renews its certificate until the policy is rebuilt from a newer catalogue).
#>
[CmdletBinding()]
param(
    [string]$JsonPath,
    [string]$OutDir,
    [switch]$IncludeOptional,
    [string[]]$ExcludeSigner = @(),
    [switch]$NoPublisherRules
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-11.3'
$Url = 'https://lolrmm.io/api/rmm_tools.json'

# Friendly name written into every generated policy, so an installed PC is self-describing.
# Deployment-specific branding (a shop name) belongs here and in $LogDirName in
# Install-RmmAppControl; keep them plain ASCII - PS 5.1 reads BOM-less files as Windows-1252.
$PolicyName = 'Remote Access Tool Blocker'
# Fixed ID: every build replaces the previously installed copy instead of stacking a second policy.
$PolicyGuid = '{2D13BFB7-4304-4847-9CDD-37820D3EE9B7}'

function Split-List([string[]]$v) { @($v | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$ExcludeSigner = Split-List $ExcludeSigner

# Vendor (certificate signer) names, compared after lower-casing and dropping everything but a-z0-9.
# MAIN: dedicated remote-control / RMM vendors - nothing else a home user needs is signed with these.
$MainSigners = @(
    'DUC FABULOUS CO.,LTD',
    'ConnectWise, LLC', 'ConnectWise, Inc.', 'Aeroadmin LLC', 'Nanosystems S.r.l.', 'Begonia Holdings LLC',
    'Kopetra Ltd.', 'REMOTE UTILITIES PTE. LTD.', 'ISL Online Ltd.', 'SimpleHelp Ltd', 'ShowMyPC INC',
    'Atera Networks Ltd', 'NinjaOne LLC', 'Servably Inc.', 'Level Software, Inc.', 'Action1 Corporation',
    'Rsupport Co., Ltd.', 'IP Ter-Osipov Aleksey Vladimirovich', 'Advanced Technologies LLC',
    'Anyplace Control Software', 'Yurii Honcharuk', 'Honcharuk Yuriy', 'Instant Housecall', 'helpU Inc.',
    'KOINO Co., Ltd.', 'LinkMeMine Inc.', 'DWSNET srl', 'FastViewer GmbH', 'pcvisit software ag',
    'Spytech Software and Design, Inc.', 'LogMeIn, Inc.', 'PhaseFive Systems LLC', 'Phase Five Systems LLC',
    'GORELO TECH, INC.', 'FleetDeck Inc', 'hs2n Informationstechnologie GmbH', 'Knowhow Electel Inc.',
    'remot3.it, Inc.', 'Superops Inc.', 'Domotz Inc', 'Plooto Star Inc', 'KHELPDESK TECHNOLOGY LTDA',
    'Net Transmit & Receive SL', 'Techinline Ltd', 'MOONWHITE TECHNOLOGIES PRIVATE LIMITED',
    'C&P Global Investors LLC', 'Christopher West', 'Electronic Team, Inc.', 'Ngrok, Inc.'
)
# OPTIONAL: remote-access vendors whose certificate ALSO signs software clients use on purpose.
$OptionalSigners = @(
    'AOMEI International Network Limited', 'RealVNC Ltd', 'Famatech Corp.', 'GoTo Technologies USA, LLC',
    'NetSupport Ltd', 'Impero Solutions Limited', 'NETOP TECH SRL', 'ENTER S.R.L.', 'Kaseya Holdings Inc.',
    'N-ABLE TECHNOLOGIES LTD', 'Ivanti, Inc.', 'LANDesk Software, Inc.', 'ZOHO Corporation Private Limited',
    'IDrive, Inc.', 'NoMachine S.a r.l.', 'Devolutions Inc', 'Royal Apps GmbH', 'JumpCloud Inc', 'Tanium',
    'Tanium Inc.', 'SOTI Inc.', 'Rocket Software, Inc.', 'Quest Software Inc.', 'Absolute Software Corp.',
    'Tobias Junghans', 'EASYVISTA SAS', 'MSPBytes Corp', 'Zabbix SIA', 'Rapid7 LLC', 'ITarian LLC',
    'Comodo Security Solutions', 'Comodo Security Solutions, Inc.', 'Bomgar Corporation', 'ZeroTier, Inc.'
)
# TOGGLES: blocked or allowed per PC (START-HERE checkboxes). Variant letter -> vendor names on the certificate.
$ToggleGroups = [ordered]@{
    T = @{ Name = 'TeamViewer'; Signers = @('TeamViewer Germany GmbH', 'TeamViewer GmbH') }
    A = @{ Name = 'AnyDesk'; Signers = @('AnyDesk Software GmbH') }
    S = @{ Name = 'Splashtop'; Signers = @('Splashtop Inc.') }
    # RustDesk: lolrmm has no certificate for it. Cert below = the signer of the official rustdesk-1.5.0 Windows builds
    # (github.com/rustdesk/rustdesk/releases, 2026-09-30; CN=PURSLANE, Sectigo EV R36, thumbprint 4230334F...2F5DA5,
    # valid to 2028-02-23). FileNames = OriginalFileName deny as a backup for self-built / custom-client copies.
    R = @{ Name = 'RustDesk'; Signers = @('PURSLANE'); FileNames = @('rustdesk.exe'); Certs = @(
        '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'
    ) }
}
$DefaultVariant = 'T1A1S0R1'
# Hard stop: never emit a rule whose certificate CN contains one of these, whatever the lists say.
$NeverBlock = @('microsoft', 'windows', 'google', 'apple', 'eset', 'adobe', 'unity', 'oculus', 'symantec',
    'winrar', 'powersoftware', 'openvpn', 'simontatham', 'tuxera', 'mozilla', 'oracle', 'intelcorp', 'nvidia',
    'advancedmicro', 'dellinc', 'hpinc', 'hewlett', 'lenovo', 'valve', 'amazon', 'cloudflare', 'digicert', 'sectigo',
    'globalsign', 'entrust', 'certum')

function Get-Key([string]$s) { (($s.ToLowerInvariant()) -replace '[^a-z0-9]', '') }
$mainKeys = @{}; foreach ($s in $MainSigners) { $mainKeys[(Get-Key $s)] = $true }
$optKeys = @{}; foreach ($s in $OptionalSigners) { $optKeys[(Get-Key $s)] = $true }
$exclKeys = @{}; foreach ($s in $ExcludeSigner) { $exclKeys[(Get-Key $s)] = $true }
$groupOf = @{}; foreach ($g in $ToggleGroups.Keys) { foreach ($s in $ToggleGroups[$g].Signers) { $groupOf[(Get-Key $s)] = $g } }

if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot 'policy' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Build-RmmAppControl v$ScriptVersion  ->  $OutDir"

if (-not (Get-Command ConvertFrom-CIPolicy -ErrorAction SilentlyContinue)) {
    throw 'ConvertFrom-CIPolicy (ConfigCI module) not found. Build on a Windows 10/11 Pro or Enterprise PC, then copy the policy folder.'
}
$template = Join-Path $env:windir 'schemas\CodeIntegrity\ExamplePolicies\AllowAll.xml'
if (-not (Test-Path -LiteralPath $template)) { throw "Template not found: $template" }

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
# toggle groups that carry their own certificates (not in the catalogue) go through the same pipeline as a pseudo-tool
foreach ($g in $ToggleGroups.Keys) {
    foreach ($cb in @($ToggleGroups[$g].Certs)) {
        if ($cb) { $tools = @($tools) + [pscustomobject]@{ Name = $ToggleGroups[$g].Name; CodeSigning = [pscustomobject]@{ certificates = @([pscustomobject]@{ signer_name = $ToggleGroups[$g].Signers[0]; certificate_der_base64 = $cb }) } } }
    }
}
Write-Host ("Catalogue: {0} tools, SHA256 {1}" -f $tools.Count, $sha)

# ---------------------------------------------------------------- certificate helpers
function Get-DerLen([byte[]]$b, [int]$i) {
    # DER length at $b[$i] -> @(value, number of length bytes)
    $l = [int]$b[$i]
    if ($l -lt 0x80) { return @($l, 1) }
    $n = $l -band 0x7F; $v = 0
    for ($k = 1; $k -le $n; $k++) { $v = ($v * 256) + [int]$b[$i + $k] }
    return @($v, (1 + $n))
}
function Get-TbsHash([Security.Cryptography.X509Certificates.X509Certificate2]$c) {
    [byte[]]$der = $c.RawData
    $outer = Get-DerLen $der 1
    $start = 1 + $outer[1]                       # tbsCertificate SEQUENCE starts here
    $inner = Get-DerLen $der ($start + 1)
    $len = 1 + $inner[1] + $inner[0]
    [byte[]]$tbs = New-Object byte[] $len
    [Array]::Copy($der, $start, $tbs, 0, $len)
    switch ($c.SignatureAlgorithm.Value) {
        { $_ -in '1.2.840.113549.1.1.5', '1.2.840.10045.4.1', '1.3.14.3.2.29' } { $h = [Security.Cryptography.SHA1]::Create(); break }
        { $_ -in '1.2.840.113549.1.1.11', '1.2.840.10045.4.3.2' } { $h = [Security.Cryptography.SHA256]::Create(); break }
        { $_ -in '1.2.840.113549.1.1.12', '1.2.840.10045.4.3.3' } { $h = [Security.Cryptography.SHA384]::Create(); break }
        { $_ -in '1.2.840.113549.1.1.13', '1.2.840.10045.4.3.4' } { $h = [Security.Cryptography.SHA512]::Create(); break }
        default { return $null }
    }
    return (($h.ComputeHash($tbs) | ForEach-Object { $_.ToString('X2') }) -join '')
}
function Get-Cert([string]$b64) {
    [byte[]]$raw = [Convert]::FromBase64String($b64.Trim())
    # some catalogue entries are base64 of a PEM file rather than of the DER bytes
    $head = [Text.Encoding]::ASCII.GetString($raw, 0, [Math]::Min(11, $raw.Length))
    if ($head -eq '-----BEGIN ') {
        $pem = [Text.Encoding]::ASCII.GetString($raw)
        $raw = [Convert]::FromBase64String((($pem -split "`n") | Where-Object { $_ -notmatch '^-----' }) -join '')
    }
    return New-Object Security.Cryptography.X509Certificates.X509Certificate2 (, $raw)
}
$issuerCache = @{}
function Get-PcaCert($c) {
    # The certificate one below the root (what ConfigCI's Publisher level uses). Windows fetches missing
    # intermediates from the certificate's AIA URL. $null when no complete chain can be built.
    $key = $c.Issuer
    if ($issuerCache.ContainsKey($key)) { return $issuerCache[$key] }
    $ch = New-Object Security.Cryptography.X509Certificates.X509Chain
    $ch.ChainPolicy.RevocationMode = 'NoCheck'
    $ch.ChainPolicy.VerificationFlags = 'AllFlags'
    $ch.ChainPolicy.UrlRetrievalTimeout = New-TimeSpan -Seconds 15
    [void]$ch.Build($c)
    $els = @($ch.ChainElements | ForEach-Object { $_.Certificate })
    $pca = $null
    if ($els.Count -ge 3 -and $els[-1].Subject -eq $els[-1].Issuer) { $pca = $els[-2] }
    $issuerCache[$key] = $pca
    return $pca
}

# ---------------------------------------------------------------- pick certificates
$rules = @{}            # dedupe key -> rule object
$skipped = New-Object System.Collections.ArrayList
foreach ($t in $tools) {
    foreach ($ce in @($t.CodeSigning.certificates)) {
        if (-not $ce) { continue }
        $signer = [string]$ce.signer_name
        $k = Get-Key $signer
        if ($exclKeys.ContainsKey($k)) { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = '-ExcludeSigner' }); continue }
        if ($groupOf.ContainsKey($k)) { $tier = 'toggle-' + $groupOf[$k] }
        elseif ($mainKeys.ContainsKey($k)) { $tier = 'main' }
        elseif ($optKeys.ContainsKey($k)) {
            if (-not $IncludeOptional) { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = 'optional vendor (use -IncludeOptional)' }); continue }
            $tier = 'optional'
        } else { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = 'not on the hand-checked vendor list' }); continue }
        if (-not $ce.certificate_der_base64) { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = 'catalogue has no certificate bytes' }); continue }
        try { $c = Get-Cert ([string]$ce.certificate_der_base64) } catch { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = 'certificate unreadable' }); continue }
        $cn = $c.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        $ck = Get-Key $cn
        $bad = @($NeverBlock | Where-Object { $ck.Contains($_) })
        if ($bad.Count -gt 0) { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = "$signer (CN=$cn)"; Reason = "never-block safety list ($($bad -join ','))" }); continue }
        if ((Get-Key $cn) -ne $k -and -not ($mainKeys.ContainsKey($ck) -or $optKeys.ContainsKey($ck) -or $groupOf.ContainsKey($ck))) {
            [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = "$signer (CN=$cn)"; Reason = 'certificate CN does not match the listed vendor' }); continue
        }

        $leafTbs = Get-TbsHash $c
        if (-not $leafTbs) { [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = "unsupported signature algorithm $($c.SignatureAlgorithm.Value)" }); continue }
        $id = 'leaf|' + $leafTbs
        if (-not $rules.ContainsKey($id)) {
            $rules[$id] = [pscustomobject]@{ Kind = 'leaf'; Tier = $tier; Publisher = $cn; CertRoot = $leafTbs; CertPublisher = '';
                Name = $cn; Issuer = $c.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $true);
                NotAfter = $c.NotAfter.ToString('yyyy-MM-dd'); Tools = (New-Object System.Collections.Generic.HashSet[string]) }
        }
        [void]$rules[$id].Tools.Add([string]$t.Name)

        if (-not $NoPublisherRules) {
            $pca = Get-PcaCert $c
            if ($pca) {
                $pcaTbs = Get-TbsHash $pca
                $pcaName = $pca.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
                if ($pcaTbs) {
                    $id = 'pub|' + $pcaTbs + '|' + $cn
                    if (-not $rules.ContainsKey($id)) {
                        $rules[$id] = [pscustomobject]@{ Kind = 'publisher'; Tier = $tier; Publisher = $cn; CertRoot = $pcaTbs; CertPublisher = $cn;
                            Name = $pcaName; Issuer = $pcaName; NotAfter = ''; Tools = (New-Object System.Collections.Generic.HashSet[string]) }
                    }
                    [void]$rules[$id].Tools.Add([string]$t.Name)
                }
            } else {
                [void]$skipped.Add([pscustomobject]@{ Tool = $t.Name; Signer = $signer; Reason = 'no issuing-CA chain (leaf rule only)' })
            }
        }
    }
}
$list = @($rules.Values | Sort-Object Tier, Publisher, Kind, CertRoot)
if ($list.Count -eq 0) { throw 'No rules produced - check the catalogue and the vendor lists.' }
Write-Host ("Rules: {0} ({1} leaf, {2} publisher) for {3} vendors" -f $list.Count, @($list | Where-Object Kind -eq 'leaf').Count,
    @($list | Where-Object Kind -eq 'publisher').Count, @($list | Select-Object -ExpandProperty Publisher -Unique).Count)

# ---------------------------------------------------------------- write policy XML (+ compile)
$now = Get-Date
$version = '1.{0}.{1}.{2}' -f $now.ToString('yyMM'), [int]$now.ToString('ddHH'), [int]$now.ToString('mmss')
$ns = 'urn:schemas-microsoft-com:sipolicy'

function New-Policy([bool]$audit, $ruleSet, [string]$variant, [string[]]$denyNames) {
    [xml]$x = Get-Content -Raw -LiteralPath $template
    $root = $x.DocumentElement
    $nm = New-Object Xml.XmlNamespaceManager $x.NameTable
    $nm.AddNamespace('p', $ns)
    $root.SelectSingleNode('p:VersionEx', $nm).InnerText = $version
    $root.SelectSingleNode('p:PolicyID', $nm).InnerText = $PolicyGuid
    $root.SelectSingleNode('p:BasePolicyID', $nm).InnerText = $PolicyGuid
    if ($audit) {
        $r = $x.CreateElement('Rule', $ns); $o = $x.CreateElement('Option', $ns); $o.InnerText = 'Enabled:Audit Mode'
        [void]$r.AppendChild($o); [void]$root.SelectSingleNode('p:Rules', $nm).AppendChild($r)
    }
    $signers = $root.SelectSingleNode('p:Signers', $nm)
    $ciSigners = $root.SelectSingleNode('p:CiSigners', $nm)
    $um = $root.SelectSingleNode("p:SigningScenarios/p:SigningScenario[@Value='12']/p:ProductSigners", $nm)
    $denied = $x.CreateElement('DeniedSigners', $ns)
    $i = 0
    foreach ($rule in $ruleSet) {
        $i++
        $sid = 'ID_SIGNER_RMM_{0}' -f $i
        $s = $x.CreateElement('Signer', $ns)
        $s.SetAttribute('ID', $sid)
        $s.SetAttribute('Name', ('{0} ({1})' -f $rule.Publisher, $rule.Kind))
        $cr = $x.CreateElement('CertRoot', $ns); $cr.SetAttribute('Type', 'TBS'); $cr.SetAttribute('Value', $rule.CertRoot)
        [void]$s.AppendChild($cr)
        if ($rule.CertPublisher) { $cp = $x.CreateElement('CertPublisher', $ns); $cp.SetAttribute('Value', $rule.CertPublisher); [void]$s.AppendChild($cp) }
        [void]$signers.AppendChild($s)
        $d = $x.CreateElement('DeniedSigner', $ns); $d.SetAttribute('SignerId', $sid); [void]$denied.AppendChild($d)
        $cs = $x.CreateElement('CiSigner', $ns); $cs.SetAttribute('SignerId', $sid); [void]$ciSigners.AppendChild($cs)
    }
    [void]$um.InsertBefore($denied, $um.FirstChild)      # schema order: (AllowedSigners) DeniedSigners FileRulesRef
    # OriginalFileName denies (same form as Microsoft's recommended block rules: all versions)
    $fileRules = $root.SelectSingleNode('p:FileRules', $nm)
    $umRefs = $um.SelectSingleNode('p:FileRulesRef', $nm)
    $j = 0
    foreach ($fn in @($denyNames | Where-Object { $_ })) {
        $j++; $fid = 'ID_DENY_RMM_F_{0}' -f $j
        $fr = $x.CreateElement('Deny', $ns); $fr.SetAttribute('ID', $fid); $fr.SetAttribute('FriendlyName', $fn); $fr.SetAttribute('FileName', $fn)
        $fr.SetAttribute('MinimumFileVersion', '0.0.0.0'); $fr.SetAttribute('MaximumFileVersion', '65535.65535.65535.65535')
        [void]$fileRules.AppendChild($fr)
        $rr = $x.CreateElement('FileRuleRef', $ns); $rr.SetAttribute('RuleID', $fid); [void]$umRefs.AppendChild($rr)
    }
    $mode = if ($audit) { 'Audit' } else { 'Enforce' }
    foreach ($st in $root.SelectNodes('p:Settings/p:Setting', $nm)) {
        if ($st.ValueName -eq 'Name') { $st.Value.String = "$PolicyName (lolrmm) - $mode [$variant]" }
        if ($st.ValueName -eq 'Id') { $st.Value.String = $version }
    }
    return $x
}

$varDir = Join-Path $OutDir 'variants'
New-Item -ItemType Directory -Force -Path $varDir | Out-Null
$letters = @($ToggleGroups.Keys)
$variantCount = [int][Math]::Pow(2, $letters.Count)
for ($n = 0; $n -lt $variantCount; $n++) {
    $code = ''; $on = @{}
    for ($b = 0; $b -lt $letters.Count; $b++) {
        $bit = [int](($n -shr ($letters.Count - 1 - $b)) -band 1)
        $code += $letters[$b] + $bit; $on[$letters[$b]] = ($bit -eq 1)
    }
    $set = @($list | Where-Object { $_.Tier -notlike 'toggle-*' -or $on[$_.Tier.Substring(7)] })
    $names = @($letters | Where-Object { $on[$_] } | ForEach-Object { @($ToggleGroups[$_].FileNames) } | Where-Object { $_ })
    foreach ($mode in 'Enforce', 'Audit') {
        $x = New-Policy ($mode -eq 'Audit') $set $code $names
        $xmlPath = Join-Path $varDir "RmmBlock-$mode-$code.xml"
        $cipPath = Join-Path $varDir "RmmBlock-$mode-$code.cip"
        $ws = New-Object Xml.XmlWriterSettings; $ws.Indent = $true; $ws.Encoding = New-Object System.Text.UTF8Encoding($false)
        $w = [Xml.XmlWriter]::Create($xmlPath, $ws); $x.Save($w); $w.Close()
        if (Test-Path -LiteralPath $cipPath) { Remove-Item -LiteralPath $cipPath -Force }
        ConvertFrom-CIPolicy -XmlFilePath $xmlPath -BinaryFilePath $cipPath | Out-Null
        if (-not (Test-Path -LiteralPath $cipPath)) { throw "Compile failed: $cipPath" }
        if ($code -eq $DefaultVariant) {
            Copy-Item -LiteralPath $cipPath -Destination (Join-Path $OutDir "RmmBlock-$mode.cip") -Force
            Copy-Item -LiteralPath $xmlPath -Destination (Join-Path $OutDir "RmmBlock-$mode.xml") -Force
        }
    }
    Write-Host ("  {0}: {1} signer rules + {2} file-name rules" -f $code, $set.Count, $names.Count)
}
foreach ($g in $letters) {
    $cnt = @($list | Where-Object { $_.Tier -eq "toggle-$g" }).Count
    if ($cnt -eq 0) { Write-Warning "Toggle $g ($($ToggleGroups[$g].Name)) has NO rules - the catalogue has no usable certificate for it." }
}

$list | Select-Object Tier, Kind, Publisher, @{ n = 'Tools'; e = { ($_.Tools | Sort-Object) -join '; ' } }, Issuer, NotAfter, CertRoot, CertPublisher |
    Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'signers.csv')
$skipped | Sort-Object Reason, Signer -Unique | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'skipped-signers.csv')
$covered = @($list | ForEach-Object { $_.Tools } | Sort-Object -Unique)
$sum = @()
$sum += "Build-RmmAppControl v$ScriptVersion  -  $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$sum += "Catalogue : $($tools.Count) tools  SHA256 $sha"
$sum += "Policy    : $PolicyGuid  version $version"
$sum += "Rules     : $($list.Count) deny rules, $(@($list | Select-Object -ExpandProperty Publisher -Unique).Count) vendors, $($covered.Count) tools$(if ($IncludeOptional) { ' (incl. OPTIONAL vendors)' })"
$sum += "Tools     : $($covered -join '; ')"
if ($ExcludeSigner.Count) { $sum += "Excluded  : $($ExcludeSigner -join ', ')" }
$sum += "Toggles   : $(($letters | ForEach-Object { '{0}={1} ({2} rules)' -f $_, $ToggleGroups[$_].Name, @($list | Where-Object Tier -eq "toggle-$_").Count }) -join ', ')  default $DefaultVariant"
$sum += "Install   : START-HERE (checkboxes) or Install-RmmAppControl -Mode Enforce -Variant T1A1S0R1"
Set-Content -Encoding UTF8 -LiteralPath (Join-Path $OutDir 'summary.txt') -Value $sum
$sum | ForEach-Object { Write-Host $_ }
