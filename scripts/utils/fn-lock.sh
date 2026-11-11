#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

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
