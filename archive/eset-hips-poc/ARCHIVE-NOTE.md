# archive/eset-hips-poc — historical prototype

**Not part of the current tool.** Kept for context; superseded in full.

This was the first phase of the project (2026-10-07): a guided script that automated the evidence-gathering steps
around a **manual** ESET HIPS rule test. It verified kit hashes, created private evidence folders, exported ESET's
configuration with `ecmd /getcfg` before and after a hand-added rule, ran a harmless test executable in a
non-elevated context via a one-shot scheduled task, diffed the XML exports, and wrote a sanitized result file.
Creating and removing the rule itself stayed manual by design.

It was written against a specific external test kit and a specific lab PC. Paths and machine names in these files
have been reduced to placeholders for publication; the procedure evidence is historical, not reproducible without
that kit.

**Superseded by:** the Windows App Control layer in `src/appcontrol/`, which blocks by code-signing certificate
instead of by file path, and therefore also catches portable, renamed and email-attachment copies that HIPS path
rules cannot.

Its sibling, `src/eset/Get-LolrmmHipsList.v2026-10-08.1.ps1`, is the later HIPS path-list generator. It is still
shipped, marked experimental, and is not wired into either kit window.

The original directory README has been kept verbatim as `README-original.md`, with a note added at the top about
its status. Its assertions about testing apply to *this* prototype only — the current tool's verified and
unverified surface is documented in [`docs/testing.md`](../../docs/testing.md).