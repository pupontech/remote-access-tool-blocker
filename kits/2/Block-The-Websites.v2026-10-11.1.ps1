<#
.SYNOPSIS
  Program 2 - block the remote-access tools' WEBSITES in ESET. Launched by Block-The-Websites.bat.
  Builds the ESET "List of blocked addresses" import file, copies it to the clipboard, opens ESET and the guide.

.DESCRIPTION
  This is the WEBSITE half of the kit. It only builds a list and shows it to you: the paste into ESET is a manual
  step and this program cannot do it or verify it.

  BUILD   Downloads the LOLRMM catalogue, writes eset-blocked-urls.txt (~406 masks), copies it to the clipboard
          (and verifies the copy), opens the folder with the file selected, then opens ESET + HOW-TO-IMPORT.txt.
  OPEN    Reopens the folder holding the list, without rebuilding it - for when you need the file again.
  Checkboxes: TeamViewer / AnyDesk / Splashtop / RustDesk - an UNTICKED tool is left out of the website list, so a
  tool your client legitimately uses is not blocked on the web.

  Requires ESET to be installed. Does NOT need administrator rights (it only writes a file and opens a window).
  It does not touch the programs themselves - that is the other program in this kit, folder "1".
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-11.1'
$Here = $PSScriptRoot

# Where the generated ESET import file goes. Resolved defensively: an unguarded Join-Path here would kill the
# whole script (no window at all) on any host where USERPROFILE is unset.
if ($env:USERPROFILE) {
    $UrlOut = Join-Path $env:USERPROFILE 'LOLRMM-UrlList\latest'
} else {
    $UrlOut = Join-Path $Here 'LOLRMM-UrlList\latest'
}
# The file the ESET import step needs. Shown to the operator so the list can always be found even when the
# clipboard does not cooperate.
$UrlListFile = Join-Path $UrlOut 'eset-blocked-urls.txt'

# ------------------------------------------------------------------ parts
# Repo layout: this file is kits/2/, so the repo root is two levels up. A built release ZIP copies the scripts
# side by side, so the folder beside this file is the fallback.
# $PSScriptRoot inside a FUNCTION resolves to the caller's script root, not this file's, so capture it once.
$ScriptRootHere = $PSScriptRoot
function Resolve-Parts {
    param([string]$Here = $ScriptRootHere)
    $out = @{ Eset = $here; Standalone = $true }
    $root = Split-Path (Split-Path $here -Parent) -Parent
    $srcEset = Join-Path $root 'src\eset'
    if (Test-Path -LiteralPath $srcEset) { $out.Eset = $srcEset; $out.Standalone = $false }
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

# ---------------------------------------------------------------- window
$form = New-Object Windows.Forms.Form
$form.Text = "2 - Block the remote-access WEBSITES in ESET  (v$ScriptVersion)"
$form.Size = New-Object Drawing.Size(640, 610)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.MinimumSize = $form.Size

$title = New-Object Windows.Forms.Label
$title.Text = 'Blocks the download pages and web consoles of the remote-access tools scammers use, in ESET. Needs ESET.'
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
$grp.Text = 'Leave these OUT of the website list (untick = allowed on this PC):'
$grp.Location = New-Object Drawing.Point(16, 84); $grp.Size = New-Object Drawing.Size(592, 52)
$form.Controls.Add($grp)
function New-Chk([string]$text, [int]$x, [bool]$on) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $text; $c.Checked = $on; $c.Location = New-Object Drawing.Point($x, 20); $c.AutoSize = $true
    $grp.Controls.Add($c); return $c
}
# same defaults as program 1: block the tool = block its website; Splashtop is allowed.
$chkT = New-Chk 'TeamViewer' 12 $true
$chkA = New-Chk 'AnyDesk' 170 $true
$chkS = New-Chk 'Splashtop' 310 $false
$chkR = New-Chk 'RustDesk' 450 $true

$btnDo = New-Btn 'BUILD the list' 16 300 'PaleGreen'
$btnFolder = New-Btn 'Open the list folder' 326 282 'LightSteelBlue'
$btnFolder.Font = New-Object Drawing.Font('Segoe UI', 10)

$log = New-Object Windows.Forms.TextBox
$log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true; $log.WordWrap = $true
$log.Location = New-Object Drawing.Point(16, 218); $log.Size = New-Object Drawing.Size(592, 340)
$log.Anchor = 'Top, Bottom, Left, Right'
$log.Font = New-Object Drawing.Font('Consolas', 9)
$form.Controls.Add($log)

function Say([string]$m, [string]$color = '') {
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
    foreach ($b in $btnDo, $btnFolder) { $b.Enabled = -not $on }
    $form.Cursor = $(if ($on) { 'WaitCursor' } else { 'Default' }); [Windows.Forms.Application]::DoEvents()
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
    if (Test-Path -LiteralPath $guide) { Start-Process notepad.exe -ArgumentList "`"$guide`"" } else { Say '  (the guide HOW-TO-IMPORT.txt was not found next to this program.)' 'Yellow' }
}
function Update-Status {
    if (Test-Path -LiteralPath $UrlListFile) {
        $n = @(Get-Content -LiteralPath $UrlListFile).Count
        $status.Text = "Status: a list of $n entries is ready at $UrlOut`r`nPaste it into ESET by hand (press BUILD to rebuild)."
        $status.ForeColor = [Drawing.Color]::DarkGreen
    } else {
        $status.Text = 'Status: no list built yet - press BUILD.'
        $status.ForeColor = [Drawing.Color]::DarkRed
    }
}

# ---------------------------------------------------------------- actions
$btnDo.Add_Click({
    Busy $true; $log.Clear()
    try {
        Say '=== BUILD the ESET website list ==='
        $urlScript = Find-Newest 'Get-LolrmmUrlList.v*.ps1' $Parts.Eset
        # unticked tools are left out of the list entirely
        $exTools = @('mstsc', 'NVDA'); $allow = @('eset.com')
        if (-not $chkS.Checked) { $exTools += 'Splashtop'; $allow += 'splashtop.com', 'splashtop.eu' }
        if (-not $chkT.Checked) { $exTools += 'TeamViewer'; $allow += 'teamviewer.com' }
        if (-not $chkA.Checked) { $exTools += 'AnyDesk'; $allow += 'anydesk.com' }
        if (-not $chkR.Checked) { $exTools += 'RustDesk'; $allow += 'rustdesk.com' }
        Say "  Website list leaves out: $(($exTools | Where-Object { $_ -notin 'mstsc', 'NVDA' }) -join ', ')$(if (-not ($exTools | Where-Object { $_ -notin 'mstsc', 'NVDA' })) { '(nothing)' })"
        if (-not $urlScript) {
            Say '  -> the URL list generator was not found next to this program.' 'Red'
            Say ('     Looked in: ' + $Parts.Eset) 'Yellow'
        } elseif ((Run-Script $urlScript @('-OutDir', $UrlOut, '-ExcludeTool', ($exTools -join ','), '-AllowDomain', ($allow -join ','))) -ne 0) {
            Say '  -> the URL list generator failed - see its output above.' 'Red'
        } elseif (-not (Test-Path -LiteralPath $UrlListFile)) {
            Say ('  -> the generator ran but produced no file at ' + $UrlListFile) 'Red'
        } else {
            $lines = @(Get-Content -LiteralPath $UrlListFile)
            # ALWAYS tell the operator where the file is. The clipboard can silently fail (elevated/hidden
            # windows can own a different clipboard), and without this the list is written to a path nobody
            # was ever told about.
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

$btnFolder.Add_Click({
    Say '=== Open the ESET list folder ==='
    if (Test-Path -LiteralPath $UrlListFile) {
        $n = @(Get-Content -LiteralPath $UrlListFile).Count
        Say ('  ' + $UrlListFile)
        Say ('  ' + $n + ' entries, ready to import into ESET.')
        Open-ListFolder $true
    } else {
        Say ('  no list built yet. It will be written to ' + $UrlListFile) 'Yellow'
        Say '  press BUILD first, then use this button to open the folder.'
        Open-ListFolder $false
    }
})

# ---------------------------------------------------------------- start
Say 'BUILD = build the ESET website list and open ESET + the guide (the paste is a by-hand step).'
Say 'Unticked tools are left OUT of the list, so a tool your client uses is not blocked on the web.'
Say ''
Say 'Nothing here changes ESET by itself - you paste the list in by hand. See HOW-TO-IMPORT.txt.'
Update-Status
[void]$form.ShowDialog()