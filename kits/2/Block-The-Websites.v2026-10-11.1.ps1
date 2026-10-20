<#
.SYNOPSIS
  Program 2 - block the remote-access tools' WEBSITES in ESET. Launched by START-HERE.bat.
  Builds the ESET "List of blocked addresses" import file, copies its file path to the clipboard, opens ESET and the guide.

.DESCRIPTION
  This is the WEBSITE half of the kit. It only builds a list and shows it to you: the import into ESET is a manual
  step and this program cannot do it or verify it.

  BUILD   Downloads the LOLRMM catalogue, writes eset-blocked-urls.txt (one combined file), copies its file path to the clipboard
          (and verifies the path copy), opens the folder with the file selected, then opens ESET + HOW-TO-IMPORT.txt.
  OPEN    Reopens the folder holding the list, without rebuilding it - for when you need the file again.
  Checkboxes: TeamViewer / AnyDesk / Splashtop / RustDesk - an UNTICKED tool is left out of the website list, so a
  tool your client legitimately uses is not blocked on the web.

  Requires ESET to be installed. Does NOT need administrator rights (it only writes a file and opens a window).
  It does not touch the programs themselves - that is the other program in this kit, folder "1".
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026.10.20.2'
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
# Native WinForms, without browser runtimes, downloaded fonts or theme dependencies.
$ink = [Drawing.ColorTranslator]::FromHtml('#172B3A')
$muted = [Drawing.ColorTranslator]::FromHtml('#506174')
$accent = [Drawing.ColorTranslator]::FromHtml('#087F8C')
$canvas = [Drawing.ColorTranslator]::FromHtml('#F3F6F8')
$form = New-Object Windows.Forms.Form
$form.Text = "Website protection | ESET list builder - v$ScriptVersion"
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
$form.AutoScaleMode = 'Dpi'
$form.ClientSize = New-Object Drawing.Size(884, 841)
$form.MinimumSize = New-Object Drawing.Size(760, 680)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.ForeColor = $ink; $form.BackColor = $canvas

$scrollHost = New-Object Windows.Forms.Panel
$scrollHost.Dock = 'Fill'; $scrollHost.AutoScroll = $true
$form.Controls.Add($scrollHost)
function New-Stack {
    $panel = New-Object Windows.Forms.TableLayoutPanel
    $panel.ColumnCount = 1; $panel.RowCount = 0
    [void]$panel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent', 100)))
    $panel.Dock = 'Top'; $panel.AutoSize = $true; $panel.AutoSizeMode = 'GrowAndShrink'
    $panel.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 10)
    $panel.Padding = New-Object Windows.Forms.Padding(12)
    $panel.BackColor = [Drawing.Color]::White
    return $panel
}
function Add-Row($panel, $control) {
    $row = $panel.RowCount; $panel.RowCount++
    [void]$panel.RowStyles.Add((New-Object Windows.Forms.RowStyle('AutoSize')))
    $panel.Controls.Add($control, 0, $row)
}
function New-Text([string]$text, [single]$size = 10, [bool]$bold = $false) {
    $label = New-Object Windows.Forms.Label
    # Dock Top fills width without stretching the last auto-sized label vertically.
    $label.Text = $text; $label.AutoSize = $true; $label.Dock = 'Top'
    $label.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 6)
    $style = if ($bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $label.Font = New-Object Drawing.Font('Segoe UI', $size, $style)
    $label.ForeColor = if ($bold) { $ink } else { $muted }
    return $label
}
function New-Btn([string]$text, [int]$width, [bool]$primary = $false) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text; $b.Size = New-Object Drawing.Size($width, 42)
    $b.Margin = New-Object Windows.Forms.Padding(0, 4, 10, 4)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = [Drawing.ColorTranslator]::FromHtml('#C8D4DC')
    $b.BackColor = [Drawing.Color]::White; $b.ForeColor = $ink
    $b.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $b.UseVisualStyleBackColor = $false; $b.Cursor = 'Hand'
    if ($primary) {
        $b.BackColor = $accent; $b.ForeColor = [Drawing.Color]::White
        $b.FlatAppearance.BorderColor = $accent
        $b.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#096C77')
    }
    $b.AccessibleName = $text
    return $b
}
function New-Actions {
    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.Size = New-Object Drawing.Size(1, 1)
    $flow.AutoSize = $true; $flow.AutoSizeMode = 'GrowAndShrink'
    $flow.Dock = 'Fill'; $flow.WrapContents = $true; $flow.Margin = New-Object Windows.Forms.Padding(0)
    return $flow
}
$layout = New-Stack
$layout.Padding = New-Object Windows.Forms.Padding(20)
$layout.Margin = New-Object Windows.Forms.Padding(0)
$layout.BackColor = $canvas
$scrollHost.Controls.Add($layout)
$header = New-Stack
$header.BackColor = $canvas; $header.Padding = New-Object Windows.Forms.Padding(0)
Add-Row $header (New-Text 'Build a safer browsing list.' 24 $true)
Add-Row $header (New-Text 'Create a website blocklist for ESET. This does not block installed programs.' 10)
Add-Row $layout $header

$statusCard = New-Stack
$statusCard.BackColor = [Drawing.ColorTranslator]::FromHtml('#E5F1F3')
$status = New-Text '' 11 $true
Add-Row $statusCard $status
Add-Row $layout $statusCard

$grp = New-Stack
Add-Row $grp (New-Text '1. Choose which websites to block' 12 $true)
Add-Row $grp (New-Text 'The list covers many remote-access tools. These four are optional:' 10)
$choices = New-Actions
function New-Chk([string]$text, [int]$tabIndex, [bool]$on) {
    $c = New-Object Windows.Forms.CheckBox
    $c.Text = $text; $c.Checked = $on; $c.AutoSize = $true; $c.TabIndex = $tabIndex
    $c.Margin = New-Object Windows.Forms.Padding(0, 6, 28, 6)
    $c.AccessibleName = 'Block ' + $text + ' websites'
    $choices.Controls.Add($c); return $c
}
# Preserve the accepted default: all four are allowed unless explicitly selected.
$chkT = New-Chk 'TeamViewer' 12 $false
$chkA = New-Chk 'AnyDesk' 170 $false
$chkS = New-Chk 'Splashtop' 310 $false
$chkR = New-Chk 'RustDesk' 450 $false
Add-Row $grp $choices
Add-Row $grp (New-Text 'Checked = blocked. Unchecked = allowed.' 9)
Add-Row $layout $grp

$buildCard = New-Stack
Add-Row $buildCard (New-Text '2. Build your website list' 12 $true)
Add-Row $buildCard (New-Text 'Downloads the latest catalogue, creates the file and copies its path for the ESET import dialog.' 10)
$buildActions = New-Actions
$btnDo = New-Btn 'Build website list' 200 $true
$buildActions.Controls.Add($btnDo)
Add-Row $buildCard $buildActions
Add-Row $buildCard (New-Text 'Review the list before importing: it can include antivirus, cloud-service and VPN websites.' 9)
Add-Row $layout $buildCard

$importCard = New-Stack
Add-Row $importCard (New-Text '3. Import into ESET' 12 $true)
Add-Row $importCard (New-Text 'You still need to import this file into ESET.' 10)
Add-Row $importCard (New-Text 'Review the list, then follow the instructions. In ESET: Import > File name > paste the path > Open.' 10)
$pathBox = New-Object Windows.Forms.TextBox
$pathBox.ReadOnly = $true; $pathBox.Dock = 'Fill'; $pathBox.BorderStyle = 'FixedSingle'
$pathBox.BackColor = [Drawing.Color]::White; $pathBox.ForeColor = $ink
$pathBox.Margin = New-Object Windows.Forms.Padding(0, 4, 0, 6)
$pathBox.AccessibleName = 'ESET import file path'
Add-Row $importCard $pathBox
Add-Row $importCard (New-Text 'File path - select and press Ctrl+C to copy it again. Do not paste the path into Enter multiple values.' 9)
$importActions = New-Actions
$btnFolder = New-Btn 'Open file folder' 155
$btnList = New-Btn 'Review list' 140
$btnGuide = New-Btn 'ESET & instructions' 195
# Ampersand is literal here, not a hidden keyboard mnemonic.
$btnGuide.UseMnemonic = $false
foreach ($button in $btnFolder, $btnList, $btnGuide) { $importActions.Controls.Add($button) }
Add-Row $importCard $importActions
Add-Row $layout $importCard

Add-Row $layout (New-Text 'Activity and troubleshooting' 10 $true)
$log = New-Object Windows.Forms.RichTextBox
$log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true; $log.WordWrap = $true
$log.Dock = 'Fill'; $log.Height = 150; $log.BorderStyle = 'None'
$log.BackColor = [Drawing.Color]::White; $log.ForeColor = $ink
$log.Font = New-Object Drawing.Font('Consolas', 9)
$log.Margin = New-Object Windows.Forms.Padding(0, 0, 0, 8)
$log.AccessibleName = 'Activity and troubleshooting log'
Add-Row $layout $log
# Let long explanations wrap at the current window width, including high-DPI scaling.
$layout.Add_SizeChanged({
    $width = [Math]::Max(200, $layout.ClientSize.Width - $layout.Padding.Horizontal - $grp.Padding.Horizontal)
    foreach ($section in $header, $statusCard, $grp, $buildCard, $importCard, $layout) {
        foreach ($control in $section.Controls) {
            if ($control -is [Windows.Forms.Label] -and $control.MaximumSize.Width -ne $width) {
                $control.MaximumSize = New-Object Drawing.Size($width, 0)
            }
        }
    }
})

function Say([string]$m, [string]$color = '') {
    # RichTextBox, NOT TextBox: SelectionColor (the colouring below) is a RichTextBox property only.
    # With a plain TextBox the first coloured line throws "The property 'SelectionColor' cannot be
    # found on this object" and kills the run - the generator had already succeeded, so the list
    # looked like it had failed.
    $log.AppendText($m + "`r`n")
    if ($color) {
        # colour is a nicety, never load-bearing: if the control cannot colour, still print the line.
        try {
            $n = $log.TextLength
            $log.SelectionStart = $n - $m.Length - 2
            $log.SelectionLength = $m.Length
            $log.SelectionColor = switch ($color) {
                'Yellow' { [Drawing.ColorTranslator]::FromHtml('#855400') }
                'Green' { [Drawing.ColorTranslator]::FromHtml('#176744') }
                'Red' { [Drawing.ColorTranslator]::FromHtml('#B42318') }
                default { [Drawing.Color]::FromName($color) }
            }
            $log.SelectionStart = $n
            $log.SelectionLength = 0
        } catch { }
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
    foreach ($b in $btnDo, $btnFolder, $btnList, $btnGuide) { $b.Enabled = -not $on }
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
    # These are independent conveniences: failure to open one must not skip the other.
    try {
        $egui = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'ESET') -Filter egui.exe -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($egui) { Start-Process -FilePath $egui.FullName } else { Say '  ESET not found - open it from the Start menu.' }
    } catch { Say ('  Could not open ESET: ' + $_.Exception.Message + '. Open it from the Start menu.') 'Yellow' }
    try {
        $guide = Find-Newest 'HOW-TO-IMPORT.txt' $Parts.Eset
        if ($guide -and (Test-Path -LiteralPath $guide -PathType Leaf)) {
            Start-Process notepad.exe -ArgumentList ('"' + $guide + '"')
        } else { Say '  (the guide HOW-TO-IMPORT.txt was not found next to this program.)' 'Yellow' }
    } catch { Say ('  Could not open the import guide: ' + $_.Exception.Message) 'Yellow' }
}
function Update-Status {
    if (Test-Path -LiteralPath $UrlListFile) {
        $n = @(Get-Content -LiteralPath $UrlListFile).Count
        $status.Text = "List ready: $n website entries. Next: review and import into ESET."
        $status.ForeColor = $ink
        $pathBox.Text = $UrlListFile
    } else {
        $status.Text = 'No list built yet. Start with step 1 below.'
        $status.ForeColor = $ink
        $pathBox.Text = ''
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
            Say ('  IMPORT FILE: ' + $UrlListFile) 'DarkBlue'
            Say ('  (' + $lines.Count + ' entries)') 'DarkBlue'

            $clipOk = $false
            try {
                Set-Clipboard -Value $UrlListFile -ErrorAction Stop
                # read it back: Set-Clipboard returns nothing, so verify rather than assume
                $back = Get-Clipboard -Raw -ErrorAction Stop
                $clipOk = ($back.TrimEnd("`r", "`n") -eq $UrlListFile)
            } catch { $clipOk = $false }

            if ($clipOk) {
                Say '  -> import FILE PATH copied to the clipboard (verified).' 'Green'
            } else {
                Say '  -> could NOT copy the file path to the clipboard. Browse to:' 'Red'
                Say '     in ESET choose Import and pick eset-blocked-urls.txt.' 'Yellow'
            }
            Say '  Tip: import it into a NEW list named "RMM scam block (lolrmm)" so UNDO is one click.'
            Open-ListFolder $true
            # Preview the actual import list as well as the instructions. A Notepad failure
            # must not prevent the folder, clipboard or ESET handoff from remaining usable.
            try {
                Start-Process notepad.exe -ArgumentList ('"' + $UrlListFile + '"')
            } catch { Say ('  Could not open the list in Notepad: ' + $_.Exception.Message) 'Yellow' }
            Say '  One combined list. Review url-review.csv: it includes AV, SaaS and VPN domains.' 'Yellow'
            # Install the ESET-aware undo tool now that this PC actually has an ESET layer. Program 1
            # installs its own (App Control only) undo tool; this one adds the ESET removal steps.
            $instEset = Find-Newest 'Install-ESET-Revert.v*.ps1' $Parts.Eset
            if ($instEset) {
                Say ''
                Say '  Installing the undo tool (removes the list from ESET later) ...'
                try {
                    if ((Run-Script $instEset @()) -ne 0) { Say '  Undo installer failed; the import list is still ready.' 'Yellow' }
                } catch { Say ('  Undo installer failed: ' + $_.Exception.Message + '. The import list is still ready.') 'Yellow' }
            } else {
                Say '  (the undo-tool installer Install-ESET-Revert.v*.ps1 was not found - the list can still be' 'Yellow'
                Say '   removed by hand in ESET; run this program again from the full kit to install the tool.)' 'Yellow'
            }
            try { Open-EsetAndGuide } catch { Say ('  Could not open ESET/guide: ' + $_.Exception.Message) 'Yellow' }
            Say ''
            Say 'LAST STEP (by hand): in ESET press F5 and follow the guide in Notepad -'
            if ($clipOk) {
                Say 'click Import, paste the copied FILE PATH into File name, then Open -> OK.'
            } else {
                Say ('click Import and choose: ' + $UrlListFile)
            }
            Say ('  [log] ESET import file: ' + $UrlListFile + ' (' + $lines.Count + ' entries, clipboard=' + $clipOk + ')')
        }
    } catch {
        # Name where it died: the owner's "not copied to clipboard" was really this handler firing on an
        # earlier line, which skipped the clipboard step entirely and made the list look broken.
        Say ('ERROR: ' + $_.Exception.Message) 'Red'
        Say ('       at line ' + $_.InvocationInfo.ScriptLineNumber + ': ' + $_.InvocationInfo.Line.Trim())
        Say '       the list file may still be on disk - press "Open the list folder" to check.'
    } finally {
        try { Update-Status }
        catch { Say ('  Could not refresh list status: ' + $_.Exception.Message) 'Yellow' }
        finally { Busy $false }
    }
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

$btnList.Add_Click({
    if (-not (Test-Path -LiteralPath $UrlListFile -PathType Leaf)) {
        Say 'No list built yet - press BUILD first.' 'Yellow'
        return
    }
    try {
        Start-Process notepad.exe -ArgumentList ('"' + $UrlListFile + '"')
        Say ('Opened list: ' + $UrlListFile)
    } catch { Say ('Could not open the list in Notepad: ' + $_.Exception.Message) 'Yellow' }
})

$btnGuide.Add_Click({ Open-EsetAndGuide })

# ---------------------------------------------------------------- start
Say 'Choose any optional websites to block, then click Build website list.'
Say 'The file path is copied automatically. Review the file, then follow step 3 to import into ESET.'
Say 'ESET is not changed automatically. Keep websites your client needs out of the list.'
Update-Status
[void]$form.ShowDialog()