# ESET import guide — the manual step

The App Control layer is fully scripted. **Adding the website list to ESET is the one step you do by hand** —
ESET's URL-list import was never captured in a form that could be scripted safely, so the tool generates the file,
copies it to the clipboard and opens ESET for you.

This takes about a minute.

## Before you start

The **BLOCK** button has already:

- blocked the remote-access **programs** (Windows App Control);
- built the website block list — around 400 masks;
- **copied that list to the clipboard**;
- opened ESET and opened this guide in Notepad.

You are pasting that list into ESET now.

## Steps

Wording differs slightly between ESET versions.

1. Press **F5** to open Advanced setup.
2. Click **Protections** → **Web access protection**.
3. Open **URL list management**, then next to **Address list** click **Edit**.
4. **Make your own list** so that undo is one click later:
   - click **Add** — in the *Address list* window, **not** inside an existing list;
   - address list type: **Blocked**;
   - name: `RMM scam block (lolrmm)`;
   - leave **List active** ticked.

   > If your ESET has no **Add** button here, use ESET's built-in **List of blocked addresses** → **Edit**
   > instead. Undo then takes more work — see [Undo](#undo) below.
5. Inside that list, click **Add** → tick **Enter multiple values**.
6. Click in the box, press **Ctrl+V** to paste the whole list, click **OK**.
   *Or* use the **Import** button and choose `eset-blocked-urls.txt` in the folder that opened.
7. Click **OK** on every window, then **OK** in Advanced setup to save.

### Block the programs too (step 8)

App Control already blocks them by signature. This ESET toggle is the backstop for tools that are unsigned or that
ESET already knows about:

8. In Advanced setup, type `unsafe` in the search box and turn **ON** *"Enable detection of potentially unsafe
   applications"*. Click **OK**.

ESET then flags known remote-access tools as soon as they are saved or opened. If it flags Splashtop or another
tool you use on purpose, open the detection and choose **Create exclusion**.

## Test it

Open a browser and go to `anydesk.com`. ESET should show its "page blocked" message.

## Undo

F5 → **Protections** → **Web access protection** → **URL list management** → **Address list** → **Edit**, then:

- **If you made your own list:** select `RMM scam block (lolrmm)` → **Remove**, or untick **List active** to switch
  it off but keep it. Then OK → OK. One click.
- **If you pasted into ESET's built-in "List of blocked addresses":** edit it, click the **first** entry,
  shift-click the **last**, **Remove** → OK → OK.

  > That built-in list was empty before unless you had added your own sites — **check before removing
  > everything.**

Turning off step 8: search `unsafe` again and switch it off.

## Notes

- **Splashtop and ESET's own sites are never in the list.**
- **Quick Assist and Chrome Remote Desktop are blocked.** Both are heavily abused by scammers. If this user really
  uses one, these are the lines to remove:
  - `*.support.services.microsoft.com` — Quick Assist
  - `*.remotedesktop.google.com`, `*.remotedesktop-pa.googleapis.com`, `*.chromoting-*.talkgadget.google.com` —
    Chrome Remote Desktop
- `eset-blocked-urls-optional.txt` holds extra entries that some people use legitimately — Sophos updates, GoTo,
  Tailscale, Ninite and others. Only add those if this person does not use them.
- **This blocks the download sites and web consoles.** A tool that is *already installed* may still connect over
  its own protocol — that is what the App Control layer is for. Uninstall any remote tool you do not recognise.

## If you want a different set of tools

The website list follows the checkboxes in the window: a tool left unticked is left out of the list as well as out
of the policy. To generate one by hand:

```powershell
.\src\eset\Run-LolrmmUrlList.bat -ExcludeTool Splashtop,TeamViewer
.\src\eset\Run-LolrmmUrlList.bat -AllowDomain splashtop.com,eset.com,teamviewer.com
.\src\eset\Run-LolrmmUrlList.bat -ExtraDomain somedownloadsite.example
```

Output lands in `%USERPROFILE%\LOLRMM-UrlList\<timestamp>\`:

| File | Meaning |
|---|---|
| `eset-blocked-urls.txt` | **Import this.** One mask per line, UTF-8 without BOM. |
| `eset-blocked-urls-optional.txt` | Remote-access related but legitimately used. Add per client only. |
| `url-review.csv` | Every entry with its tier and the tool(s) it came from. Review this. |
| `website-candidates.csv` | Tool websites deliberately *not* blocked. Promote one with `-ExtraDomain`. |
| `skipped.csv`, `ips.txt` | Dropped entries with reasons, and raw IPs (the URL list takes no IPs). |

The generator is read-only: it never touches ESET's configuration, never runs `ecmd`, and never writes a registry
key. It only produces files.