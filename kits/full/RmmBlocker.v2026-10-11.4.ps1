<#
.SYNOPSIS
  One-window front end: BLOCK (do) / UNDO remote-access scam tools on this PC. Launched by START-HERE.bat (elevated).

.DESCRIPTION
  BLOCK  1. Windows App Control: installs policy\RmmBlock-Enforce.cip (builds it first if missing and this PC can)
            -> AnyDesk, TeamViewer, ScreenConnect ... can't start, even renamed / from email / Downloads / USB.
         2. Builds the ESET website block list, copies it to the clipboard, opens ESET + the paste guide
            (the paste into ESET is the only manual step).
  UNDO   Removes the App Control policy (restart to finish) and opens ESET + the guide's UNDO section
         for taking the website list back out.
  TEST   Installs the policy in audit mode (logs only, blocks nothing).
  Checkboxes: TeamViewer / AnyDesk / Splashtop / RustDesk can each be blocked or allowed (default: block TeamViewer,
  AnyDesk + RustDesk, allow Splashtop) - in App Control AND in the ESET website list. Ticked on open = what is installed now. Change them, then press BLOCK (or Test mode) to apply.
  Every action is logged in the window and in %ProgramData%\RemoteAccessToolBlocker\RmmAppControl.log (via Install-RmmAppControl).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-11.3'
$PolicyGuid = '{2D13BFB7-4304-4847-9CDD-37820D3EE9B7}'   # must match Build-/Install-RmmAppControl
$bare = $PolicyGuid.Trim('{}').ToLowerInvariant()
$Here = $PSScriptRoot
# Where the generated ESET import file goes. Resolved defensively: this line runs BEFORE the
# window is built, so an unguarded Join-Path here kills the whole script (no window at all)
# on any host where USERPROFILE is unset.
if ($env:USERPROFILE) {
    $UrlOut = Join-Path $env:USERPROFILE 'LOLRMM-UrlList\latest'
} else {
    $UrlOut = Join-Path $Here 'LOLRMM-UrlList\latest'
}
# The file the ESET import step needs. Shown to the operator so the list can always be found
# even when the clipboard does not cooperate.
$UrlListFile = Join-Path $UrlOut 'eset-blocked-urls.txt'

# ------------------------------------------------------------------ parts
# Repo layout (see README "Repository layout"):
#   kits/full/         this window + START-HERE.bat
#   kits/windows-only/ the same window without the ESET steps
#   src/appcontrol/    Build- / Install- / Run-RmmAppControl   (ONE shared copy)
#   src/eset/          Get-LolrmmUrlList / Get-LolrmmHipsList
#   policy/            the prebuilt .cip / .xml policies (shared, at the repo root)
# Running the kit from a built release ZIP (scripts copied side by side) falls back to
# the local folder, so an extracted kit still works standalone.
# $PSScriptRoot inside a FUNCTION resolves to the caller's script root, not this file's.
# Capture it once at script scope and hand it to the function so the lookup cannot drift.
$ScriptRootHere = $PSScriptRoot
function Resolve-Parts {
    param([string]$Here = $ScriptRootHere)
    $out = @{
        AppControl = $here
        Eset       = $here
        Policy     = (Join-Path $here 'policy')
        Standalone = $true
    }
    $root = Split-Path (Split-Path $here -Parent) -Parent
    $srcAc = Join-Path $root 'src\appcontrol'
    $srcEset = Join-Path $root 'src\eset'
    $pol = Join-Path $root 'policy'
    if (Test-Path -LiteralPath $srcAc) { $out.AppControl = $srcAc; $out.Standalone = $false }
    if (Test-Path -LiteralPath $srcEset) { $out.Eset = $srcEset }
    if (Test-Path -LiteralPath $pol) { $out.Policy = $pol }
    return $out
}
$Parts = Resolve-Parts

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

function Find-Newest([string]$pattern, [string]$dir) {
    if (-not $dir) { $dir = $Here }
    Get-ChildItem -LiteralPath $dir -Filter $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------------------------------------------------------------- window
$form = New-Object Windows.Forms.Form
$form.Text = "Block remote-access scam tools  (v$ScriptVersion)"
$form.Size = New-Object Drawing.Size(640, 610)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.MinimumSize = $form.Size

$title = New-Object Windows.Forms.Label
$title.Text = 'Stops AnyDesk, TeamViewer, ScreenConnect and ~50 other remote-access tools that scammers use.'
$title.Location = New-Object Drawing.Point(16, 8); $title.Size = New-Object Drawing.Size(600, 36)
$form.Controls.Add($title)

$status = New-Object Windows.Forms.Label
$status.Location = New-Object Drawing.Point(16, 44); $status.Size = New-Object Drawing.Size(600, 40)
$status.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
$form.Controls.Add($status)

function New-Btn([string]$text, [int]$x, [int]$w, [string]$color) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object Drawing.Point($x, 142); $b.Size = New-Object Drawing.Size($w, 64)
    $b.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
    $b.BackColor = [Drawing.Color]::FromName($color); $b.FlatStyle = 'Flat'
    $form.Controls.Add($b); return $b
}
$grp = New-Object Windows.Forms.GroupBox
$grp.Text = 'Also block these (untick = allowed on this PC):'
$grp.Location = New-Object Drawing.Point(16, 84); $grp.Size = New-Object Drawing.Size(592, 52)
$form.Controls.Add($grp)
function New-Chk([string]$text, [int]$x, [bool]$on) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $text; $c.Checked = $on; $c.Location = New-Object Drawing.Point($x, 20); $c.AutoSize = $true
    $grp.Controls.Add($c); return $c
}
$chkT = New-Chk 'TeamViewer' 12 $true
$chkA = New-Chk 'AnyDesk' 170 $true
$chkS = New-Chk 'Splashtop' 310 $false
$chkR = New-Chk 'RustDesk' 450 $true
$chkS.Add_Click({
    if ($chkS.Checked) {
        $r = [Windows.Forms.MessageBox]::Show(
            "Blocking Splashtop stops Splashtop from starting on THIS PC - including the Splashtop we use for support.`r`n`r`nIf you are connected through Splashtop right now you will lose this PC after it restarts.`r`n`r`nBlock Splashtop anyway?",
            'Block Splashtop?', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $chkS.Checked = $false }
    }
})
function Get-Variant { 'T{0}A{1}S{2}R{3}' -f [int]$chkT.Checked, [int]$chkA.Checked, [int]$chkS.Checked, [int]$chkR.Checked }
function Describe-Variant([string]$v) {
    # older 3-letter codes (no R) = RustDesk not blocked
    $n = [ordered]@{ T = 'TeamViewer'; A = 'AnyDesk'; S = 'Splashtop'; R = 'RustDesk' }; $i = 0; $parts = @()
    foreach ($k in $n.Keys) { $parts += '{0} {1}' -f $n[$k], $(if ($v.Length -gt $i * 2 + 1 -and $v[$i * 2 + 1] -eq [char]'1') { 'blocked' } else { 'allowed' }); $i++ }
    $parts -join ', '
}

$btnDo = New-Btn 'BLOCK (do)' 16 230 'PaleGreen'
$btnUndo = New-Btn 'UNDO' 256 170 'MistyRose'
$btnTest = New-Btn 'Test mode' 436 172 'LightYellow'
$btnTest.Font = New-Object Drawing.Font('Segoe UI', 10)

$log = New-Object Windows.Forms.TextBox
$log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true; $log.WordWrap = $true
$log.Location = New-Object Drawing.Point(16, 218); $log.Size = New-Object Drawing.Size(592, 300)
$log.Anchor = 'Top, Bottom, Left, Right'
$log.Font = New-Object Drawing.Font('Consolas', 9)
$form.Controls.Add($log)

$btnLog = New-Object Windows.Forms.Button
$btnLog.Text = 'Refresh status / show recent blocks'; $btnLog.Location = New-Object Drawing.Point(16, 528)
$btnLog.Size = New-Object Drawing.Size(280, 30); $btnLog.Anchor = 'Bottom, Left'
$form.Controls.Add($btnLog)

# Reopen the folder holding eset-blocked-urls.txt at any time, without rebuilding it.
# Deliberately not in Busy()'s disable list: opening a folder is harmless during work.
$btnFolder = New-Object Windows.Forms.Button
$btnFolder.Text = 'Open the ESET list folder'; $btnFolder.Location = New-Object Drawing.Point(306, 528)
$btnFolder.Size = New-Object Drawing.Size(280, 30); $btnFolder.Anchor = 'Bottom, Left'
$form.Controls.Add($btnFolder)

function Say([string]$m, [string]$color = '') {
    # colour is optional: 'Red'/'Yellow'/'Green' for the lines an operator must not miss.
    # The on-screen box is this window's output surface, so every line lands there too.
    $log.AppendText($m + "`r`n")
    if ($color) {
        $n = $log.TextLength
        $log.SelectionStart = $n - $m.Length - 2
        $log.SelectionLength = $m.Length
        $log.SelectionColor = [Drawing.Color]::FromName($color)
        $log.SelectionStart = $n
        $log.SelectionLength = 0
    }
    [Windows.Forms.Application]::DoEvents()
}
function Run-Script([string]$path, [string[]]$scriptArgs) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @scriptArgs 2>&1
    $rc = $LASTEXITCODE
    foreach ($l in $out) { Say ('  ' + [string]$l) }
    return $rc
}
function Busy([bool]$on) {
    foreach ($b in $btnDo, $btnUndo, $btnTest, $btnLog) { $b.Enabled = -not $on }
    $form.Cursor = $(if ($on) { 'WaitCursor' } else { 'Default' }); [Windows.Forms.Application]::DoEvents()
}

function Get-PolicyState {
    $ci = Join-Path $env:windir 'System32\CiTool.exe'
    if (Test-Path -LiteralPath $ci) {
        try {
            $j = (& $ci --list-policies -json 2>$null | Out-String) | ConvertFrom-Json
            if ($j.OperationResult -and $j.OperationResult -ne 0) { return 'unknown' }
            $p = @($j.Policies) | Where-Object { ([string]$_.PolicyID).Trim('{}').ToLowerInvariant() -eq $bare } | Select-Object -First 1
            if (-not $p) { return 'off' }
            if ([string]$p.FriendlyName -match '\[(T[01]A[01]S[01](R[01])?)\]') { $script:InstalledVariant = $Matches[1] } else { $script:InstalledVariant = 'T1A1S0' }
            if ([string]$p.FriendlyName -match 'Audit') { return 'test' } else { return 'on' }
        } catch { return 'unknown' }
    }
    if (Test-Path -LiteralPath (Join-Path $env:windir "System32\CodeIntegrity\CiPolicies\Active\$PolicyGuid.cip")) { return 'on-restart' }
    return 'off'
}
$script:InstalledVariant = ''
function Update-Status {
    $script:InstalledVariant = ''
    $state = Get-PolicyState
    switch ($state) {
        'on' { $status.Text = 'Status: PROTECTED - remote-access programs are blocked'; $status.ForeColor = [Drawing.Color]::DarkGreen }
        'test' { $status.Text = 'Status: TEST MODE - logging only, nothing is blocked'; $status.ForeColor = [Drawing.Color]::DarkGoldenrod }
        'on-restart' { $status.Text = 'Status: installed - restart the PC to activate'; $status.ForeColor = [Drawing.Color]::DarkGoldenrod }
        'off' { $status.Text = 'Status: NOT protected - press BLOCK'; $status.ForeColor = [Drawing.Color]::DarkRed }
        default { $status.Text = 'Status: unknown (needs administrator rights)'; $status.ForeColor = [Drawing.Color]::Gray }
    }
    if ($script:InstalledVariant -and $state -in 'on', 'test') { $status.Text += "`r`n" + (Describe-Variant $script:InstalledVariant) }
}

function Ensure-Policy([string]$mode, [string]$variant) {
    $cip = Join-Path $Parts.Policy "variants\RmmBlock-$mode-$variant.cip"
    if (Test-Path -LiteralPath $cip) { return $true }
    $build = Find-Newest 'Build-RmmAppControl.v*.ps1' $Parts.AppControl
    if (-not $build -or -not (Get-Command ConvertFrom-CIPolicy -ErrorAction SilentlyContinue)) {
        Say 'The block policy is not in the policy folder and this PC cannot build it (needs Windows Pro).'
        Say 'Build it on a Pro PC (Build-RmmAppControl -IncludeOptional) and copy the policy folder next to START-HERE.'
        return $false
    }
    Say 'Building the block policy from lolrmm.io (first time only, ~1 minute) ...'
    [void](Run-Script $build @())
    return (Test-Path -LiteralPath $cip)
}
function Install-Policy([string]$mode) {
    $inst = Find-Newest 'Install-RmmAppControl.v*.ps1' $Parts.AppControl
    if (-not $inst) { Say 'Install-RmmAppControl.v*.ps1 is missing from this folder.'; return $false }
    $v = Get-Variant
    Say "  Toggles: $(Describe-Variant $v)"
    if (-not (Ensure-Policy $mode $v)) { return $false }
    return ((Run-Script $inst @('-Mode', $mode, '-Variant', $v)) -eq 0)
}
function Open-ListFolder([bool]$selectFile = $false) {
    # Put the list in front of the operator rather than naming a path they must navigate to.
    # /select highlights the file itself, so it is one click from ESET's Import dialog.
    try {
        if ($selectFile -and (Test-Path -LiteralPath $UrlListFile)) {
            Start-Process explorer.exe -ArgumentList ('/select,"' + $UrlListFile + '"')
        } elseif (Test-Path -LiteralPath $UrlOut) {
            Start-Process explorer.exe -ArgumentList ('"' + $UrlOut + '"')
        } else {
            Say ('  (the folder does not exist yet: ' + $UrlOut + ')') 'Yellow'
        }
    } catch {
        Say ('  could not open the folder automatically. It is: ' + $UrlOut) 'Yellow'
    }
}

function Open-EsetAndGuide {
    $egui = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'ESET') -Filter egui.exe -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($egui) { Start-Process -FilePath $egui.FullName } else { Say '  ESET not found - open it from the Start menu.' }
    $guide = Find-Newest 'HOW-TO-IMPORT.txt' $Parts.Eset
    if (Test-Path -LiteralPath $guide) { Start-Process notepad.exe -ArgumentList "`"$guide`"" }
}

# ---------------------------------------------------------------- actions
$btnDo.Add_Click({
    Busy $true; $log.Clear()
    try {
        Say '=== BLOCK ==='
        Say '[1/2] Blocking the programs (Windows App Control) ...'
        $ok = Install-Policy 'Enforce'
        Say $(if ($ok) { '  -> programs blocked.' } else { '  -> FAILED - see the lines above.' })

        Say '[2/2] Building the ESET website block list ...'
        $urlScript = Find-Newest 'Get-LolrmmUrlList.v*.ps1' $Parts.Eset
        # the same ticks decide the website list: unticked tools are left out of it, ticked Splashtop goes in
        $exTools = @('mstsc', 'NVDA'); $allow = @('eset.com')
        if (-not $chkS.Checked) { $exTools += 'Splashtop'; $allow += 'splashtop.com', 'splashtop.eu' }
        if (-not $chkT.Checked) { $exTools += 'TeamViewer'; $allow += 'teamviewer.com' }
        if (-not $chkA.Checked) { $exTools += 'AnyDesk'; $allow += 'anydesk.com' }
        if (-not $chkR.Checked) { $exTools += 'RustDesk'; $allow += 'rustdesk.com' }
        Say "  Website list leaves out: $(($exTools | Where-Object { $_ -notin 'mstsc', 'NVDA' }) -join ', ')$(if (-not ($exTools | Where-Object { $_ -notin 'mstsc', 'NVDA' })) { '(nothing)' })"
        if (-not $urlScript) {
            Say '  -> the URL list generator was not found next to this window.' 'Red'
            Say ('     Looked in: ' + $Parts.Eset) 'Yellow'
        } elseif ((Run-Script $urlScript @('-OutDir', $UrlOut, '-ExcludeTool', ($exTools -join ','), '-AllowDomain', ($allow -join ','))) -ne 0) {
            Say '  -> the URL list generator failed - see its output above.' 'Red'
        } elseif (-not (Test-Path -LiteralPath $UrlListFile)) {
            Say ('  -> the generator ran but produced no file at ' + $UrlListFile) 'Red'
        } else {
            $lines = @(Get-Content -LiteralPath $UrlListFile)
            # ALWAYS tell the operator where the file is. The clipboard can silently fail
            # (elevated/hidden windows can own a different clipboard), and without this the
            # list is written to a path nobody was ever told about.
            Say ''
            Say ('  IMPORT FILE: ' + $UrlListFile) 'White'
            Say ('  (' + $lines.Count + ' entries)') 'White'

            $clipOk = $false
            try {
                Set-Clipboard -Value $lines -ErrorAction Stop
                # read it back: Set-Clipboard returns nothing, so verify rather than assume
                $back = @(Get-Clipboard -ErrorAction Stop)
                $clipOk = ($back.Count -ge $lines.Count -and $back[0] -eq $lines[0])
            } catch { $clipOk = $false }

            if ($clipOk) {
                Say '  -> list copied to the clipboard (verified) and opening ESET ...' 'Green'
            } else {
                Say '  -> could NOT copy to the clipboard, so use the file instead:' 'Red'
                Say '     in ESET choose Import and pick eset-blocked-urls.txt.' 'Yellow'
            }
            Say '  Tip: paste it into a NEW list named "RMM scam block (lolrmm)" so UNDO is one click.'
            # show them the file: the folder opens with the list selected
            Open-ListFolder $true
            Open-EsetAndGuide
            Say ''
            Say 'LAST STEP (by hand): in ESET press F5 and follow the guide in Notepad -'
            if ($clipOk) {
                Say 'click "Enter multiple values" and press Ctrl+V, then OK -> OK.'
            } else {
                Say ('click Import and choose: ' + $UrlListFile)
            }
            Say ('  [log] ESET import file: ' + $UrlListFile + ' (' + $lines.Count + ' entries, clipboard=' + $clipOk + ')')
        }
    } catch { Say "ERROR: $($_.Exception.Message)" }
    Update-Status; Busy $false
})

$btnUndo.Add_Click({
    $r = [Windows.Forms.MessageBox]::Show('Remove the block from this PC?', 'Undo', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    Busy $true; $log.Clear()
    try {
        Say '=== UNDO ==='
        Say '[1/2] Removing the program block (Windows App Control) ...'
        $inst = Find-Newest 'Install-RmmAppControl.v*.ps1' $Parts.AppControl
        if ($inst) { [void](Run-Script $inst @('-Mode', 'Remove')) } else { Say '  Install-RmmAppControl.v*.ps1 missing.' }
        Say '[2/2] Website block: remove it in ESET by hand (opening ESET + the guide, see the UNDO section):'
        Say '  F5 > Protections > Web access protection > URL list management > Address list > Edit >'
        Say '  select "RMM scam block (lolrmm)" > Remove > OK > OK.   (One click.)'
        Say '  If it was pasted into the built-in "List of blocked addresses" instead: Edit it,'
        Say '  click the first entry, Shift+click the last, Remove > OK > OK.'
        Open-EsetAndGuide
        Say ''
        Say 'RESTART the PC to finish removing the program block.'
    } catch { Say "ERROR: $($_.Exception.Message)" }
    Update-Status; Busy $false
})

$btnTest.Add_Click({
    Busy $true; $log.Clear()
    try {
        Say '=== TEST MODE (logs only, blocks nothing) ==='
        $ok = Install-Policy 'Audit'
        if ($ok) { Say ''; Say 'Now start AnyDesk/TeamViewer, then click "Refresh status" - it should list "[3076]" for it.' }
    } catch { Say "ERROR: $($_.Exception.Message)" }
    Update-Status; Busy $false
})

$btnFolder.Add_Click({
    Say '=== Open the ESET list folder ==='
    if (Test-Path -LiteralPath $UrlListFile) {
        $n = @(Get-Content -LiteralPath $UrlListFile).Count
        Say ('  ' + $UrlListFile)
        Say ('  ' + $n + ' entries, ready to import into ESET.')
        Open-ListFolder $true
    } else {
        Say ('  no list built yet. It will be written to ' + $UrlListFile) 'Yellow'
        Say '  press BLOCK first, then use this button to open the folder.'
        Open-ListFolder $false
    }
})
$btnLog.Add_Click({
    Busy $true; $log.Clear()
    $inst = Find-Newest 'Install-RmmAppControl.v*.ps1' $Parts.AppControl
    if ($inst) { [void](Run-Script $inst @('-Mode', 'Status')) }
    Say ''; Say '[3077] = blocked   [3076] = would be blocked (test mode)'
    Update-Status; Busy $false
})

# ---------------------------------------------------------------- start
if (-not $isAdmin) { Say 'Not running as administrator - BLOCK / UNDO will fail. Start this from START-HERE.bat.' }
Say 'BLOCK  = block the programs + build the ESET website list (one paste in ESET at the end).'
Say 'UNDO   = remove the program block (restart after) + shows how to remove the website list from ESET.'
Say 'Test mode = log only, nothing blocked - for trying it out first.'
Say 'Ticks = TeamViewer / AnyDesk / Splashtop / RustDesk blocked or allowed. Change them, then press BLOCK to apply.'
Update-Status
if ($script:InstalledVariant) {
    $chkT.Checked = ($script:InstalledVariant[1] -eq [char]'1')
    $chkA.Checked = ($script:InstalledVariant[3] -eq [char]'1')
    $chkS.Checked = ($script:InstalledVariant[5] -eq [char]'1')     # set directly: no warning pop-up on open
    $chkR.Checked = ($script:InstalledVariant.Length -gt 7 -and $script:InstalledVariant[7] -eq [char]'1')
}
[void]$form.ShowDialog()
