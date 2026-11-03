#!/bin/bash
# Ask NetworkManager to re-scan the air (refreshes its AP cache) and redraw the icon.
set -euo pipefail

ERRLOG=/tmp/waybar_errors.log

if ! command -v nmcli >/dev/null; then
    printf "%s wifi-rescan: nmcli not found\n" "$(date -Iseconds)" >>"$ERRLOG"
    exit 1
fi

out=""
rc=0
out=$(nmcli device wifi rescan 2>&1) || rc=$?
if [ "$rc" -ne 0 ]; then
    printf "%s wifi-rescan: nmcli rc=%s: %s\n" "$(date -Iseconds)" "$rc" "$out" >>"$ERRLOG"
fi

if ! pkill -SIGRTMIN+12 waybar; then
    printf "%s wifi-rescan: no waybar process matched SIGRTMIN+12\n" "$(date -Iseconds)" >>"$ERRLOG"
fi

exit "$rc"
