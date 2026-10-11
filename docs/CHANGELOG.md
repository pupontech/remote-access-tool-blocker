# Changelog

All notable changes to this project. Dates are the versioning dates carried in the script filenames.

## Unreleased

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