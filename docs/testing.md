# Testing

How to confirm the block actually works, and what has and has not been proven on real hardware.

**Golden rule: test in audit mode first.** Audit logs what *would* be blocked and blocks nothing. Confirm the
events, then enforce.

---

## The two events

| Event | Meaning |
|---|---|
| **3076** | A program *would* have been blocked (audit mode) |
| **3077** | A program **was** blocked (enforce mode) |

Both are written to:

**Event Viewer → Applications and Services Logs → Microsoft → Windows → CodeIntegrity → Operational**

**These events carry the policy ID, not the policy name.** To filter them by hand, search the event text for:

```
2d13bfb7-4304-4847-9cdd-37820d3ee9b7
```

The tool does this for you — **Refresh status** filters on the GUID and lists the last 14 days.

---

## Walkthrough

1. Install in audit mode:
   - the **Test mode** button in either window, or
   - `Run-RmmAppControl.bat -Mode Audit`
2. **Close the remote tool if it is already running.** App Control blocks new process starts; it does not kill
   running ones. A tool already open will keep running.
3. Start the tool.
4. **Refresh status** (or check Event Viewer). You want a `[3076]` naming that file.
5. Now press **BLOCK** (or `-Mode Enforce`).
6. Close the tool, start it again. It should fail to start, and you should get a `[3077]`.

### Safe trigger without running the tool

If you want to prove the policy is live without executing the executable:

```powershell
# starts the image, suspends it immediately, then kills it: the image load is
# evaluated (3076/3077 logged) but no code from it ever runs
Add-Type -Namespace W -Name N -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern bool CreateProcess(string a, string b, IntPtr c, IntPtr d, bool e,
    uint f, IntPtr g, string h, ref STARTUPINFO i, out PROCESS_INFORMATION j);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool TerminateProcess(IntPtr h, uint c);
[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
public struct STARTUPINFO { public int cb; public string r1, r2, r3; public int x, y, xs, ys, xc, yc, fill, flags; public short s1, s2; public IntPtr r4, r5, r6; }
[StructLayout(LayoutKind.Sequential)]
public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int pid, tid; }
'@
$si = New-Object W.N+STARTUPINFO; $si.cb = [Runtime.InteropServices.Marshal]::SizeOf($si)
$pi = New-Object W.N+PROCESS_INFORMATION
[void][W.N]::CreateProcess($null, 'C:\path\to\tool.exe', [IntPtr]::Zero, [IntPtr]::Zero, $false,
    0x00000004, [IntPtr]::Zero, $null, [ref]$si, [ref]$pi)   # CREATE_SUSPENDED
[void][W.N]::TerminateProcess($pi.hProcess, 1)
```

The image load is evaluated, so the event is written — but the suspended process never executes a single
instruction of the tool.

---

## Reading the status view

`Run-RmmAppControl.bat` with no arguments shows:

- the PC name, OS caption and build number;
- whether the policy is installed, its friendly name, version, `IsEnforced` and mode (audit vs enforce);
- which toggles are set, read back from the policy name;
- recent 3076/3077 events for this policy.

The same information appears in the status line of both windows: **PROTECTED**, **TEST MODE**, **NOT protected**,
or "installed — restart the PC to activate" on older builds that need one.

---

## What has been verified, and how

### Verified on a real PC

Windows 11 Pro build 26200, ESET Security 19.2.10, with the earlier three-toggle policy:

- The policy loads — CodeIntegrity 3099, `Status 0x0`.
- Audit mode logged **3076** for `AnyDesk.exe`, `TeamViewer_Setup_x64.exe` and `ScreenConnect.ClientSetup.exe`
  (plus the ScreenConnect MSI temp files).
- Enforce mode: the user confirmed **AnyDesk did not start**, and CodeIntegrity logged **3077** for `AnyDesk.exe`.
- **No** 3076/3077 events for anything other than remote tools.
- The ESET URL list import worked — `anydesk.com` showed ESET's block page.

### Verified by build and inspection only — NOT run on a PC

- **The v.3 policies with the RustDesk toggle.** The rules match the real RustDesk installer's certificate (leaf
  and publisher), and all 32 policies compiled and round-tripped through `ConvertFrom-CIPolicy`.
  **A RustDesk block has not been observed.**
- **The window buttons** (BLOCK / UNDO / Test mode) in both windows. Each window opens, but the buttons need
  administrator rights and were not clicked by an automated test. They call the same install script that *was*
  verified end to end.
- **Windows Home.** App Control on Home editions is claimed by third parties but is **untested here**. Run audit
  mode on one Home PC first.
- **The ESET "Add list" button** — the button used to create a separate address list is documented by ESET but was
  not checked in the UI on the test machine.
- **The revert tool never removes a real policy on real hardware.** Its *removal* path (`CiTool --remove-policy`,
  the `CiPolicies\Active` delete, opening ESET) is the same code path as the already-verified `-Mode Remove`, but
  the tool itself has only been exercised on Linux with stubbed Windows surfaces. Its file-handling logic — the
  backup, the restore listing, the copy into `C:\RemoteAccessToolBlocker` — **has** been executed end to end and
  verified on disk (see below).

### The revert tool: what was actually executed

Not a source-only review. The following were run against the real shipped scripts with synthetic
directories standing in for Windows paths:

| Checked by execution | Result |
|---|---|
| Kit copies the undo tool from the **repo layout** (`revert\`) | 4 items copied, guide and 32 variants land |
| Kit copies it from an **extracted release ZIP** (loose files) | 3 items copied, 71 policy files, 32 variants |
| Policies land at `policy\variants\*.cip`, not double-nested | verified on disk |
| A second install **backs up** the previous backups instead of clobbering | dated `.backup-*` sibling created, sentinel file preserved byte-for-byte |
| Missing revert files → skips gracefully, no throw, no empty folder | verified |
| `-WhatIf` cannot reach either removal call | every destructive call sits inside the `else` of the dry-run guard |
| `-RemoveFolder` refuses anything not named `RemoteAccessToolBlocker` | 5 path shapes tested, including `…\RemoteAccessToolBlockerXYZ` and a nested subfolder |
| The installed copy is **self-sufficient** | its guide, README, 32 variants and `$PSScriptRoot`-relative paths all resolve with no kit present |

Three real defects were found by running this rather than reading it: the kit layout was never detected (the
resolver looked for a *folder* named `revert`, which a release ZIP does not have), the ESET guide never copied,
and the policies landed double-nested because `-LiteralPath` does not expand a `*` glob — leaving an empty folder
and no working `policy\variants\`.

### Known noise, not a defect

CodeIntegrity **3033** events about ESET's `eamsi.dll` in `svchost` existed on the test PC **before** the policy was
installed. They are not caused by this policy. If you see them, they are unrelated.

---

## Common causes of "it did not block"

1. **The tool was already running.** App Control only blocks new process starts. Close it completely, including
   tray icons, then start it again.
2. **You are in audit mode.** `[3076]` means "would have blocked". Press **BLOCK** to enforce.
3. **The policy was installed on a pre-22H2 build and the PC has not been restarted.** The status view says
   "installed — restart the PC to activate".
4. **The tool is unsigned, or signed by a vendor not on the list.** See
   [Limits](../README.md#limits--read-this-before-you-rely-on-it).
5. **You filtered the event log by policy name.** The events carry the GUID instead.

---

## Checking the Log

Install, remove and status actions all append to:

```
%ProgramData%\<LogDirName>\RmmAppControl.log
```

`<LogDirName>` defaults to `RemoteAccessToolBlocker` and is a named constant at the top of
`Install-RmmAppControl`. The log records the action, the resulting `CiTool` exit code and its output.