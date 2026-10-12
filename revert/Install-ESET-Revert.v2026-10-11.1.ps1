<#
.SYNOPSIS
  Program 2 helper - install the standalone ESET-aware revert tool to C:\RemoteAccessToolBlocker.
  Run for you by START-HERE.bat (folder 2) the first time it builds a list; can also be run by hand.

.DESCRIPTION
  Program 1 installs its own undo tool (App Control removal only). This is the OTHER half: the undo tool that
  also walks you through taking the website list back out of ESET. It is installed only from program 2, so a PC
  with no ESET layer is never handed ESET removal steps.

  It copies, into C:\RemoteAccessToolBlocker:
    Run-Revert.bat
    Revert-RemoteAccessBlock.v*.ps1        (the full, ESET-aware variant)
    docs\eset-remove-guide.txt
  and REMOVES the Windows-only variant if program 1 had installed one, so exactly one variant is present and the
  installed tool matches what was actually blocked on the PC. A dated backup of any previous install is taken
  first; the old folder is never removed before the new copy is in place.

  Policy files are NOT touched here - program 1 owns those.

.PARAMETER InstallDir  Override the destination (testing). Default: <SystemDrive>\RemoteAccessToolBlocker
.PARAMETER WhatIf      Show what would happen and change nothing.
#>
[CmdletBinding()]
param(
    [string]$InstallDir,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-11.1'
$Here = $PSScriptRoot
# $PSScriptRoot inside a FUNCTION is the CALLER's script root, so capture it once at script scope.
$ScriptRootHere = $PSScriptRoot
$RepoRootHere = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

if (-not $InstallDir) {
    if (-not $env:SystemDrive) {
        Write-Host 'This tool needs Windows (SystemDrive is not set).'
        exit 9
    }
    $InstallDir = Join-Path $env:SystemDrive 'RemoteAccessToolBlocker'
}

function Write-Step([string]$m) {
    if ($WhatIf) { Write-Host "[dry run] $m" } else { Write-Host $m }
}

# ---------------------------------------------------------------- find our files
# Resolve by the FILES we need, not by a folder name: in the repo they live in revert\, but in a built release
# ZIP they sit loose beside this script. Looking for a folder named 'revert' made the kit layout silently skip.
function Find-RevertDir {
    $candidates = @(
        @{ root = $ScriptRootHere; sub = '' },
        @{ root = $ScriptRootHere; sub = 'revert' },
        @{ root = $RepoRootHere;   sub = '' },
        @{ root = $RepoRootHere;   sub = 'revert' }
    )
    foreach ($c in $candidates) {
        if (-not $c.root) { continue }
        $dir = if ($c.sub) { Join-Path $c.root $c.sub } else { $c.root }
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        if (Get-ChildItem -Path (Join-Path $dir 'Revert-RemoteAccessBlock.v*.ps1') -File -ErrorAction SilentlyContinue) {
            return $dir
        }
    }
    return $null
}
function Find-GuideDir {
    # The guide is revert\docs\ in the repo and revert-docs\ in a release ZIP.
    $candidates = @(
        (Join-Path $ScriptRootHere 'docs'),
        (Join-Path $ScriptRootHere 'revert-docs'),
        (Join-Path $ScriptRootHere 'revert\docs'),
        (Join-Path $RepoRootHere   'revert\docs')
    )
    foreach ($d in $candidates) {
        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'eset-remove-guide.txt'))) { return $d }
    }
    return $null
}

$revDir = Find-RevertDir
if (-not $revDir) {
    Write-Host 'Revert-RemoteAccessBlock.v*.ps1 was not found next to this program - cannot install the undo tool.'
    exit 2
}
$fullRev = @(Get-ChildItem -LiteralPath $revDir -Filter 'Revert-RemoteAccessBlock.v*.ps1' -File)
$runRevert = @(Get-ChildItem -LiteralPath $revDir -Filter 'Run-Revert.bat' -File)
if ($fullRev.Count -ne 1) {
    Write-Host "Expected exactly 1 Revert-RemoteAccessBlock.v*.ps1 in $revDir, found $($fullRev.Count)."
    exit 2
}
$guideDir = Find-GuideDir

Write-Host "Install-ESET-Revert v$ScriptVersion"
Write-Host "  source   : $revDir"
Write-Host "  guide    : $(if ($guideDir) { $guideDir } else { 'NOT FOUND (the tool will print the steps instead)' })"
Write-Host "  install  : $InstallDir"

if ($WhatIf) { Write-Host '[dry run] nothing below this line changes anything.' }

# ---------------------------------------------------------------- 1. backup an existing install
if (Test-Path -LiteralPath $InstallDir) {
    $old = Join-Path $InstallDir 'backups'
    if (Test-Path -LiteralPath $old) {
        $keep = Join-Path ($InstallDir + '.backup-' + (Get-Date -Format 'yyyy-MM-dd_HHmmss')) 'backups'
        if ($WhatIf) {
            Write-Step "would back up existing backups to $keep"
        } else {
            try {
                New-Item -ItemType Directory -Force -Path (Split-Path $keep -Parent) | Out-Null
                Copy-Item -LiteralPath $old -Destination $keep -Recurse -Force
                Write-Step "backed up the previous revert-tool backups to $keep"
            } catch { Write-Host "could not back up previous backups: $($_.Exception.Message)" }
        }
    }
} else {
    if ($WhatIf) { Write-Step "would create $InstallDir" } else { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
}

# ---------------------------------------------------------------- 2. exactly one variant: the full one
$winOnlyName = 'Revert-RemoteAccessBlock-WinOnly.v*.ps1'
$hadWinOnly = @(Get-ChildItem -Path (Join-Path $InstallDir $winOnlyName) -File -ErrorAction SilentlyContinue)
foreach ($stale in $hadWinOnly) {
    if ($WhatIf) {
        Write-Step "would remove the Windows-only variant: $($stale.Name)"
    } else {
        Remove-Item -LiteralPath $stale.FullName -Force
        Write-Step "removed the Windows-only variant: $($stale.Name)"
    }
}
foreach ($f in @($fullRev + $runRevert)) {
    if ($WhatIf) {
        Write-Step "would copy $($f.Name)"
    } else {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $InstallDir $f.Name) -Force
        Write-Step "copied $($f.Name)"
    }
}

# ---------------------------------------------------------------- 3. the ESET removal guide
if ($guideDir) {
    $destDocs = Join-Path $InstallDir 'docs'
    if ($WhatIf) {
        Write-Step "would copy eset-remove-guide.txt into $destDocs"
    } else {
        New-Item -ItemType Directory -Force -Path $destDocs | Out-Null
        Copy-Item -LiteralPath (Join-Path $guideDir 'eset-remove-guide.txt') -Destination $destDocs -Force
        Write-Step 'copied docs\eset-remove-guide.txt'
    }
} else {
    Write-Host 'WARNING: eset-remove-guide.txt not found - the installed tool will print the steps instead.'
}

# ---------------------------------------------------------------- 4. a README that matches THIS variant
if (-not $WhatIf) {
    # [System.Collections.Generic.List[string]] not @(): a bare @() is a fixed-size array and .Add() on it
    # throws "Collection was of a fixed size" (found by running this, not by reading it).
    $readme = [System.Collections.Generic.List[string]]::new()
    $readme.Add('Remote-access tool blocker - undo tool')
    $readme.Add('')
    $readme.Add('This folder was installed by the website-list program (folder "2"). It removes BOTH halves')
    $readme.Add('of the block on this PC:')
    $readme.Add('  1. the Windows App Control policy (the programs), and')
    $readme.Add('  2. the ESET website list (by hand, following docs\eset-remove-guide.txt).')
    $readme.Add('')
    $readme.Add('Double-click Run-Revert.bat. It backs everything up into backups\ first.')
    $readme.Add('Run-Revert.bat -WhatIf shows every step and changes nothing.')
    $readme.Add('')
    $readme.Add('This variant DOES handle ESET. It is only installed by program 2, so a PC with no')
    $readme.Add('antivirus layer is never told to go un-block something it never blocked.')
    Set-Content -LiteralPath (Join-Path $InstallDir 'README.txt') -Value $readme -Encoding ASCII
    Write-Step 'wrote README.txt (full variant)'
}

Write-Host ''
Write-Host "Done. Undo tool at: $InstallDir"
Write-Host 'Double-click Run-Revert.bat there to remove the block.'
exit 0