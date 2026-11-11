#!/usr/bin/env bash
# ddc-signal.sh — wrapper for ddcutil combo changes with waybar refresh
set -euo pipefail

source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

action="${1:-}"
value="${2:-}"

if [[ -z "$action" ]]; then
    log_error "ddc-signal" "missing action"
    exit 1
fi

if [[ "$action" == "set" ]]; then
    "$WAYBAR_HOME/scripts/utils/ddc.sh" combo "$action" "$value"
else
    "$WAYBAR_HOME/scripts/utils/ddc.sh" combo "$action"
fi

signal_waybar SIGRTMIN+11
