# ESET website import (manual)

Program 2 builds one combined `eset-blocked-urls.txt`, copies its full file path to the clipboard, opens its folder with the file selected, and opens the list itself in Notepad alongside the instructions. It does not copy the website entries or automatically change ESET.

TeamViewer, AnyDesk, Splashtop and RustDesk start unticked (allowed). Tick a tool before BUILD to include it. Program 1 controls the Windows program policy separately and loads an existing policy's choices when available.

## Review first

The combined list includes previously optional domains used for AV updates, SaaS and VPN services. Review optional-tier entries in `url-review.csv` and remove services the client needs from `eset-blocked-urls.txt`. Protected shared-platform roots and allow-domain exclusions still apply. A rebuild removes the old `eset-blocked-urls-optional.txt`; there is only one import list. Other CSV/text files are review reports, not additional import lists.

## Import

1. In ESET press F5 -> Protections -> Web access protection -> URL list management -> Address list / Edit.
2. Add a new Blocked list named `RMM scam block (lolrmm)` and leave List active ticked. If your ESET does not allow a named list, edit List of blocked addresses instead.
3. Inside the list choose Import. Paste the copied **file path into File name**, then Open. If clipboard copy failed, browse to the file in the opened folder. **Do not paste the file path into Enter multiple values.**
4. OK on every window to save. The program cannot verify this step.
5. Test a website actually in the generated list. AnyDesk is allowed by default and is not a default test target.

## Undo

Remove `RMM scam block (lolrmm)` or untick List active. Do not remove unrelated pre-existing entries from a shared built-in list. Program 2 does not change Windows App Control; use program 1 for the separate program block.

## Files

- `eset-blocked-urls.txt`: the single UTF-8 import file, one mask per line.
- `url-review.csv`: entry, tier and source tool(s); review before import.
- `website-candidates.csv`: websites not automatically blocked.
- `skipped.csv`, `ips.txt`, `summary.txt`: diagnostic/reference output, not import lists.

The window writes to `%USERPROFILE%\LOLRMM-UrlList\latest`. The standalone generator defaults to a timestamped directory and accepts `-OutDir`, `-ExcludeTool` and `-AllowDomain`.
