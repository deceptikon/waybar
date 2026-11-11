#!/usr/bin/env bash
# scripts/lib/common.sh — shared helpers for Waybar scripts
#
# Usage (from scripts/<area>/foo.sh):
#   source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
#
# This library intentionally does NOT change shell options. Waybar `exec`
# scripts must keep running when a probe (grep, iwgetid, curl, …) exits
# non-zero; side-effect scripts can opt into `set -euo pipefail` themselves.

# Resolve the Waybar root from this file's location, so scripts work both in
# the repository and when deployed to ~/.config/waybar. WAYBAR_HOME may still
# be overridden explicitly.
LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_HOME="${WAYBAR_HOME:-$(cd -- "$LIB_DIR/../.." && pwd)}"

# All project logs live in <waybar-root>/logs. Mutable state/PIDs live under
# XDG_STATE_HOME / XDG_RUNTIME_DIR.
LOG_DIR="${WAYBAR_LOG_DIR:-$WAYBAR_HOME/logs}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-$STATE_DIR/run}"

mkdir -p "$LOG_DIR" "$STATE_DIR" "$RUNTIME_DIR"

ERRLOG="$LOG_DIR/errors.log"
WAYBAR_PIDFILE="$RUNTIME_DIR/waybar.pid"

# log_error TAG MESSAGE...
log_error() {
    local tag="${1:-waybar}"
    shift || true
    printf '%s %s: %s\n' "$(date -Iseconds)" "$tag" "$*" >>"$ERRLOG"
}

# signal_waybar [SIGRTMIN+N]
# Missing waybar processes are logged but never fail the caller.
signal_waybar() {
    local sig="${1:-SIGRTMIN+8}"
    if ! pkill -"$sig" waybar 2>/dev/null; then
        log_error "signal" "pkill $sig failed (no waybar process?)"
    fi
    return 0
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
