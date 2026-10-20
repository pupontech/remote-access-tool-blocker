param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent), [string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
function Assert($ok, [string]$message) { if (-not $ok) { throw $message }; Write-Host "PASS: $message" }
$p2 = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'kits/2') -Filter 'Block-The-Websites.v*.ps1' | Select-Object -First 1
$text = Get-Content -Raw $p2.FullName
Assert ($text.Contains('Windows.Forms.TableLayoutPanel')) 'website window uses content-based layout'
Assert ($text.Contains('You still need to import this file into ESET.')) 'manual import limitation stays visible outside the log'
Assert ($text.Contains('Checked = blocked. Unchecked = allowed.')) 'checkbox meanings are explicit'
Assert ($text.Contains('1. Choose which websites to block')) 'choice step has a plain-language heading'
Assert ($text.Contains('2. Build your website list')) 'build step has a plain-language heading'
Assert ($text.Contains('3. Import into ESET')) 'manual import has a permanent step'
if ($env:OS -ne 'Windows_NT') { Write-Host 'Rendered Windows layout assertions deferred to Windows CI'; return }
$work = Join-Path ([IO.Path]::GetTempPath()) ('eset-ui-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $copy = Join-Path $work $p2.Name
    [IO.File]::WriteAllText($copy, $text.Replace('[void]$form.ShowDialog()', '# suppressed by UI test'))
    . $copy
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    if ($EvidenceDirectory) {
        New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
        $initial = New-Object Drawing.Bitmap($form.Width, $form.Height)
        try {
            $form.DrawToBitmap($initial, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
            $initial.Save((Join-Path $EvidenceDirectory 'eset-initial.png'), [Drawing.Imaging.ImageFormat]::Png)
        } finally { $initial.Dispose() }
    }
    Assert ($form.BackColor.ToArgb() -ne [Drawing.SystemColors]::Control.ToArgb()) 'window has a deliberate neutral canvas'
    Assert ($btnDo.Text -eq 'Build website list') 'primary action describes its actual effect'
    Assert ($pathBox.ReadOnly) 'import path is visible and read-only'
    Assert ($status.Text -match 'No list') 'empty state explains that a list must be built'
    foreach ($c in $chkT, $chkA, $chkS, $chkR) { Assert (-not $c.Checked) "$($c.Text) still starts allowed" }
    Busy $true
    Assert (-not $btnDo.Enabled -and -not $btnFolder.Enabled -and -not $btnList.Enabled -and -not $btnGuide.Enabled) 'all actions disabled while building'
    Busy $false
    Assert ($btnDo.Enabled -and $btnFolder.Enabled -and $btnList.Enabled -and $btnGuide.Enabled) 'all actions restored after building'
    $script:guideCalls = 0
    function Open-EsetAndGuide { $script:guideCalls++ }
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($copy, [ref]$tokens, [ref]$errors)
    $handler = $ast.Find({ param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Extent.Text.StartsWith('$btnGuide.Add_Click(') }, $true)
    Assert ($null -ne $handler) 'ESET and instructions action is wired'
    $body = $handler.Arguments[0].ScriptBlock.Extent.Text
    & ([scriptblock]::Create($body.Substring(1, $body.Length - 2)))
    Assert ($script:guideCalls -eq 1) 'instructions action reuses the protected production handoff'
    $UrlListFile = Join-Path $work 'eset-blocked-urls.txt'
    Set-Content -LiteralPath $UrlListFile -Value @('*.fixture-one.example', '*.fixture-two.example')
    Update-Status
    Assert ($status.Text -match '2' -and $status.Text -match 'import') 'ready state reports entries without claiming ESET is configured'
    Assert ($pathBox.Text -eq $UrlListFile) 'ready state displays the exact import path'
    if ($EvidenceDirectory) { New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null }
    foreach ($case in @(@{ Name = 'default'; Size = (New-Object Drawing.Size(900, 880)) }, @{ Name = 'compact'; Size = $form.MinimumSize })) {
        $form.Size = $case.Size
        $scrollHost.AutoScrollPosition = New-Object Drawing.Point(0, 0)
        $form.PerformLayout(); [Windows.Forms.Application]::DoEvents()
        Assert ($layout.Width -le $scrollHost.ClientSize.Width) "$($case.Name): no horizontal scrolling"
        if ($case.Name -eq 'default') {
            $guideBottom = $form.PointToClient($btnGuide.PointToScreen((New-Object Drawing.Point(0, $btnGuide.Height)))).Y
            Assert ($guideBottom -le $form.ClientSize.Height) 'default: all import actions visible without scrolling'
        }
        foreach ($button in $btnDo, $btnFolder, $btnList, $btnGuide) {
            Assert ($button.Width -ge 120 -and $button.Height -ge 36) "$($case.Name): $($button.Text) has a usable target"
        }
        Assert ($grp.Height -ge ($choices.Bottom + $grp.Padding.Bottom)) "$($case.Name): checkboxes fit inside their section"
        if ($EvidenceDirectory) {
            $bitmap = New-Object Drawing.Bitmap($form.Width, $form.Height)
            try {
                $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                $bitmap.Save((Join-Path $EvidenceDirectory ("eset-$($case.Name).png")), [Drawing.Imaging.ImageFormat]::Png)
            } finally { $bitmap.Dispose() }
        }
    }
} finally {
    if ($form) { $form.Dispose() }
    Remove-Item -LiteralPath $work -Recurse -Force
}
