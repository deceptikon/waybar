#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if ! command -v nmcli >/dev/null 2>&1; then
    log_error "wifi-rescan" "nmcli not found"
    exit 1
fi

out=""
rc=0
out=$(nmcli device wifi rescan 2>&1) || rc=$?
if [[ "$rc" -ne 0 ]]; then
    log_error "wifi-rescan" "nmcli rc=$rc: $out"
fi

signal_waybar SIGRTMIN+12
exit "$rc"
