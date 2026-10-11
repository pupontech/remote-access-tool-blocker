# eset-hips-poc - automation of the LOLRMM / ESET Owner Test Kit (Phase 1)

Handoff doc: what was done, why, and how to run it. Written 2026-10-07 by Claude (Sonnet 5.5).

## Context
The kit (`Downloads\LOLRMM-ESET-Owner-Test-Kit`) is a Phase 1 evidence-prep kit. It contains a harmless
`LolrmmEsetTest.exe` (prints "Test Application", exits 0) and `OWNER-RUN.md`, a manual procedure:
export ESET config -> add ONE manual HIPS block rule for that exact exe -> test -> check HIPS log -> remove
rule -> export again -> re-test. It is NOT the finished RMM-blocking tool and must not import XML, widen rules,
disable protection, or collect passwords.

## What I did (in order)
1. Read START-HERE.txt, OWNER-RUN.md, RESULTS.txt, SHA256SUMS.txt.
2. Verified all 5 kit files against SHA256SUMS.txt - all OK.
3. Inspected this machine (read-only): Windows 11 Pro 25H2 build 26200.9457; **ESET Security 19.2.10.0**
   (product name is "ESET Security", NOT "Ultimate" - the guide's documented target - so this is a
   *compatibility candidate*; stop if the HIPS UI differs); `ekrn` running;
   `ecmd.exe` = `C:\Program Files\ESET\ESET Security\ecmd.exe`; session not elevated.
4. **Attempted** to create folders, copy the exe, and launch an elevated `ecmd /getcfg` export in one command.
   The auto-mode classifier **denied** it ("Code from External"). I did not retry or work around it;
   nothing was created or run. I told the user and gave manual commands.
5. User then asked for more automation. I wrote the files in this folder (nothing executed):
   - `Invoke-EsetHipsPoc.v2026-10-07.1.ps1` - guided end-to-end script
   - `Run-EsetHipsPoc.bat` - self-elevating launcher; auto-detects newest `.v*.ps1` (repo versioning convention)
   - this README

## What the script automates
Hash check -> private folders with ACL (`%LOCALAPPDATA%\LOLRMM-POC\<date>`, `%USERPROFILE%\LOLRMM-Evidence\<date>`)
-> copies the exact exe -> captures env (Windows, ESET version, ecmd path) -> `ecmd /getcfg` x3
(`baseline.xml`, `with-manual-rule.xml`, `after-removal.xml`) -> launches the exe as the **normal (non-elevated)
user** via a one-shot Limited scheduled task, capturing stdout + exit code (pre-rule, with-rule, post-removal)
-> XML diffs (baseline vs rule shows the added lines; baseline vs after-removal proves only the test rule was
removed) -> writes `sanitized-rule-diff.txt` (username/profile replaced with `<USER>`) -> auto-fills `RESULTS.txt`.

## What stays manual (deliberately)
- Creating and removing the single HIPS rule in the ESET UI (script prints exact field values + exe path and
  pauses). Programmatic rule insertion/import is explicitly out of scope until later Phase 1 gates.
- Reading Tools > Log files > HIPS (not exposed via ecmd/Windows event log) and noting any notification.
- Answering HIPS-enabled / ESET CMD mode prompts (no passwords).

## Safety behaviors
Stops on: not elevated, hash mismatch, missing ecmd, HIPS disabled, any failed export. Warns if no XML change
after rule save, if the exe still runs with the rule, or if the exe name remains in `after-removal.xml`.
Never imports config, never edits ESET settings, never touches other rules.

## How to run
Double-click `Run-EsetHipsPoc.bat` (accept UAC), or `Run-EsetHipsPoc.bat -KitDir <path>` if the kit is elsewhere.
Windows-only by nature (ESET + Windows APIs); PowerShell 5.1, ASCII only. **Not yet executed or tested** -
first run is the test; review any warning it prints.

## Sharing
Share only `RESULTS.txt` and `sanitized-rule-diff.txt`. Keep `*.xml` and logs private in the evidence folder.

## Known gaps / next
- Untested script; the scheduled-task launcher assumes an interactive logged-on user (`Win32_ComputerSystem.UserName`).
- If the HIPS rule UI differs on "ESET Security" vs "Ultimate", record differences and stop.
- Not added to CLAUDE.md or committed (user hasn't asked; skills/CLAUDE.md are the auto-sync scope).
