#!/usr/bin/env bash
# Build the two release ZIPs for the remote-access tool blocker.
#
# The kit is now TWO SEPARATE PROGRAMS (see README "Quick start"):
#   folder 1\  the PROGRAM blocker  - Windows App Control. ESET-free by design: it must never
#              carry ESET steps, because a PC with no antivirus would be told to un-block
#              something it never blocked (the bug already fixed once for the windows-only kit).
#   folder 2\  the WEBSITE list     - the ESET import list, plus the ESET-aware undo tool.
#
# This script is the single definition of that layout: CI runs it and asserts the result, so the
# mapping cannot drift from the docs. Run from the repo root.
#
#     ./build/build-release.sh          # writes dist/*.zip + .sha256
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DATE="${1:-2026.10.11}"
DIST="$ROOT/dist"
mkdir -p "$DIST"

FULL_ZIP="$DIST/full-kit-eset-$DATE.zip"
WIN_ZIP="$DIST/remote-tools-block-windows-$DATE.zip"

# newest file matching a glob, error if none
pick() {
    local pat="$1"; shift
    local hit
    hit=$(ls -1 "$@" 2>/dev/null | sort | tail -1 || true)
    if [ -z "$hit" ]; then echo "MISSING: no file matching $pat in $*" >&2; exit 1; fi
    printf '%s\n' "$hit"
}

APP_BUILD=$(pick 'Build-RmmAppControl.v*.ps1'   src/appcontrol/Build-RmmAppControl.v*.ps1)
APP_INST=$(pick  'Install-RmmAppControl.v*.ps1' src/appcontrol/Install-RmmAppControl.v*.ps1)
URLGEN=$(pick    'Get-LolrmmUrlList.v*.ps1'     src/eset/Get-LolrmmUrlList.v*.ps1)
HIPSGEN=$(pick   'Get-LolrmmHipsList.v*.ps1'    src/eset/Get-LolrmmHipsList.v*.ps1)
REV_WIN=$(pick   'Revert-RemoteAccessBlock-WinOnly.v*.ps1' revert/Revert-RemoteAccessBlock-WinOnly.v*.ps1)
REV_FULL=$(pick  'Revert-RemoteAccessBlock.v*.ps1'         revert/Revert-RemoteAccessBlock.v*.ps1)
REV_INST=$(pick  'Install-ESET-Revert.v*.ps1'   revert/Install-ESET-Revert.v*.ps1)
P1=$(pick        'Block-The-Programs.v*.ps1'    kits/1/Block-The-Programs.v*.ps1)
P2=$(pick        'Block-The-Websites.v*.ps1'    kits/2/Block-The-Websites.v*.ps1)

GUIDE=revert/docs/eset-remove-guide.txt
[ -f "$GUIDE" ] || { echo "MISSING: $GUIDE" >&2; exit 1; }

# ---------------------------------------------------------------- full kit: folders 1 and 2
FULL_STAGE=$(mktemp -d)
trap 'rm -rf "$FULL_STAGE"' EXIT
mkdir -p "$FULL_STAGE/1" "$FULL_STAGE/2" "$FULL_STAGE/1/policy"

# program 1 - App Control only. The WinOnly revert variant gives it an ESET-FREE undo tool.
cp kits/1/START-HERE.bat                              "$FULL_STAGE/1/"
cp "$P1"                                              "$FULL_STAGE/1/"
cp "$APP_BUILD" "$APP_INST" src/appcontrol/Run-RmmAppControl.bat "$FULL_STAGE/1/"
cp "$REV_WIN" revert/Run-Revert.bat                   "$FULL_STAGE/1/"
cp -r policy/. "$FULL_STAGE/1/policy/"

# program 2 - the ESET website list, plus the ESET-aware undo tool and its guide.
cp kits/2/START-HERE.bat                              "$FULL_STAGE/2/"
cp "$P2" "$URLGEN" "$HIPSGEN"                         "$FULL_STAGE/2/"
cp src/eset/HOW-TO-IMPORT.txt src/eset/Run-LolrmmUrlList.bat src/eset/Run-LolrmmHipsList.bat "$FULL_STAGE/2/"
cp "$REV_INST" "$REV_FULL" revert/Run-Revert.bat      "$FULL_STAGE/2/"
mkdir -p "$FULL_STAGE/2/revert-docs"
cp "$GUIDE" "$FULL_STAGE/2/revert-docs/"

# ---------------------------------------------------------------- windows-only kit (unchanged shape)
WIN_STAGE=$(mktemp -d)
trap 'rm -rf "$FULL_STAGE" "$WIN_STAGE"' EXIT
mkdir -p "$WIN_STAGE/policy"
cp kits/windows-only/START-HERE.bat                   "$WIN_STAGE/"
cp "$(pick 'Remote-Tools-Block-Windows.v*.ps1' kits/windows-only/Remote-Tools-Block-Windows.v*.ps1)" "$WIN_STAGE/"
cp "$APP_BUILD" "$APP_INST" src/appcontrol/Run-RmmAppControl.bat "$WIN_STAGE/"
cp "$REV_WIN" revert/Run-Revert.bat                   "$WIN_STAGE/"
cp -r policy/. "$WIN_STAGE/policy/"

# ---------------------------------------------------------------- zip (deterministic: fixed order, mtime)
make_zip() {
    local out="$1" stage="$2"
    rm -f "$out"
    ( cd "$stage" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | \
        zip -q -X "$out" -@ )
}
make_zip "$FULL_ZIP" "$FULL_STAGE"
make_zip "$WIN_ZIP"  "$WIN_STAGE"

# ---------------------------------------------------------------- contracts on the REAL output
fail=0
full_list=$(unzip -Z1 "$FULL_ZIP")
for f in 1/START-HERE.bat 2/START-HERE.bat; do
    echo "$full_list" | grep -qx "$f" || { echo "ERROR: $f missing from the full kit"; fail=1; }
done
# program 1 must be ESET-free and must NOT carry the full variant or a guide
echo "$full_list" | grep -q '^1/Revert-RemoteAccessBlock-WinOnly\.v' || { echo "ERROR: folder 1 has no WinOnly revert variant"; fail=1; }
if echo "$full_list" | grep -qE '^1/(Revert-RemoteAccessBlock\.v|revert-docs/|Install-ESET-Revert)'; then
    echo "ERROR: folder 1 contains ESET-aware undo content (program 1 must be ESET-free)"; fail=1
fi
for p in egui.exe Get-LolrmmUrlList eset-blocked-urls LOLRMM-UrlList; do
    if unzip -p "$FULL_ZIP" '1/Block-The-Programs.v*.ps1' | grep -qi "$p"; then
        echo "ERROR: program 1 mentions $p - ESET leaked into the program blocker"; fail=1
    fi
done
# program 2 must carry the ESET-aware undo tool, its guide, and no App Control installer
echo "$full_list" | grep -qE '^2/Install-ESET-Revert\.v'        || { echo "ERROR: folder 2 has no ESET undo installer"; fail=1; }
echo "$full_list" | grep -qE '^2/Revert-RemoteAccessBlock\.v'   || { echo "ERROR: folder 2 has no full revert variant"; fail=1; }
echo "$full_list" | grep -q  '^2/revert-docs/eset-remove-guide.txt' || { echo "ERROR: folder 2 has no ESET guide"; fail=1; }
if echo "$full_list" | grep -qE '^2/(Install-RmmAppControl|Build-RmmAppControl)'; then
    echo "ERROR: folder 2 contains App Control scripts"; fail=1
fi
[ "$fail" -eq 0 ] || exit 1

# ---------------------------------------------------------------- hashes + a printed manifest
( cd "$DIST" && sha256sum "$(basename "$FULL_ZIP")" > "$(basename "$FULL_ZIP").sha256" \
                && sha256sum "$(basename "$WIN_ZIP")"  > "$(basename "$WIN_ZIP").sha256" )
echo '--- built ---'
( cd "$DIST" && sha256sum ./*.zip )
echo "--- full kit layout ---"
unzip -Z1 "$FULL_ZIP" | sed 's|^|  |' | head -40
echo "  ... ($(echo "$full_list" | wc -l) members total)"