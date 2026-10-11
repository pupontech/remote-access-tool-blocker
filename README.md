
# vibe coded use at your own risk
# Remote-access tool blocker (Windows App Control + optional ESET list)

Blocks the **legitimate remote-support tools that tech-support scammers abuse** — AnyDesk, TeamViewer,
ScreenConnect, RustDesk, UltraViewer, Supremo, AeroAdmin and around fifty more — on ordinary Windows 10/11 PCs.

Most home and small-business PCs run consumer antivirus, so this is built to work on a stock PC with nothing but
Windows on it. The blocking is done by **Windows App Control** (WDAC) deny rules built from each vendor's
**code-signing certificate**, so it catches the program *wherever it is*: renamed, saved from an email attachment,
sitting in Downloads, or run from a USB stick.

An optional second layer adds the tools' **websites** (download pages and web consoles) to ESET's web filter.

---

## What it does

There are three independent protection layers. Use whichever fit the PC you are working on.

| Layer | What it blocks | How it is applied | How to undo |
|---|---|---|---|
| **Windows App Control** (WDAC) deny policy | The *programs*, wherever they are — renamed, email attachment, Downloads, USB | Fully scripted | Scripted (+ restart) |
| **ESET web filter** ("List of blocked addresses") | The tools' *websites* — download pages and web consoles | Generated list, **pasted by hand** into ESET | By hand in ESET |
| **ESET "potentially unsafe applications"** | Known remote tools, flagged by ESET itself | One manual toggle | Toggle off |

The App Control layer is the load-bearing one. The ESET layers are optional extras for PCs that run ESET.

---

## Quick start

1. Download the release ZIP for the kit you want:
   - `remote-tools-block-windows-<version>.zip` — App Control only. No antivirus needed. Start here.
   - `full-kit-eset-<version>.zip` — the same, plus the ESET website list.
2. Extract it anywhere on the PC. Keep the folders together — the launcher finds the scripts relative to itself.
3. Double-click **`Remote-Tools-Block-Windows.bat`** (Windows-only kit) or **`START-HERE.bat`** (full kit) and
   accept the administrator prompt.
4. Tick or untick **TeamViewer / AnyDesk / Splashtop / RustDesk**. Ticked = blocked.
5. Press **BLOCK**.
6. **Full kit only: a technician must then paste the website list into ESET BY HAND** — the tool cannot do it and
   cannot verify it. See [The ESET paste](#the-eset-paste--must-be-done-by-hand-by-a-technician).

When the block is applied, the kit also copies a **standalone undo tool** to
`C:\RemoteAccessToolBlocker` on that PC — see [Undoing it later](#undoing-it-later). It is there so the block can
be reverted later without the original kit, the network, or this repository.

To undo immediately: press **UNDO**, then restart the PC. In the full kit, also take the website list back out of
ESET — the guide that opens has the two-click steps.

The status line always shows the current state — **PROTECTED**, **TEST MODE** or **NOT protected** — and what each
toggle is set to. **Refresh status** lists recent events: `[3077]` means a program was blocked, `[3076]` means one
*would* have been blocked (audit mode).

### The ESET paste — **MUST BE DONE BY HAND BY A TECHNICIAN**

> ## ⚠️ THIS STEP CANNOT BE AUTOMATED. A TECHNICIAN MUST DO IT BY HAND.
>
> The **BLOCK** button does everything else itself. It **cannot** add the website list to ESET: ESET's URL list is
> a GUI import/paste with no scriptable interface, and this project deliberately does not guess at ESET's
> configuration XML. **A technician must copy the list and paste it into ESET by hand, following the steps below.**
>
> **Do not skip this step and do not assume it happened.** Until it is done, the ESET website layer of the block is
> not active — the programs are still blocked by Windows App Control, but the tools' download sites and web
> consoles are not.

**Before you start:** the **BLOCK** button has already blocked the programs, built the list and **copied it to your
clipboard**. It also prints the **exact path of the import file** in the window, like this:

```
  IMPORT FILE: C:\Users\<you>\LOLRMM-UrlList\latest\eset-blocked-urls.txt
  (406 entries)
  -> list copied to the clipboard (verified) and opening ESET ...
```

**If the clipboard does not work** — common when the window is running elevated, since an elevated process can own
a different clipboard from your own session — the window says so and tells you to use the file instead:

```
  -> could NOT copy to the clipboard, so use the file instead:
     in ESET choose Import and pick eset-blocked-urls.txt.
```

The window also opens the folder for you on that path, with the file already selected. Either route works. The
clipboard is faster; the file always works. **The list is never lost — it is always on disk at the path the window
prints.**

**Lost the folder?** Press **Open the ESET list folder** in the window at any time — it opens
`%USERPROFILE%\LOLRMM-UrlList\latest` with `eset-blocked-urls.txt` selected, without rebuilding anything.

It takes about a minute from here.

**Follow these steps exactly. Every action below is done by hand in the ESET window.**

| # | **Do this by hand** |
|---|---|
| 1 | **Press `F5`** in ESET to open **Advanced setup**. |
| 2 | Click **Protections** → **Web access protection**. |
| 3 | Open **URL list management**, then next to **Address list** click **Edit**. |
| 4 | **Make your own list** so undo is one click later: click **Add** (**in the *Address list* window — NOT inside an existing list**), set Address list type to **Blocked**, name it **`RMM scam block (lolrmm)`**, and leave **List active** ticked. |
| 5 | Inside that list click **Add** → tick **Enter multiple values**. |
| 6 | **Click in the box and press `Ctrl+V`** to paste the whole list, then click **OK**. *(No clipboard? Use the **Import** button and choose `eset-blocked-urls.txt` from the folder that opened.)* |
| 7 | Click **OK** on every window, then **OK** in Advanced setup to save. |
| 8 | **Also block the programs' backstop:** in Advanced setup type **`unsafe`** in the search box and turn **ON** *"Enable detection of potentially unsafe applications"*, then click **OK**. |

> **No `Add` button in step 4?** Paste into ESET's built-in **List of blocked addresses** → **Edit** instead.
> Undo then takes more work — see the ESET removal guide.

**Test it — by hand:** open a browser and go to **`anydesk.com`**. ESET should show its **"page blocked"** message.
If it loads normally, the paste did not take — repeat steps 1–7.

**To take the list back out (by hand):** `F5` → **Protections** → **Web access protection** →
**URL list management** → **Address list** → **Edit**, then select **`RMM scam block (lolrmm)`** → **Remove**, or
untick **List active** to switch it off but keep it. `OK` → `OK`.

Full detail, including the wording differences between ESET versions, the undo for the built-in list, and the
entries to remove if a client really uses Quick Assist or Chrome Remote Desktop:
[`docs/eset-import-guide.md`](docs/eset-import-guide.md).

### Undoing it later

The undo tool is installed on the PC itself, at:

```
C:\RemoteAccessToolBlocker\
  Run-Revert.bat                          <- double-click this
  Revert-RemoteAccessBlock-variant.ps1    (see the two variants below)
  README.txt
  policy\                                 (the built policies, so it can put the block back)
  backups\                                (created by the first revert)
```

It is placed there automatically when a block is applied, so **the block can be removed later without the original
kit, the network, or this repository.** Because that folder is a permanent, scriptable tool sitting on the machine,
note what it is: it lets anyone with local administrator rights undo the block. That is deliberate — the
alternative is a PC you cannot un-block without hunting down the original kit.

### Two variants, matching the kit you used

The tool installs the variant that matches the kit, because the Windows-only kit never installs an ESET layer and
must not hand out instructions for software that isn't there:

| Kit you used | Variant installed | Behaviour |
|---|---|---|
| **Windows-only** | `Revert-RemoteAccessBlock-WinOnly.v*.ps1` | App Control removal only. **Never touches ESET** — no ESET window, no ESET steps, no guide, and it does not even read the `LOLRMM-UrlList` folder. |
| **Full (with ESET)** | `Revert-RemoteAccessBlock.v*.ps1` | Removes the policy *and* walks you through taking the website list back out of ESET. |

Both variants are generated from one source, so they cannot drift. Switching kits on a PC **removes the other
variant**, so a machine that has moved to Windows-only can never keep an ESET-capable script.

| Command | What it does |
|---|---|
| `Run-Revert.bat` | Undo the block. Backs up first, then removes the policy (and opens the ESET guide on the full variant). |
| `Run-Revert.bat -WhatIf` | **Dry run** — shows every step and changes nothing. |
| `Run-Revert.bat -Restore` | Put a previously backed-up block back, with its original toggles. |
| `Run-Revert.bat -NoPause` | Don't wait for a key press at the end (remote/unattended use). |
| `Run-Revert.bat -RemoveFolder` | After reverting, also delete the folder and its backups. |

**Revert never destroys the ability to restore.** Before it removes anything it copies the installed policy, its
toggles and mode, the generated ESET lists (full variant only) and a machine summary into `backups\<timestamp>\`,
one dated folder per revert, never overwritten. `-Restore` reads those back.

**On the full variant, the ESET website list is the one part it cannot do for you.** ESET's URL list is a UI
import/paste with no scriptable interface, so the tool backs up the generated list, opens ESET,
opens `docs\eset-remove-guide.txt`, and tells you exactly what to click. If you pasted into ESET's own built-in
list rather than a list you created, the guide warns you to check it was empty beforehand — that removal is not
undoable from ESET's side.

`-WhatIf` is the safe way to see what a revert would do on a live machine.

## Test before you enforce

Press **Test mode** first. It installs the same policy in **audit** mode: nothing is blocked, but Windows logs
what would have been. Run the tool you expect to be blocked, then **Refresh status** and confirm you see a `3076`
for it. Only then press **BLOCK**.

---

## What gets blocked

**Always on** — around 55 tools from 52 vendors are covered, including ScreenConnect (ConnectWise Control),
UltraViewer, Supremo, AeroAdmin, Remote Utilities, Remote Manipulator System, Lite Manager, DW Service, Tactical
RMM, Atera, NinjaRMM, Action1, Syncro, SuperOps, MeshCentral, HopToDesk, Getscreen, SimpleHelp, ISL Online and
more. The full list of rules is in [`policy/signers.csv`](policy/signers.csv).

**Switchable per PC** — four tools are on toggles, because a client may legitimately use one:

| Toggle | Tool | Default |
|---|---|---|
| `T` | TeamViewer | **blocked** |
| `A` | AnyDesk | **blocked** |
| `S` | Splashtop | **allowed** |
| `R` | RustDesk | **blocked** |

> **Splashtop is allowed by default** because it is commonly used by IT shops as their own support tool. Blocking
> it cuts off that shop's access to the PC, so the window warns before you do it. **Change this default** for your
> own deployment — see [Configuration](#configuration).

All 16 toggle combinations are pre-built as `.cip` files in `policy/variants/`, so a PC that cannot build policies
(a Windows Home PC, or any PC without the ConfigCI tooling) can still switch between them.

**Optional vendors, not blocked by default** — the vendor list is deliberately hand-checked. Several remote-access
vendors also sign software that people use on purpose (NetSupport School, Impero/Netop and Veyon in schools; GoTo,
Zoho, AOMEI, RealVNC, Famatech/Advanced IP Scanner, Kaseya, N-able, Ivanti), so they are excluded unless you ask
for them with `-IncludeOptional` when rebuilding.

**Never blocked** — a hard guard rejects well-known publishers regardless of the lists: Microsoft, Google, ESET,
Adobe and similar. This exists because the upstream catalogue attaches unrelated certificates to some tools; an
unattended rebuild against it would otherwise block ordinary software.

---

## How it works

The policy starts from Microsoft's own `AllowAll.xml` template — allow-everything — and adds **deny rules for
specific code-signing certificates** in the user-mode signing scenario only. Script enforcement is left **off**, so
PowerShell is not forced into Constrained Language Mode and normal administration keeps working.

For each vendor certificate there are two rules:

- a **leaf** rule — the TBS hash of the vendor's own certificate; and
- a **publisher** rule — the TBS hash of the certificate authority one level below the root, plus the vendor's
  common name.

The publisher rule is what makes this survive certificate renewal: when a vendor reissues its signing certificate
under the same CA, the publisher rule still matches. The AnyDesk and ScreenConnect installers on the original test
PC already prove that.

This is why renaming the file does not help an attacker, why saving it to Downloads does not help, and why running
it from a USB stick does not help — none of those change the signature.

The policy carries a **fixed policy ID** (`{2D13BFB7-4304-4847-9CDD-37820D3EE9B7}`), so installing a newer build
**replaces** the previous policy instead of stacking a second one. Both kits share that ID, so either kit replaces
the other's install.

Full technical detail: [`docs/how-it-works.md`](docs/how-it-works.md).

---

## Testing it

1. Install the policy in **audit** mode (the **Test mode** button, or `Run-RmmAppControl.bat -Mode Audit`).
2. Close the remote tool if it is already running — App Control blocks new process starts and does not kill
   running ones.
3. Start the tool.
4. Open **Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → Operational** and
   look for event **3076**.
5. Press **BLOCK**, close the tool, start it again — you should get event **3077** and the program should not run.

Note that these events carry the **policy ID, not the policy name**, which is why the status view filters on the
GUID. More detail, including a safe way to trigger a policy check without actually running a tool, is in
[`docs/testing.md`](docs/testing.md).

---

## Limits — read this before you rely on it

- **Unsigned tools are not covered.** App Control here works by certificate, so an unsigned or self-signed
  remote tool gets through. The ESET "potentially unsafe applications" toggle is the backstop.
- **Windows Home is untested.** App Control on Home editions is claimed by third parties but this project has not
  verified it. If you deploy to a Home PC, run **audit** mode first and confirm events appear.
- **The v.3 RustDesk block has not been observed on a PC yet.** The rules were verified against the real RustDesk
  installer's certificate by inspection, and all 32 compiled policies were validated, but no live RustDesk block
  has been recorded. Test it in audit mode.
- **The window buttons have not been clicked by an automated test.** Each window opens and was inspected, but the
  BLOCK/UNDO/Test buttons need administrator rights and were exercised by hand, not automatically. They call the
  same install script that *was* verified.
- **The ESET website paste is manual and a technician MUST do it by hand.** ESET's URL list import is not
  scripted, and the tool cannot verify it happened.
  See [The ESET paste](#the-eset-paste--must-be-done-by-hand-by-a-technician)
  and [`docs/eset-import-guide.md`](docs/eset-import-guide.md).
- **The ESET website list only covers HTTP/HTTPS**, and HTTPS needs ESET's SSL/TLS filtering enabled. A tool that
  is already installed and connects over its own protocol may still connect.
- **Vendor certificates rotate.** Rebuilding periodically from the upstream catalogue keeps the list current; the
  publisher rules cover most renewals.

The upstream data source is **LOLRMM** (https://lolrmm.io, repo
[magicsword-io/LOLRMM](https://github.com/magicsword-io/LOLRMM), Apache-2.0), a catalogue of around 358 RMM and
remote-access tools including each one's code-signing certificates.

---

## Configuration

Two deployment-specific values are named constants, near the top of their scripts. Change these (and nothing else)
to brand the tool for your own shop:

| Constant | File | Purpose |
|---|---|---|
| `$PolicyName` | `src/appcontrol/Build-RmmAppControl.v2026-10-11.3.ps1` | Friendly name written into every generated policy |
| `$LogDirName` | `src/appcontrol/Install-RmmAppControl.v2026-10-11.3.ps1` | Folder created under `%ProgramData%` for the log file |

**Do not change the policy GUID.** PCs that already carry this policy are keyed to it; a different GUID would
install a second policy alongside the first instead of replacing it. Changing it knowingly requires a migration
step that removes the old policy — that is not automated here.

To change the default toggles (for example to block Splashtop out of the box), edit the default variant in
`Build-RmmAppControl` and rebuild, or simply untick Splashtop in the window before pressing BLOCK and let it
reinstall.

---

## Rebuilding the policy

The pre-built policies in `policy/` are committed, so ordinary use needs nothing else. Rebuild when you want to
pick up new tools or refreshed certificates.

Requires **Windows 10/11 Pro or Enterprise** (the ConfigCI module) and PowerShell 5.1:

```powershell
# from the repo root, in an elevated PowerShell
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1 -IncludeOptional        # add school/enterprise vendors
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1 -ExcludeSigner "Vendor Name"
```

Then install the result:

```powershell
.\src\appcontrol\Run-RmmAppControl.bat -Mode Enforce -Variant T1A1S0R1
.\src\appcontrol\Run-RmmAppControl.bat -Mode Audit
.\src\appcontrol\Run-RmmAppControl.bat            # status (default)
```

Vendor names for `-ExcludeSigner` are the `Publisher` column in `policy/signers.csv`. PCs that cannot rebuild
(a Home PC) just need the rebuilt `policy/` folder copied next to them.

---

## Safety

What this deliberately does **not** touch:

- the kernel/driver signing scenario — only user-mode code is restricted;
- script enforcement — PowerShell is not put into Constrained Language Mode;
- any other App Control policy on the machine.

It is reversible: **UNDO** in the window, or

```powershell
.\src\appcontrol\Run-RmmAppControl.bat -Mode Remove
```

then restart. That removes the policy this project installed and nothing else.

---

## Repository layout

```
src/appcontrol/    Build- / Install- / Run-RmmAppControl   (ONE shared copy, used by both kits)
src/eset/          Get-LolrmmUrlList  (website list)  and Get-LolrmmHipsList  (experimental path list)
kits/full/         START-HERE.bat + RmmBlocker window   (App Control + ESET website list)
kits/windows-only/ Remote-Tools-Block-Windows.bat + window (App Control only)
revert/            Run-Revert.bat + Revert-RemoteAccessBlock  (standalone undo/restore tool)
policy/            the prebuilt policies - 32 toggle combinations + signers.csv (generated output)
docs/              how-it-works, eset-import-guide, testing, CHANGELOG
archive/           the original ESET HIPS prototype, kept for history
```

The scripts resolve the folders relative to themselves, so the repo layout works in place and a built release ZIP
(which lays the scripts out side by side) works standalone.

The revert tool follows the same rule in two ways: the kit resolves it either from `revert\` (repo) or from the
loose files beside the installer (release ZIP), and once installed on a PC it resolves everything — its own scripts,
the guide and the policies — from `C:\RemoteAccessToolBlocker\` alone.

Scripts deployed to other machines carry their version in the filename — `Name.vYYYY-MM-DD.N.ps1`. The `.bat`
launchers auto-detect the newest with `dir /b /o-n`, so superseded versions can be removed once a new one works.

**`policy/` is generated output.** It is committed because Windows Home PCs cannot build it themselves; it is
rebuilt by `Build-RmmAppControl`.

---

## Credits

- **[LOLRMM](https://lolrmm.io)** ([magicsword-io/LOLRMM](https://github.com/magicsword-io/LOLRMM), Apache-2.0) —
  the catalogue of remote-access tools and their code-signing certificates. The policies, the signer list and the
  ESET website lists in this repository are derived from its data. See [`NOTICE`](NOTICE).
- **Microsoft** — the `AllowAll.xml` example policy and the documented recommended-block-rules layout this policy
  is built on.
- The **RustDesk** signing certificate is not in LOLRMM. It was taken from the official RustDesk Windows build
  and is embedded in the builder. See [`NOTICE`](NOTICE).

---

## Disclaimer

Provided as-is, without warranty of any kind. **Test in audit mode first** and confirm the events before you
enforce, particularly on Windows Home and with RustDesk. Blocking a remote-access tool may cut off your own
support access to that PC — check every toggle before you press BLOCK.

This project is not affiliated with, endorsed by, or supported by ESET, Microsoft, or any of the vendors named.
All trademarks belong to their respective owners.

Licensed under the **Apache License 2.0** — see [`LICENSE`](LICENSE).
