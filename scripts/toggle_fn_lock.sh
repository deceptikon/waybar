#!/bin/bash
set -euo pipefail

STATE_FILE="$HOME/.fn_lock_state"

if [ "${1:-}" = "refresh" ]; then
    if [ ! -f "$STATE_FILE" ]; then
        echo "0" > "$STATE_FILE"
    fi
    state=$(cat "$STATE_FILE")
    if [ "$state" = "1" ]; then
        jq -n --compact-output '{text:"󰌾 <sub></sub>",class:"active"}'
    else
        jq -n --compact-output '{text:"󰌽 <sub></sub>",class:"inactive"}'
    fi
    exit 0
fi

/usr/local/bin/toggle_fn_lock.sh