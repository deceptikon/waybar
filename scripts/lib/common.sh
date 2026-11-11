#!/usr/bin/env bash
# scripts/lib/common.sh — shared helpers for Waybar scripts
#
# Usage: source "$WAYBAR_HOME/scripts/lib/common.sh"

set -euo pipefail

# Runtime and state locations
WAYBAR_HOME="${WAYBAR_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/waybar}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-$STATE_DIR/run}"
LOG_DIR="${WAYBAR_HOME}/logs"

mkdir -p "$STATE_DIR" "$RUNTIME_DIR" "$LOG_DIR"

ERRLOG="$STATE_DIR/errors.log"
WAYBAR_PIDFILE="$RUNTIME_DIR/waybar.pid"

# log_error TAG MESSAGE...
log_error() {
    local tag="${1:-waybar}"
    shift || true
    printf '%s %s: %s\n' "$(date -Iseconds)" "$tag" "$*" >>"$ERRLOG"
}

# signal_waybar [SIGRTMIN+N]
signal_waybar() {
    local sig="${1:-SIGRTMIN+8}"
    if ! pkill -"$sig" waybar; then
        log_error "signal" "pkill $sig failed"
        return 1
    fi
}

# emit_json TEXT CLASS [TOOLTIP]
emit_json() {
    local text="$1" class="$2" tooltip="${3:-}"
    if [[ -n "$tooltip" ]]; then
        jq -nc \
            --arg text "$text" \
            --arg class "$class" \
            --arg tooltip "$tooltip" \
            '{text:$text, class:$class, tooltip:$tooltip}'
    else
        jq -nc \
            --arg text "$text" \
            --arg class "$class" \
            '{text:$text, class:$class}'
    fi
}

# require_cmd CMD [HUMAN_NAME]
require_cmd() {
    local cmd="$1" name="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "require" "missing command: $name"
        return 1
    fi
}
