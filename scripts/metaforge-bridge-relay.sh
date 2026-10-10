#!/usr/bin/env bash
# metaforge-bridge-relay.sh — launch the MetaForge Bridge (Windows) INSIDE the
# ARC Raiders Proton prefix, so a metaforge:// deep link reaches native Steam.
#
# Install as the host handler for x-scheme-handler/metaforge (see README).
# by Hermy & Linux Fertxo
set -euo pipefail

APPID="${META_FORGE_APPID:-1808500}"
EXE="$HOME/.steam/steam/steamapps/compatdata/$APPID/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe"

[ -f "$EXE" ] || { echo "metaforge-bridge.exe not found in the prefix: $EXE" >&2; exit 1; }

# Keep XWayland/Wayland display for the GUI window.
export DISPLAY="${DISPLAY:-:0}"

exec protontricks-launch --appid "$APPID" "$EXE" "$@"
