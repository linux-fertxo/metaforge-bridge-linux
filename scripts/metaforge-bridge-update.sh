#!/usr/bin/env bash
# metaforge-bridge-update.sh — download the official MetaForge Bridge installer and
# (re)install it inside the ARC Raiders Proton prefix.
#
# Usage:  metaforge-bridge-update.sh [--check] [--force]
#   --check   only report installed vs available version (no install)
#   --force   reinstall even if versions match
# by Hermy & Linux Fertxo
set -euo pipefail

APPID="${META_FORGE_APPID:-1808500}"
URL="https://downloads.metaforge.app/bridge/MetaForgeBridgeSetup.exe"
DL="$HOME/Downloads/MetaForgeBridgeSetup.exe"
EXE="$HOME/.steam/steam/steamapps/compatdata/$APPID/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe"

CHECK=0; FORCE=0
for a in "$@"; do case "$a" in
  --check) CHECK=1;;
  --force|-f) FORCE=1;;
  -h|--help) sed -n '2,10p' "$0"; exit 0;;
  *) echo "unknown option: $a" >&2; exit 64;;
esac; done

# Read the ProductVersion string out of a PE/NSIS binary.
ver() { strings -e l -n 3 "$1" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1; }

CUR=""; [ -f "$EXE" ] && CUR="$(ver "$EXE")"
echo "installed : ${CUR:-<none>}"

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if ! curl -fsS -A 'Mozilla/5.0' -o "$TMP" "$URL"; then
  echo "could not download the official installer" >&2; exit 2
fi
NEW="$(ver "$TMP")"
[ -n "$NEW" ] || { echo "could not read the installer version" >&2; exit 2; }
echo "available : $NEW"

if [ -n "$CUR" ] && [ "$CUR" = "$NEW" ] && [ "$FORCE" = 0 ]; then
  echo "already up to date ($CUR). Nothing to do."; exit 0
fi

echo "updating  : ${CUR:-<none>} -> $NEW"
if [ "$CHECK" = 1 ]; then echo "(--check: not installing)"; exit 0; fi

pgrep -x steam >/dev/null || { echo "Steam is not running: start it and retry." >&2; exit 3; }

# The NSIS installer can't replace an .exe that is in use.
if pkill -f 'metaforge-bridge\.exe' 2>/dev/null; then echo "closing running bridge…"; sleep 2; fi

mkdir -p "$(dirname "$DL")"
mv -f "$TMP" "$DL"
export DISPLAY="${DISPLAY:-:0}"
echo "installing into the prefix…"
protontricks-launch --appid "$APPID" "$DL" /S
echo "done. installed now: $(ver "$EXE")"
