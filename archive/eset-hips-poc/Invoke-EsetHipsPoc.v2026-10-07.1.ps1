# Invoke-EsetHipsPoc - automates OWNER-RUN.md (LOLRMM / ESET Phase 1 observation).
# Automated: hash check, environment capture, folders+ACL, 3x ecmd /getcfg export,
#            de-elevated test launches, XML diffing, sanitized diff, RESULTS.txt fill-in.
# Manual (by design, per the guide): create/remove the ONE HIPS rule in the ESET UI,
#            and read Tools > Log files > HIPS. The script pauses and asks you for those.
# Never imports XML, never changes ESET settings, never collects passwords.
# PowerShell 5.1, ASCII only. Run via Run-EsetHipsPoc.bat (self-elevates).
param(
    [string]$KitDir = (Join-Path $env:USERPROFILE 'Downloads\LOLRMM-ESET-Owner-Test-Kit'),
    [string]$RuleName = 'LOLRMM POC TEST - LolrmmEsetTest'
)
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyy-MM-dd'
# Real (non-elevated) profile owner, in case the elevation account differs
$realUser = (Get-CimInstance Win32_ComputerSystem).UserName
$realProfile = $env:USERPROFILE
$runDir = Join-Path $env:LOCALAPPDATA "LOLRMM-POC\$stamp"
$evDir  = Join-Path $realProfile "LOLRMM-Evidence\$stamp"
$exe    = Join-Path $runDir 'LolrmmEsetTest.exe'
$results = [ordered]@{}
function Say($m, $c = 'Cyan') { Write-Host $m -ForegroundColor $c }
function Stop-Poc($m) { Say "STOP: $m" Red; if ($results.Count) { Save-Results }; Read-Host 'Press Enter to close'; exit 1 }
function Ask($q) { (Read-Host "$q").Trim() }
function Save-Results {
    $lines = @('OWNER RESULTS - no passwords/full configuration exports (auto-filled by Invoke-EsetHipsPoc)', '')
    foreach ($k in $results.Keys) { $lines += "${k}: $($results[$k])" }
    $lines += '', 'Manual observation is NOT the completed programmatic Phase 1 gate.', 'Keep all full XML exports, passwords and raw logs local and private.'
    $lines | Set-Content (Join-Path $evDir 'RESULTS.txt') -Encoding ASCII
    Say "Results written: $(Join-Path $evDir 'RESULTS.txt')" Green
}

# --- 0. Admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')
if (-not $isAdmin) { Stop-Poc 'Must run elevated (use Run-EsetHipsPoc.bat).' }

# --- 1. Verify kit hashes
Say '[1/8] Verifying kit hashes'
if (-not (Test-Path $KitDir)) { Stop-Poc "Kit folder not found: $KitDir" }
foreach ($line in Get-Content (Join-Path $KitDir 'SHA256SUMS.txt')) {
    if (-not $line.Trim()) { continue }
    $h, $f = $line -split '\s+', 2
    $a = (Get-FileHash (Join-Path $KitDir $f.Trim()) -Algorithm SHA256).Hash.ToLower()
    if ($a -ne $h) { Stop-Poc "Hash mismatch: $f" }
}
Say '  all hashes OK' Green

# --- 2. Folders (private ACL) + copy exact exe
Say '[2/8] Creating private folders and copying the exact executable'
New-Item -ItemType Directory -Force $runDir, $evDir | Out-Null
foreach ($f in $runDir, $evDir) {
    icacls $f /inheritance:r /grant:r "${env:USERNAME}:(OI)(CI)F" 'Administrators:(OI)(CI)F' | Out-Null
}
Copy-Item (Join-Path $KitDir 'LolrmmEsetTest.exe') $exe -Force
Say "  exe target for the rule: $exe" Green
Say "  evidence folder: $evDir" Green

# --- 3. Environment capture
Say '[3/8] Capturing environment'
$esetDir = 'C:\Program Files\ESET\ESET Security'
$ecmd = Join-Path $esetDir 'ecmd.exe'
if (-not (Test-Path $ecmd)) {
    $found = Get-ChildItem 'C:\Program Files\ESET' -Recurse -Filter ecmd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $found) { Stop-Poc 'ecmd.exe not found under C:\Program Files\ESET' }
    $ecmd = $found.FullName
}
$vi = (Get-Item $ecmd).VersionInfo
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$results['Date/time/timezone'] = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz') $((Get-TimeZone).Id)"
$results['Exact ESET consumer product'] = $vi.ProductName
$results['Exact ESET version/build'] = $vi.ProductVersion
$results['Windows edition/version/build'] = "$($cv.ProductName) $($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR)"
$results['ecmd.exe path/version'] = "$($ecmd -replace [regex]::Escape($env:USERNAME), '<USER>') / $($vi.FileVersion)"
$results['CI run'] = '37634726506'
if ($vi.ProductName -notmatch 'Ultimate') {
    Say "  NOTE: installed product is '$($vi.ProductName)', guide target is 'ESET Security Ultimate 19.2.x' (compatibility candidate)." Yellow
    $results['Failures/uncertainties'] = "Product is '$($vi.ProductName)', not Ultimate. "
}
$hips = Ask '  Is HIPS enabled in ESET (Advanced setup > Protections > HIPS)? (y/n)'
if ($hips -ne 'y') { $results['HIPS enabled'] = 'no'; Stop-Poc 'HIPS missing/disabled - guide says stop. Do not change it.' }
$results['HIPS enabled'] = 'yes'
$results['ESET CMD enabled and authorization MODE (no password)'] = Ask '  ESET CMD enabled? authorization mode shown (no password!)'

# --- helpers
function Export-Cfg($name) {
    $out = Join-Path $evDir $name
    $log = Join-Path $evDir "$name.export.log"
    & $ecmd /getcfg $out *> $log
    $code = $LASTEXITCODE
    if ($code -ne 0 -or -not (Test-Path $out)) {
        $err = (Get-Content $log -Raw -ErrorAction SilentlyContinue)
        return @{ ok = $false; text = "exit $code : $err".Trim() }
    }
    return @{ ok = $true; text = "ok ($name)" }
}
# Launch exe as the NORMAL (limited) user via a one-shot scheduled task, capture stdout+exit code.
function Run-AsNormalUser($tag) {
    $outFile = Join-Path $evDir "run-$tag.txt"
    Remove-Item $outFile -ErrorAction SilentlyContinue
    $inner = "`"$exe`" > `"$outFile`" 2>&1 & echo EXITCODE=%errorlevel%>> `"$outFile`""
    $act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $inner"
    $prin = New-ScheduledTaskPrincipal -UserId $realUser -LogonType Interactive -RunLevel Limited
    $tn = "LOLRMM-POC-$tag"
    Register-ScheduledTask -TaskName $tn -Action $act -Principal $prin -Force | Out-Null
    Start-ScheduledTask $tn
    $t = 0; while ((Get-ScheduledTask $tn).State -eq 'Running' -and $t -lt 30) { Start-Sleep 1; $t++ }
    Start-Sleep 2
    Unregister-ScheduledTask $tn -Confirm:$false
    if (Test-Path $outFile) { return (Get-Content $outFile -Raw) } else { return '(no output file - launch may have been blocked)' }
}
function Sanitize($s) { $s -replace [regex]::Escape($env:USERNAME), '<USER>' -replace [regex]::Escape($realProfile), 'C:\Users\<USER>' }

# --- 4. Baseline
Say '[4/8] Exporting baseline'
$b = Export-Cfg 'baseline.xml'
$results['Baseline export succeeded / exact error'] = $b.text
if (-not $b.ok) { Stop-Poc "Baseline export failed: $($b.text)" }

# --- 5. Pre-rule control launch (proves the exe runs before the rule exists)
Say '[5/8] Control launch before any rule (normal user)'
$pre = Run-AsNormalUser 'pre-rule'
Say "  output: $($pre.Trim())"

# --- 6. Manual rule + export + block test
Say '[6/8] MANUAL STEP - create exactly ONE rule in the ESET UI' Yellow
Write-Host @"

  ESET > Advanced setup > Protections > HIPS > Rules > Add
    Name:               $RuleName
    Action:             Block (enabled)
    Operation:          Start new application
    Source apps:        All applications
    Target:             Specific applications -> $exe   (exact file, no folder/wildcard)
    Logging severity + user notification: ON  (note the exact logging choice)
  Save it. Do not change anything else.
"@
$null = Read-Host 'Press Enter AFTER saving the rule'
$results['Manual rule fields used'] = Ask '  Logging choice shown in UI (exact text)'
$m = Export-Cfg 'with-manual-rule.xml'
$results['Manual-rule export succeeded / exact error'] = $m.text
if (-not $m.ok) { Stop-Poc "Rule export failed: $($m.text)" }

# Auto-verify exactly one new rule, via XML diff
$base = Get-Content (Join-Path $evDir 'baseline.xml')
$with = Get-Content (Join-Path $evDir 'with-manual-rule.xml')
$diff = Compare-Object $base $with
$added = @($diff | ? SideIndicator -eq '=>'); $removed = @($diff | ? SideIndicator -eq '<=')
Say "  XML diff vs baseline: +$($added.Count) / -$($removed.Count) lines"
$clean = $with | ? { $_ -match 'LolrmmEsetTest|' + [regex]::Escape($RuleName) }
if (-not $added.Count) { Say '  WARNING: no change detected in export - rule may not be saved/exported.' Yellow }
$sanFile = Join-Path $evDir 'sanitized-rule-diff.txt'
(@('--- added lines (baseline -> with-manual-rule), sanitized ---') + ($added | % { Sanitize $_.InputObject }) +
 '--- removed lines ---' + ($removed | % { Sanitize $_.InputObject })) | Set-Content $sanFile -Encoding ASCII
Say "  sanitized diff: $sanFile (review before sharing; still contains only changed lines)" Green

Say 'Launching test exe once as normal user'
$blk = Run-AsNormalUser 'with-rule'
Say "  output: $($blk.Trim())"
$ran = $blk -match 'Test Application'
Say "  ESET notification/popup visible just now?" Yellow
$results['Notification observed'] = Ask '  Notification observed (describe / none)'
$results['Exact executable blocked (yes/no/unclear)'] = if ($ran) { 'NO - it ran and printed Test Application' } elseif ($blk -match 'EXITCODE=0') { 'unclear' } else { 'yes (no program output)' }
Say 'MANUAL: ESET > Tools > Log files > HIPS - find the entry at the test time.' Yellow
$results['Matching HIPS log result'] = Ask '  HIPS log result (app / result / rule name, or "absent")'
if ($ran -or $results['Matching HIPS log result'] -match 'absent') {
    $results['Failures/uncertainties'] += 'Exe ran or HIPS entry absent - per guide, STOP; no rule changes. '
    Say 'Guide: stop on unexpected outcome. You may still remove the test rule below (guide section 5).' Yellow
}

# --- 7. Removal
Say '[7/8] MANUAL STEP - remove ONLY the test rule' Yellow
Write-Host "  HIPS > Rules: confirm name '$RuleName' + exact exe target, remove that one rule. Touch nothing else."
$null = Read-Host 'Press Enter AFTER removing it'
$r = Export-Cfg 'after-removal.xml'
$results['Post-removal export succeeded / exact error'] = $r.text
if (-not $r.ok) { Stop-Poc "Post-removal export failed: $($r.text)" }

# --- 8. Verify
Say '[8/8] Verifying removal + that settings are unchanged'
$after = Get-Content (Join-Path $evDir 'after-removal.xml')
$d2 = Compare-Object $base $after
if (-not $d2) { $results['Other settings/rules unchanged (observed/not verified)'] = 'observed: after-removal.xml identical to baseline.xml'; $results['Only test rule removed'] = 'yes (export identical to baseline)' }
else {
    $results['Other settings/rules unchanged (observed/not verified)'] = "after-removal differs from baseline by $(@($d2).Count) line(s) - see diff-baseline-vs-after.txt (may be timestamps/counters)"
    (@($d2) | % { "$($_.SideIndicator) $(Sanitize $_.InputObject)" }) | Set-Content (Join-Path $evDir 'diff-baseline-vs-after.txt') -Encoding ASCII
    $results['Only test rule removed'] = Ask '  Confirm in UI that only the test rule is gone and it is absent (yes/no)'
}
if (Select-String -Path (Join-Path $evDir 'after-removal.xml') -Pattern 'LolrmmEsetTest' -Quiet) { Say '  WARNING: exe name still present in after-removal.xml' Yellow; $results['Failures/uncertainties'] += 'LolrmmEsetTest still present in after-removal.xml. ' }
$post = Run-AsNormalUser 'post-removal'
$okRun = ($post -match 'Test Application') -and ($post -match 'EXITCODE=0')
$results['Executable prints Test Application after removal'] = if ($okRun) { 'yes, exit code 0' } else { "NO: $($post.Trim())" }
$results['Sanitized minimal test-rule diff available'] = "yes: $sanFile"
if (-not $results.Contains('Failures/uncertainties')) { $results['Failures/uncertainties'] = 'none recorded' }
Save-Results
Say "`nDone. Share ONLY RESULTS.txt + sanitized-rule-diff.txt. Keep all *.xml and logs private in $evDir" Green
Read-Host 'Press Enter to close'
