
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
| **Windows App Control** (WDAC) deny policy — **program `1`** | The *programs*, wherever they are — renamed, email attachment, Downloads, USB | Fully scripted | Scripted (+ restart) |
| **ESET web filter** ("List of blocked addresses") — **program `2`** | The tools' *websites* — download pages and web consoles | Generated list, **pasted by hand** into ESET | By hand in ESET |
| **ESET "potentially unsafe applications"** | Known remote tools, flagged by ESET itself | One manual toggle | Toggle off |

The App Control layer is the load-bearing one. The ESET layers are optional extras for PCs that run ESET.

---

## Quick start

The full kit is **two separate programs**, in two folders:

| Folder | Program | What it does | Needs |
|---|---|---|---|
| **`1\`** | `START-HERE.bat` | Blocks the remote-access **programs** (AnyDesk, TeamViewer, ScreenConnect …) with Windows App Control | Administrator. No antivirus. |
| **`2\`** | `START-HERE.bat` | Builds the list of the tools' **websites** and opens ESET + the paste guide | **ESET installed.** No admin needed. |

They are independent — run either one, or both. Neither needs the other.

1. Download the release ZIP you want:
   - `remote-tools-block-windows-<version>.zip` — the program blocker only. No antivirus needed. **Start here.**
   - `full-kit-eset-<version>.zip` — both programs, as folders `1` and `2`.
2. Extract it anywhere on the PC. Keep the folders together — the launchers find the scripts relative to themselves.
3. **Program 1:** open folder **`1`**, double-click **`START-HERE.bat`** and accept the administrator prompt.
4. **TeamViewer, AnyDesk and RustDesk start ticked (blocked); Splashtop starts unticked (allowed)** on a fresh PC. Ticked = blocked. Untick a tool the client really uses. An existing program policy still loads its installed choices.
5. Press **BLOCK**.
6. **Program 2 (only if the PC runs ESET):** open folder **`2`**, double-click **`START-HERE.bat`**, press
   **BUILD**, then **import the file into ESET BY HAND** — the program cannot do it and cannot verify it.
   See [The ESET paste](#the-eset-paste--must-be-done-by-hand-by-a-technician).

When program 1 applies the block it also copies a **standalone undo tool** to
`C:\RemoteAccessToolBlocker` on that PC — see [Undoing it later](#undoing-it-later). It is there so the block can
be reverted later without the original kit, the network, or this repository.

To undo immediately: **program 1** → press **UNDO**, then restart the PC. **Program 2** → take the website list
back out of ESET by hand, following the guide.

The status line always shows the current state — **PROTECTED**, **TEST MODE** or **NOT protected** — and what each
toggle is set to. **Refresh status** lists recent events: `[3077]` means a program was blocked, `[3076]` means one
*would* have been blocked (audit mode).

### The ESET paste — **MUST BE DONE BY HAND BY A TECHNICIAN**

> ## ⚠️ THIS STEP CANNOT BE AUTOMATED. A TECHNICIAN MUST DO IT BY HAND.
>
> The **BLOCK** button does everything else itself. It **cannot** add the website list to ESET: ESET's URL list is
> a GUI import/paste with no scriptable interface, and this project deliberately does not guess at ESET's
> configuration XML. **A technician must import the file into ESET by hand, following the steps below.**
>
> **Do not skip this step and do not assume it happened.** Until it is done, the ESET website layer of the block is
> not active — the programs are still blocked by Windows App Control, but the tools' download sites and web
> consoles are not.

**Program 2 BUILD** writes one combined file, `eset-blocked-urls.txt`, opens its folder with the file selected, opens the list itself in Notepad alongside the instructions, and copies the **full file path** to the clipboard (not the list contents). The path is also printed in the window. **Open the list folder** reopens it without rebuilding.

Both programs, and the Windows-only kit, start with TeamViewer, AnyDesk and RustDesk ticked (blocked) and Splashtop unticked (allowed). Their checkboxes are independent. Program 1 loads installed choices when an existing policy is detected.

**Review before import:** the combined list now includes previously optional AV-update, SaaS and VPN domains. Review optional-tier rows in `url-review.csv` and remove services the client needs from the import file. The protected-root and allow-domain safety filters remain active. There is no second optional import file.

1. In ESET, press **F5** -> **Protections** -> **Web access protection** -> **URL list management** -> **Address list / Edit**.
2. Add a new list of type **Blocked**, named **RMM scam block (lolrmm)**, with **List active** ticked.
3. Inside it choose **Import**. Paste the copied **file path into File name**, then **Open**. If clipboard copy failed, browse to the file in the folder that opened. Do not paste the path into **Enter multiple values**.
4. Click **OK** on every window to save.
5. Test a website that actually appears in the generated file, for example `anydesk.com` if AnyDesk was left ticked.

To undo, remove this named list or untick **List active**. Do not remove unrelated pre-existing entries. Program 2 does not apply the Windows program block or verify ESET import; use program 1 independently.

See [`docs/eset-import-guide.md`](docs/eset-import-guide.md) and the guide that opens in Notepad.

### Undoing it later

**Program 1** installs the undo tool to `C:\RemoteAccessToolBlocker` on the PC when it applies the block, so the
block can be removed later without the original kit, the network, or this repository. It installs the **ESET-free**
variant — program 1 blocks only programs, so it must never hand out ESET removal steps.

```
C:\RemoteAccessToolBlocker\
  Run-Revert.bat                          <- double-click this
  Revert-RemoteAccessBlock-WinOnly.ps1    (App Control removal only, ESET-free)
  README.txt
  policy\                                 (the built policies, so it can put the block back)
  backups\                                (created by the first revert)
```

**Program 2** installs the **ESET-aware** variant to the same folder when it builds a list — that is what adds the
ESET removal steps and the guide:

```
C:\RemoteAccessToolBlocker\
  Revert-RemoteAccessBlock.ps1            (also handles the ESET website list)
  docs\eset-remove-guide.txt
  README.txt
```

Whichever program ran last owns the variant: program 2 **removes** the ESET-free copy when it installs the full one,
so exactly one variant is ever present and the tool always matches what was actually blocked on the PC. A PC that
only ever ran program 1 therefore never sees an ESET step.

Because that folder is a permanent, scriptable tool sitting on the machine, note what it is: it lets anyone with
local administrator rights undo the block. That is deliberate — the alternative is a PC you cannot un-block without
hunting down the original kit.

### Two variants, matching what actually ran on the PC

The variant installed is chosen by which program put it there, because a PC that only ran program 1 (or the
Windows-only kit) has no ESET layer and must never be told to go un-block something that was never blocked:

| Program used | Variant installed | Behaviour |
|---|---|---|
| **Program 1** (and the **Windows-only** kit) | `Revert-RemoteAccessBlock-WinOnly.v*.ps1` | App Control removal only. **Never touches ESET** — no ESET window, no ESET steps, no guide, and it does not even read the `LOLRMM-UrlList` folder. |
| **Program 2** (the website list) | `Revert-RemoteAccessBlock.v*.ps1` | Removes the policy *and* walks you through taking the website list back out of ESET. |

Program 2 **removes** the ESET-free variant when it installs the full one, so exactly one variant is ever present
and it always matches what was blocked. Both variants are generated from one source, so they cannot drift.

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
what would have been. Run the program you expect to be blocked, then **Refresh status** and confirm you see a `3076`
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

## Customizing what gets blocked (with an AI agent)

You can ask a coding agent (Claude Code, Codex, Copilot and similar) to change what is blocked and what is
allowed. This section has the prompts and the file map it needs, so it can make the change without exploring the
repo first. **Point the agent at this section** ("read the README section *Customizing what gets blocked* first").

### Prompts you can copy

Replace the parts in `<angle brackets>`.

```text
Read README.md "Customizing what gets blocked" first. Then:
Stop blocking <ScreenConnect> programs everywhere. Rebuild policy/ and show me the report.
```

```text
Read README.md "Customizing what gets blocked" first. Then:
Also block <Ping32> - programs and websites. Tell me if the catalogue has no certificate for it.
```

```text
Read README.md "Customizing what gets blocked" first. Then:
Never block these websites, our clients use them: <tailscale.com, sophos.com>.
```

```text
Read README.md "Customizing what gets blocked" first. Then:
Make <Splashtop> blocked by default in every kit (it stays a per-PC checkbox).
```

```text
Read README.md "Customizing what gets blocked" first. Then:
Go through the "Vendors that need a decision" in the latest lolrmm-watch PR / report and propose
main, optional or leave-alone for each one, with a one-line reason. Don't change anything until I answer.
```

### Agent reference

**Two layers, configured separately.** Allowing a tool usually means changing **both**.

- **Program 1 (App Control):** blocks programs by their code-signing certificate. Its output, `policy/`, is
  committed and has to be rebuilt.
- **Program 2 (ESET):** blocks websites. The list is generated on the technician's PC when they press BUILD.

Script filenames carry a version (`Name.vYYYY-MM-DD.N.ps1`). Glob for them (`src/appcontrol/Build-RmmAppControl.v*.ps1`)
and do not rename them for a list-only edit.

#### Where each setting lives

| Goal | File | What to change |
|---|---|---|
| **Block a vendor's programs** | `src/appcontrol/Build-RmmAppControl.v*.ps1` | Add the signer name to `$MainSigners` |
| Block only with `-IncludeOptional` (vendor also signs software clients need) | same | Add it to `$OptionalSigners` |
| **Stop blocking a vendor's programs** | same | Remove it from `$MainSigners` (or move it to `$OptionalSigners`) |
| Never block a publisher, whatever the lists say | same | Add part of its certificate CN to `$NeverBlock`, in lower case with spaces and punctuation removed (for example `simontatham`) |
| Default toggle state for a policy **build** | same | `$DefaultVariant` (`T1A1S0R1` = TeamViewer, AnyDesk, RustDesk blocked; Splashtop allowed) |
| **Default checkbox state** in the windows | `kits/1/Block-The-Programs.v*.ps1`, `kits/2/Block-The-Websites.v*.ps1`, `kits/windows-only/Remote-Tools-Block-Windows.v*.ps1` | The last argument of `New-Chk '<Tool>' <x> $true` (`$true` = ticked = blocked). All three currently start TeamViewer, AnyDesk and RustDesk ticked and Splashtop unticked, matching `$DefaultVariant`. Change all three together, plus `$DefaultVariant` and the assertion in `tests/Test-ImportWorkflow.ps1`, which checks the three agree. |
| **Block extra websites** | `src/eset/Get-LolrmmUrlList.v*.ps1` | Add the domain to the `$ExtraDomain` default |
| **Never block a website** (this domain and everything under it) | `kits/2/Block-The-Websites.v*.ps1` | Add it to `$allow = @('eset.com')` in the BUILD handler. Also add it to the `$AllowDomain` default in `Get-LolrmmUrlList` for command-line runs. **Kit 2 passes its own allow-list, which replaces the generator's default.** |
| Leave a tool's websites out completely | `kits/2/Block-The-Websites.v*.ps1` | Add the tool's name to `$exTools`. It matches catalogue names with `-like *name*`. |
| Mark a domain as *review before import* | `src/eset/Get-LolrmmUrlList.v*.ps1` | `$OptionalDomain`. It **is still in the import file**; it is only flagged in `url-review.csv`. |
| Never block a shared platform root (CDNs, cloud hosts) | same | `$ProtectedRoot` |

A new per-PC checkbox (a fifth toggle like `T`/`A`/`S`/`R`) is **not** a quick edit. It changes `$ToggleGroups`,
all three windows, the variant naming and the 32 prebuilt variants in `policy/variants/`. Ask for a plan first.

#### Looking up the exact names

Signer names must match the certificate. The comparison ignores case and punctuation, but not wording.

| You need | Look in | Column |
|---|---|---|
| Signers already blocked | `policy/signers.csv` | `Publisher` (`Tools` shows the tools they cover) |
| Signers in the catalogue but not blocked, and why | `data/lolrmm-baseline/skipped-signers.csv` | `Signer`, `Reason` |
| Every tool name in the catalogue | `data/lolrmm-baseline/tools.txt` | one name per line |
| Every website entry, its tier and the tools behind it | `data/lolrmm-baseline/url-review.csv` | `Entry`, `Tier`, `Tools` |

What the `Reason` values in `skipped-signers.csv` mean:

- `not on the hand-checked vendor list`: adding the signer to `$MainSigners` will block it.
- `optional vendor (use -IncludeOptional)`: it is already in `$OptionalSigners`.
- `catalogue has no certificate bytes`: **adding it does nothing.** No rule can be built until LOLRMM publishes
  the certificate. The only option is its websites.
- `never-block safety list (...)`: `$NeverBlock` stopped it. Do not work around this without asking.
- `certificate CN does not match the listed vendor`: the catalogue attached someone else's certificate to the
  tool. Leave it alone.

#### Rebuild and verify: one command

After editing any of the lists above, run this from the repo root in Windows PowerShell 5.1. It needs Windows
10/11 Pro or Enterprise, or Windows Server, because of the ConfigCI module.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\Update-LolrmmBaseline.ps1 -Force -ReportPath .\lolrmm-report.md
```

The command:

- runs both generators against the live catalogue;
- rebuilds `policy/` only when the deny rules changed, putting the output in the right folder;
- refreshes `data/lolrmm-baseline/`;
- writes a report of exactly what the edit added and removed: rules, blocked websites and unreviewed signers.

**Read the report.** If a change you expected is missing, the name did not match. Check it against the tables
above.

Add `-SkipPolicy` on a PC without ConfigCI to check only the website list. Do not commit `lolrmm-report.md`.

#### Before you commit

- `.ps1` files must be **pure ASCII with no BOM**. Windows PowerShell 5.1 misreads anything else. `.bat` files must
  be ASCII with CRLF line endings. CI enforces both.
- Commit the script edit together with `data/lolrmm-baseline/`, plus `policy/` when it was rebuilt.
- If `policy/` changed, add a `docs/CHANGELOG.md` entry, bump `VERSION`, and test on a PC in **Audit** mode
  before Enforce.
- Website-list edits reach technicians only in a new release ZIP (`build/build-release.sh`).
- Never change `$PolicyGuid` (see [Configuration](#configuration)).

The weekly `lolrmm-watch` workflow runs the same script without `-Force`. It opens a pull request when LOLRMM
itself changes, and its "Vendors that need a decision" list is the usual starting point for the last prompt above.

---

## Rebuilding the policy and the release ZIPs

The pre-built policies in `policy/` are committed, so ordinary use needs nothing else. Rebuild when you want to
pick up new tools or refreshed certificates.

To rebuild the **release ZIPs** (both kits, with the `1\`/`2\` split asserted on the result):

```bash
./build/build-release.sh          # writes dist/*.zip + .sha256
```

Requires **Windows 10/11 Pro or Enterprise** (the ConfigCI module) and PowerShell 5.1:

```powershell
# from the repo root, in an elevated PowerShell. Without -OutDir it writes to src\appcontrol\policy, not policy\
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1 -OutDir .\policy
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1 -OutDir .\policy -IncludeOptional        # add school/enterprise vendors
.\src\appcontrol\Build-RmmAppControl.v2026-10-11.3.ps1 -OutDir .\policy -ExcludeSigner "Vendor Name"
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
kits/1/            START-HERE.bat + window   (PROGRAM 1: the App Control program blocker)
kits/2/            START-HERE.bat + window   (PROGRAM 2: the ESET website list)
kits/windows-only/ START-HERE.bat + window (App Control only, one window)
revert/            Run-Revert.bat + Revert-RemoteAccessBlock (both variants) + Install-ESET-Revert
policy/            the prebuilt policies - 32 toggle combinations + signers.csv (generated output)
build/             build-release.sh - builds BOTH release ZIPs and asserts the 1\/2\ split on them
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

Open list: reopen the existing eset-blocked-urls.txt in Notepad without rebuilding it. If no list exists, press BUILD first.
