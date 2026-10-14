# How it works

Technical detail behind the Windows App Control layer, and the ESET layers. Read the
[README](../README.md) first for the user-facing description.

## The problem this solves

ESET HIPS rules match **file paths**, so they miss a portable copy in Downloads, a renamed copy, or an email
attachment. The App Control layer blocks by the vendor's **code-signing certificate** instead, so none of those
evasions work. No installers need to be downloaded for it to work — the certificates come from the upstream
catalogue.

## Where the certificate data comes from

[LOLRMM](https://lolrmm.io) (`/api/rmm_tools.json`, ~358 tools, Apache-2.0) publishes each tool's domains,
install paths, PE metadata and — crucially — its code-signing certificates in
`CodeSigning.certificates[].certificate_der_base64`.

`Build-RmmAppControl` downloads that file, extracts the certificates for the vendors on its hand-checked list,
and turns each one into App Control signer rules.

### Why the vendor list is hand-checked

The catalogue attaches unrelated certificates to some tools — WinRAR, PuTTY / Simon Tatham, Unity, Oculus,
OpenVPN, Symantec, Microsoft / .NET, Power Software and others appear against entries that have nothing to do
with them. An automatic rebuild against every certificate in the catalogue would block ordinary software.

So the vendor lists (`$MainSigners`, `$OptionalSigners`) are maintained by hand, and on top of them `$NeverBlock`
is a hard guard on well-known publisher common names (microsoft, google, eset, adobe and similar) that applies
regardless of what the lists say.

Optional vendors are **not** blocked by default because their certificate also signs software that clients use on
purpose — NetSupport School, Impero/Netop and Veyon (schools), GoTo, Zoho, AOMEI, RealVNC, Famatech
(Advanced IP Scanner), Kaseya, N-able, Ivanti. Pass `-IncludeOptional` to add them.

## The policy layout

The base is Microsoft's `%windir%\schemas\CodeIntegrity\ExamplePolicies\AllowAll.xml` — allow-all, with **user-mode
code integrity on** and **script enforcement off** — plus `DeniedSigners` in the user-mode signing scenario (12)
only.

That is the same layout Microsoft documents for its recommended block rules as safe to deploy standalone. Two
consequences worth knowing:

- **Script enforcement off** means PowerShell is *not* put into Constrained Language Mode, so normal administration
  and scripts keep working.
- **Scenario 12 only** means kernel-mode and driver signing are untouched.

### Leaf and publisher rules

Each vendor certificate produces two rules:

| Rule | `CertRoot` | Extra | Purpose |
|---|---|---|---|
| **leaf** | TBS hash of the vendor's own certificate | — | Matches that exact certificate |
| **publisher** | TBS hash of the CA one level below the root | `CertPublisher` = vendor CN | Survives certificate renewal |

The publisher rule is built by walking the certificate chain with `X509Chain`, which fetches missing intermediates
over AIA. When a vendor renews its certificate under the same CA, the publisher rule keeps matching — the AnyDesk
and ScreenConnect files on the original test PC already demonstrate this.

### The TBS hash

The TBS hash is the hash of the DER `tbsCertificate`, using **the hash of the certificate's own signature
algorithm** — `sha256RSA` → SHA-256, `sha384RSA` → SHA-384, and so on. Getting this wrong is the single easiest
way to build a policy that silently matches nothing.

It was cross-checked two ways:

- against ConfigCI's own `New-CIPolicy -Level LeafCertificate` / `Publisher` output on a real signed file; and
- against the `tbs_*` fields the catalogue itself publishes — **37 matched exactly**, and 4 differed only because
  those certificates are SHA-384 while the catalogue publishes SHA-1/SHA-256 hashes for them (the underlying TBS
  bytes were identical).

### The fixed policy ID

The policy carries a fixed ID, `{2D13BFB7-4304-4847-9CDD-37820D3EE9B7}`, and uses the multiple-policy format. Every
install therefore **replaces** the previous policy rather than stacking a second one, and both kits share the ID so
either kit replaces the other's install.

**Do not change this GUID.** Installed PCs are keyed to it. Changing it without a migration step that removes the
old policy leaves two policies active.

### Toggles and variants

Four tools are switchable per PC, because a client may legitimately use one:

| Toggle | Tool | Default |
|---|---|---|
| `T` | TeamViewer | blocked |
| `A` | AnyDesk | blocked |
| `S` | Splashtop | allowed |
| `R` | RustDesk | blocked |

The variant code (`T1A1S0R1`) is written into the policy's friendly name —
`Remote Access Tool Blocker (lolrmm) - Enforce [T1A1S0R1]` — and the window reads it back to tick its checkboxes.
Older installs carry three-letter codes with no `R`; the installer and the window treat those as "RustDesk
allowed", which is what they actually did.

`Build-RmmAppControl` pre-builds **all 16 combinations** in both modes (32 files) under `policy/variants/`, so a PC
that cannot run ConfigCI — a Windows Home PC, for example — can still switch between them.

Splashtop is allowed by default because it is commonly the IT shop's own support tool; the window warns before
blocking it, since that cuts off the shop's own access to that PC.

### RustDesk

RustDesk is the one vendor whose certificate is **not** from the catalogue — LOLRMM has no certificate data for it.
Its certificate (CN=PURSLANE, Sectigo EV R36, thumbprint `4230334F8A7DD84E50D0273EF379E8B4A82F5DA5`, valid to
2028-02-23) was taken from the official `rustdesk-1.5.0-x86_64.exe` / `-x86-sciter.exe` Windows builds and is
**embedded in the builder**, so a rebuild needs no download.

There is also an `OriginalFileName` deny rule for `rustdesk.exe`, covering versions 0.0.0.0 through
65535.65535.65535.65535. That catches self-built "custom client" copies, which would not carry the official
signature.

**A live RustDesk block has not been observed on a PC yet.** The rules were verified against the real installer's
certificate by inspection and all 32 compiled policies were validated, but that is build/inspection evidence, not
a live block. Test it in audit mode first.

## Coverage

Roughly **55 tools across 52 vendors**, plus 126 always-on signer rules. The complete list is in
`policy/signers.csv` (every rule) and `policy/skipped-signers.csv` (everything deliberately dropped, with a
reason). `policy/summary.txt` carries the catalogue hash the build was made from.

Not covered: unsigned tools, and the catalogue entries that publish no certificate bytes.

## Installing

`Install-RmmAppControl` has four modes: `Enforce`, `Audit`, `Remove`, `Status` (the default).

- On **Windows 11 22H2 and later** it uses `CiTool.exe --update-policy`, which takes effect immediately.
- On older builds it copies the `.cip` into `%windir%\System32\CodeIntegrity\CiPolicies\Active` and asks for a
  restart.

The log is written to `%ProgramData%\<LogDirName>\RmmAppControl.log`.

Two behaviours worth remembering:

- **App Control blocks new process starts; it does not kill running ones.** Close a tool before testing Enforce.
- `CiTool --list-policies` needs administrator rights. Without them it returns `{"OperationResult":-2147024891}`,
  which the status view reports as "unknown — needs administrator rights" rather than as "not installed".

## The ESET layers

These are optional and only apply to PCs running ESET (consumer: NOD32, Internet Security, Security Ultimate,
"ESET Security").

### Website list (`Get-LolrmmUrlList`)

Turns the catalogue's tool domains into `eset-blocked-urls.txt` — roughly 406 masks, one per line, UTF-8 without a
BOM — which you paste into ESET's **List of blocked addresses**.

Mask rules it relies on (per ESET's help for "URL address list"): a leading `*.` also matches the bare domain, so
`*.anydesk.com` covers `anydesk.com` and every subdomain; `*` matches any text and `?` a single character; no
`http(s)://` prefix is needed.

Safety filters that keep it from breaking ordinary browsing:

- **Shared platforms are never blocked at their root** — `github.com`, `githubusercontent.com`, `google.com`,
  `zoho.com`, `amazonaws.com`, `windows.net`, `cloudflare.com` and similar. A specific host *under* one of them is
  kept, because that only blocks that host (one S3 bucket, `remotedesktop.google.com`).
- Placeholders (`user_managed`) and malformed masks are skipped.
- Entries already covered by a broader `*.domain` entry are folded into it.
- The list does not accept raw IPs; those are written to `ips.txt` for reference only.

`-ExtraDomain` adds download sites the catalogue only lists as a website — it has `*.net.anydesk.com` but not
`anydesk.com`. `-ExcludeTool` and `-AllowDomain` leave a tool out entirely (TeamViewer, AnyDesk, Splashtop and RustDesk are excluded by default in the website generator; the two windows have independent choices).

Entries that are remote-access related but also legitimately used — Sophos update servers, Freshchat widgets,
Basecamp, Ninite, GoTo, Tailscale, ZeroTier, Zoho downloads — are included in the single `eset-blocked-urls.txt` file and marked optional in `url-review.csv`. Review these and remove services the client needs before import.

Two entries worth knowing about, both deliberate: `*.support.services.microsoft.com` blocks **Quick Assist** and
`*.remotedesktop.google.com` blocks **Chrome Remote Desktop**. Both are heavily abused by scammers. If a client
genuinely relies on either, drop those lines.

### HIPS path list (`Get-LolrmmHipsList`) — experimental

An earlier phase of the project. Turns the catalogue into lists of install paths for ESET's HIPS rules, matching
by path. It is read-only — it never touches ESET, runs `ecmd`, or changes a rule — and it is **not wired into
either window**.

Its limits are the reason the App Control layer exists: path rules only catch installs at known paths, so a
portable or renamed copy slips through. Wildcard path behaviour on ESET 19.2 is also unverified. Treat this as
experimental.

**Importing HIPS rules is not built.** It needs the real HIPS-rule XML for that ESET build, which was never
captured. The documented plan, if anyone wants it: add ONE rule by hand, run `ecmd /getcfg` before and after,
diff, then generate an import with a backup and rollback step. **Never guess the XML.**

### "Potentially unsafe applications"

One manual toggle, and the backstop for tools that are unsigned or previously unknown: in ESET's advanced setup,
search for `unsafe` and enable **detection of potentially unsafe applications**. ESET then flags known
remote-access tools as soon as they are saved or opened. If it flags a tool you use on purpose, open the detection
and choose **Create exclusion**.