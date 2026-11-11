#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

STATE_FILE="$RUNTIME_DIR/fn_lock_state"

if [[ "${1:-}" = "refresh" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "0" > "$STATE_FILE"
    fi
    state=$(cat "$STATE_FILE")
    if [[ "$state" = "1" ]]; then
        emit_json "󰌾 <sub></sub>" "active"
    else
        emit_json "󰌽 <sub></sub>" "inactive"
    fi
    exit 0
fi

/usr/local/bin/toggle_fn_lock.sh
