#!/usr/bin/env bash
# ddc-signal.sh — wrapper for ddcutil combo changes with waybar refresh
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

action="${1:-}"
value="${2:-}"

if [[ -z "$action" ]]; then
    log_error "ddc-signal" "missing action"
    exit 1
fi

if [[ "$action" == "set" ]]; then
    "$WAYBAR_HOME/scripts/utils/ddc.sh" combo "$action" "$value" \
        || log_error "ddc-signal" "ddc.sh set $value failed"
else
    "$WAYBAR_HOME/scripts/utils/ddc.sh" combo "$action" \
        || log_error "ddc-signal" "ddc.sh $action failed"
fi

signal_waybar SIGRTMIN+11
