# Prompt: build a fully automated version of the LOLRMM / ESET Phase 1 test

Copy everything below the line into the other AI. Fill in the two [BRACKETED] spots first.

---

## Role and goal
You are a senior Windows/PowerShell engineer. Build a **single-command, fully automated, self-verifying**
version of the "LOLRMM / ESET Owner Test Kit" Phase 1 procedure. I own this machine; it is an isolated
test PC/VM (not production) with ESET installed. The goal is to prove, with minimal human interaction,
that one ESET HIPS block rule for ONE exact harmless executable can be created, enforced, logged, and
cleanly removed, with every other ESET setting provably unchanged.

## Environment (verified facts)
- Windows 11 Pro 25H2, build 26200.9457. PowerShell 5.1 (must stay 5.1-compatible, pure ASCII .ps1).
- ESET product: **"ESET Security" 19.2.10.0** (NOT "ESET Security Ultimate"; the kit's docs target Ultimate 19.2.x, so
  treat this as a compatibility candidate and detect/report any UI or XML difference).
- `ekrn` service running. `ecmd.exe` at `C:\Program Files\ESET\ESET Security\ecmd.exe` (FileVersion 10.67.16.0).
- Kit folder: `C:\Users\<user>\Downloads\LOLRMM-ESET-Owner-Test-Kit` containing `LolrmmEsetTest.exe`
  (prints "Test Application", exits 0), `OWNER-RUN.md`, `RESULTS.txt`, `SHA256SUMS.txt`, `START-HERE.txt`.
  Read all of them first; `OWNER-RUN.md` is the source procedure.
- Repo with an existing attempt: `<repo>\archive\eset-hips-poc\` (`Invoke-EsetHipsPoc.v2026-10-07.1.ps1`,
  `Run-EsetHipsPoc.bat`, `README.md`). **It was run and did not work.** Failure observed: [PASTE EXACT ERROR /
  WHERE IT STOPPED / WHAT YOU SAW]. Diagnose that first; do not assume the old design is right.
- Known tool constraint: an AI agent's elevated/external-code execution may be denied by the host's permission
  classifier. Design so a **human double-click (UAC accept) starts everything**, and the AI never needs elevation.

## The procedure to automate (from OWNER-RUN.md)
1. Verify kit hashes against SHA256SUMS.txt; stop on mismatch.
2. Create private local non-synced folders (run dir `%LOCALAPPDATA%\LOLRMM-POC\<date>`, evidence dir
   `%USERPROFILE%\LOLRMM-Evidence\<date>`), ACL: current user + Administrators only. Copy the exact exe.
3. Record environment: date/time/timezone, ESET product+version, Windows build, HIPS enabled?, ESET CMD
   enabled + authorization mode (never a password), ecmd path.
4. Elevated `ecmd.exe /getcfg <evidence>\baseline.xml`.
5. Add exactly ONE HIPS rule: name `LOLRMM POC TEST - LolrmmEsetTest`, Action Block, enabled, Operation
   "Start new application", Source "All applications", Target = the exact exe path (no folder/wildcard),
   logging + user notification on.
6. `/getcfg ... with-manual-rule.xml`. Launch the exe once as a NORMAL (non-elevated) user; record ran/blocked,
   exit code, notification, and the HIPS log entry (Tools > Log files > HIPS).
7. Remove only that rule; `/getcfg ... after-removal.xml`; launch exe again, expect "Test Application" + exit 0.
8. Fill RESULTS.txt; produce a sanitized minimal diff (replace username/profile with `<USER>`, only the rule's lines).

## What must become automated (the hard parts - research and decide, justify each choice)
A. **Rule creation/removal without clicking the UI.** The original guide did this manually and forbade guessing XML.
   Investigate, in this order, and pick the safest that works on 19.2.10:
   1. ESET's documented import path (`ecmd /setcfg <xml>`; check ESET CMD must be enabled, authorization mode, any
      required signing of the XML - ESET docs: help.eset.com/esu/19/en-US/idh_config_ecmd.html and
      idh_importexport_config.html). Derive the rule's XML by exporting, adding the rule by hand ONCE, exporting
      again and diffing - never invent XML. Insert it programmatically into a copy of baseline.xml with
      minimal structure change, preserve everything else byte-for-byte, then import.
   2. If import is blocked (ESET CMD off / password-protected / unsigned), fall back to **UI Automation**
      (System.Windows.Automation or UIAutomationClient in PowerShell, or a pywinauto script) driving
      Advanced setup > Protections > HIPS > Rules. Handle ESET running its GUI as a different integrity level.
   3. If neither is feasible, say so plainly and automate everything else, leaving only a single clearly
      prompted manual step.
   Never disable protection/Self-Defense, never touch other rules, never request or store the ESET password
   (if one is required, prompt for it securely at runtime, SecureString, in memory only).
B. **HIPS log verification.** ESET logs are not in the Windows Event Log. Investigate: `ecmd` log export options,
   the ESET log database under `C:\ProgramData\ESET\ESET Security\Logs`, or UI Automation reading
   Tools > Log files > HIPS. Parse for an entry at the test time naming the rule and "blocked".
C. **Normal-user launch from an elevated session** (must not run the test exe elevated). Use a Limited-token
   approach (scheduled task with Interactive principal + RunLevel Limited, or `runas /trustlevel`, or
   CreateProcess with a restricted token). Capture stdout and exit code robustly; wait for ESET's block.
D. **Block detection that does not infer from "no window".** Combine: launch error/exit code, absence of the
   "Test Application" output, the HIPS log entry, and (if possible) the ESET notification.
E. **Self-verification (the acceptance gate).** Automatically assert:
   - baseline vs with-rule differs by exactly the one rule's XML node;
   - after-removal vs baseline is identical, or differs only by a documented allowlist of volatile fields
     (timestamps/counters) - list which and why;
   - idempotency: running the "add rule" step twice yields one rule, not two;
   - exe blocked while rule present, runs (exit 0) after removal.
   Produce a pass/fail table and a nonzero exit code on any failure.
F. **Rollback safety.** A `finally`/trap path: if anything fails mid-run, detect whether the test rule exists and
   remove only it (re-verify via export), then report. Never leave the rule behind silently.

## Deliverables
1. `Run-EsetHipsPoc.bat` (self-elevating; auto-detects newest `Invoke-EsetHipsPoc.v*.ps1`; pushd/pause/exit-code).
2. `Invoke-EsetHipsPoc.v<YYYY-MM-DD>.<N>.ps1` - PS 5.1, ASCII only, no external dependencies unless justified;
   parameters for kit dir, rule name, and a `-DryRun` mode that does steps 1-4 and prints what it WOULD do.
3. Evidence output: `baseline.xml`, `with-manual-rule.xml`, `after-removal.xml`, run-*.txt, diffs,
   `sanitized-rule-diff.txt`, auto-filled `RESULTS.txt`, plus a machine-readable `result.json`.
4. A README: architecture, decisions (with rejected alternatives and why), how to run, how to roll back, what is
   still unverified. Include a short test plan and the exact commands you used to validate.
5. A written root-cause analysis of why the previous script failed and how the new one avoids it.

## Rules and guardrails
- Isolated test machine only; refuse to run if it looks like a production/domain-joined server (warn + require
  an explicit `-IAmOnATestMachine` switch).
- Only the one exact exe path; no wildcards, folders, or extra rules. No AV exclusions, HIPS allow rules, firewall
  rules, services, or Self-Defense changes.
- Full XML exports, raw logs, and any password stay local; only `RESULTS.txt` + `sanitized-rule-diff.txt` are
  shareable. Sanitize usernames/machine names.
- Stop (non-zero exit, clear message) on: not elevated, hash mismatch, HIPS disabled/missing, failed export,
  unexpected UI/XML shape, ambiguous result. Do not "fix" ambiguity by widening anything.
- Don't claim it works unless you actually ran it end-to-end on this machine and show the output. If you cannot
  run it (permissions), say exactly which steps are untested.
- Report honestly: what passed, what failed, what is assumed.

## First actions
1. Read the kit docs and the existing `eset-hips-poc` files; reproduce/diagnose the failure above.
2. Run the baseline export manually to confirm `ecmd` works and capture the XML structure.
3. Do the one-time manual rule add + export + diff to learn the real rule XML on THIS build.
4. Then design (explain the architecture in a few bullets), implement, test, and report.
