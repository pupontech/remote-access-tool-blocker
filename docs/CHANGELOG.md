# Changelog

All notable changes to this project. Dates are the versioning dates carried in the script filenames.

## Unreleased

### Fixed: the ESET list did not appear to arrive

Two independent defects, either of which alone makes the list look like it vanished.

**1. The window could die before it ever appeared.** The output-folder line ran at script scope with
`$ErrorActionPreference = 'Stop'`:

```powershell
$UrlOut = Join-Path $env:USERPROFILE 'LOLRMM-UrlList\latest'
```

If `USERPROFILE` is unset (service accounts, some elevated/RDP contexts) that throws — and it sits **before** the
form is constructed and before BLOCK is wired, so the window never opens and BLOCK appears to do nothing. The
launcher starts the window hidden, so there is no visible error either. The folder is now resolved defensively and
falls back to a folder beside the script.

**2. The list was written somewhere nobody was told about, and the clipboard was assumed to work.** The window
printed "list copied to the clipboard" without checking, and never disclosed where the file was. `Set-Clipboard`
returns nothing and can fail or write to a *different* session's clipboard when the process runs elevated — so the
success message could be false while `eset-blocked-urls.txt` sat in an unmentioned folder. Now it:

- **always prints the import file path** and the entry count in the window,
- **reads the clipboard back** and only claims success when the contents actually match,
- when the clipboard fails, says so and points at the file: *"in ESET choose Import and pick that
  eset-blocked-urls.txt file"*,
- and reports each failure mode distinctly instead of collapsing them: generator not found (with the folder it
  searched), generator failed, generator ran but produced no file.

**Also guarded `$env:USERPROFILE` in both ESET generators** (`Get-LolrmmUrlList`, `Get-LolrmmHipsList`), which threw
on a default run without it; they now fall back to a folder beside the script.

Verified by running the real generator the way the window invokes it: 406 entries at the announced path, no BOM,
`anydesk.com` present, an excluded tool genuinely absent, `-OutDir` honoured on repeat runs, and a default run
without `USERPROFILE` falling back instead of crashing.

## 2026.10.11

### Windows-only kit: its removal tool no longer has the ESET part

The Windows-only kit installs no ESET layer, but the shared revert tool unconditionally opened ESET, printed ESET
removal steps and shipped the ESET guide — so a Windows-only deployment was told to go un-block something it had
never blocked. Fixed by generating two variants from one source:

| Kit | Variant installed | Behaviour |
|---|---|---|
| Windows-only | `Revert-RemoteAccessBlock-WinOnly.v*.ps1` | App Control removal only. No ESET window, no ESET steps, no guide, and it does not read the `LOLRMM-UrlList` folder at all. |
| Full (ESET) | `Revert-RemoteAccessBlock.v*.ps1` | Removes the policy and walks through taking the website list back out of ESET. |

- The installer picks the variant the kit ships, and **removes the other variant** if a previous install used it —
  so a PC moved to Windows-only can never keep an ESET-capable script.
- The ESET guide is not installed on the Windows-only path; its `docs\` folder is not created at all.
- Each variant writes a matching `README.txt`, so the instructions on the PC match what that script does.
- Both variants are generated from one marked-up source (never hand-edited), so they cannot drift.

Verified by running the installed copies: the Windows-only copy completes a full revert with **zero** ESET
actions (no ESET line in the output, no ESET-named file anywhere in the install, no `docs\`, no `eset-lists\`
backup), while the full copy still presents the ESET guide and steps. Switching kits in both directions leaves
exactly one variant installed.

### Fixed the dry run — `-WhatIf` did not work

`-WhatIf` was documented in the README, the release notes, the script's own help and the launcher comments, but it
was **not a parameter at all**: `[CmdletBinding()]` alone does not add it to a script, so the switch failed to
bind with *"A parameter cannot be found that matches parameter name 'WhatIf'"*. The one guardrail that shows what a
revert would do without changing anything was unusable.

Making it exist via `SupportsShouldProcess` was tried and rejected: that works, but makes PowerShell intercept every
`ShouldProcess`-aware cmdlet the script calls (`New-Item`, `Add-Content`, `Set-Content`, …) and emit its own
framework chatter, burying the dry run the operator is meant to read. `-WhatIf` is now an explicit switch driving
the same guard — nothing is written when it is set, with readable output.

Three further defects surfaced only once the dry run actually ran:

- **A crash on the dry-run path**: `Say '[dry run] would write a log line to ' $LogFile` does not concatenate — the
  path bound to `-ForegroundColor` and died with *"Cannot convert value '…\Revert.log' to type System.ConsoleColor"*.
  Fixed at all three sites by parenthesising the expression.
- **`$env:USERPROFILE` unguarded** in the ESET-only backup loop, so a host without it died with a bare null-`Path`
  error. Only the full variant hit it, which is why the Windows-only copy ran clean.
- **`$env:windir` unguarded**, so the tool died at startup on any host lacking it. It now refuses with a specific
  message and exit code 9 ("This tool needs Windows") instead of an error naming no useful line.

## 2026.10.11

### Standalone revert / restore tool (`C:\RemoteAccessToolBlocker`)

- **`revert/` — a self-contained undo tool** (`Run-Revert.bat` + `Revert-RemoteAccessBlock`). Applying a block now
  installs a copy of it to `C:\RemoteAccessToolBlocker` on the PC, so the block can be removed later without the
  original kit, the network, or the repository.
- **Revert**: backs up the installed policy, its toggles and mode, the generated ESET lists and a machine summary
  into `backups\<timestamp>\` (one dated folder per revert, never overwritten), then removes the App Control policy
  and opens ESET with a removal guide. The repository path is untouched.
- **Restore**: `-Restore` lists the dated backups and re-installs the policy with its original toggles, so the block
  can be put back without the kit.
- **`-WhatIf`** dry-runs the whole thing and reaches neither removal call.
- **`-NoPause`** for remote/unattended use; **`-RemoveFolder`** to delete the folder and backups afterwards,
  refusing unless the folder is actually named `RemoteAccessToolBlocker`.
- Shipped inside both kit ZIPs and wired into `Install-RmmAppControl`, which copies it after a successful
  Enforce/Audit install and takes a dated backup of any previous install first.
- The ESET website list remains a manual removal — ESET exposes no scriptable interface for it — so the tool backs
  up the generated list, opens ESET and prints the exact clicks, including a warning for the case where the entries
  went into ESET's own built-in list rather than a list you created.

Verified by execution, not inspection: both the repo layout and an extracted release ZIP install the tool
correctly; policies land at `policy\variants\` with all 32 variants; a repeat install backs up the previous
backups instead of clobbering them. Three defects were found and fixed that way — the release-ZIP layout was never
detected, the ESET guide never copied, and the policies landed double-nested because `-LiteralPath` does not expand
a `*` glob.

## 2026.10.11

First public release. The work below was done as a single continuous effort on 2026-10-07, 2026-10-08 and
2026-10-11, so the history is recorded by date rather than by release tag.

### 2026-10-11 — App Control layer, ESET website list, front end (v3)

- **Windows App Control layer added.** `Build-RmmAppControl` turns the LOLRMM code-signing certificates into a
  deny policy on top of Microsoft's `AllowAll.xml` template. Leaf and publisher rules per vendor, so renewal under
  the same CA keeps blocking. Fixed policy ID, multiple-policy format, so a rebuild replaces the installed policy
  rather than stacking.
- **Status-filter fix.** CodeIntegrity 3076/3077 events carry the *policy ID*, not its name; the status view now
  filters on the GUID.
- **ESET website list** (`Get-LolrmmUrlList`, v1). Catalogue domains to an ESET import file (~406 masks) with
  shared-platform safety filtering, tiered optional entries, and review CSVs. Read-only.
- **Unified front end** (`RmmBlocker` window). BLOCK / UNDO / Test mode / Refresh status, with checkbox toggles.
- **Toggle support, v2** — TeamViewer, AnyDesk and Splashtop switchable per PC, with all eight combinations
  pre-built so Windows Home PCs can switch without ConfigCI. The installed combination is written into the policy
  name and read back by the window.
- **RustDesk toggle and file-name rule, v3.** RustDesk is not in the catalogue; its certificate was taken from the
  official 1.5.0 Windows build and embedded in the builder, alongside an `rustdesk.exe` `OriginalFileName` deny
  that catches self-built "custom client" copies. All 16 combinations × 2 modes = 32 policies pre-built.
  Default is `T1A1S0R1`.
- **Windows-only kit** (`remote-tools-block-windows`), the same window without the ESET steps, sharing the policy
  ID so either kit replaces the other's install.

### 2026-10-08 — ESET HIPS path list

- Prototype (`Get-LolrmmHipsList`) turning the catalogue into ESET HIPS path lists, with disk scanning,
  confidence ratings and a skipped-items report. Read-only. Superseded by the App Control layer, because path
  rules miss portable and renamed copies — kept in `src/eset/` as experimental.

### 2026-10-07 — HIPS prototype

- First prototype (`archive/eset-hips-poc`), automating the evidence-gathering steps of a manual ESET HIPS rule
  test: hash verification, private evidence folders, `ecmd /getcfg` exports before and after a hand-made rule,
  running a known test executable unelevated via a one-shot scheduled task, XML diffs, and a sanitized result
  file. The rule creation and removal stayed manual by design. Kept in `archive/` for history; superseded.

## Verified status at this release

Read [`docs/testing.md`](docs/testing.md) for the full picture. In short:

- **Verified on a real PC:** the policy loads; audit logged AnyDesk, TeamViewer and ScreenConnect (3076);
  enforcement blocked AnyDesk (3077); the ESET URL import worked.
- **Not yet observed on a PC:** a RustDesk block; the window buttons being clicked by an automated test; Windows
  Home behaviour.