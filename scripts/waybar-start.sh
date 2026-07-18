#!/bin/bash
set -euo pipefail

LOGS_DIR="$HOME/.local/share/waybar/logs"
CFG_DIR="$HOME/.config/waybar"

# ── Check last N lines of a log for REAL errors (not benign dbus noise) ──────
check_log() {
    local bar_name="$1"
    local log_file="$2"
    local errors
    # Grep for [error] lines, then filter out known harmless service errors
    errors=$(tail -n 8 "$log_file" 2>>/tmp/waybar_errors.log \
        | grep "\[error\]" \
        | grep -v "power-profiles-daemon" \
        | grep -v "desktop appearance" \
        | grep -v "NameHasNoOwner" \
        || echo "Command failed [start]: $?" >>/tmp/waybar_errors.log)
    if [[ -n "$errors" ]]; then
        dunstify -u critical -t 0 \
            "⛔ Waybar $bar_name CSS/Config Error" \
            "$errors"
    fi
}

# ── Post-launch: wait 2s then check all logs ─────────────────────────────────
check_all_logs_deferred() {
    sleep 2
    check_log "top"      "$LOGS_DIR/waybar-top.log"
    check_log "vertical"      "$LOGS_DIR/waybar-vertical.log"
    check_log "vertical-lite" "$LOGS_DIR/waybar-vertical-lite.log"
    check_log "bottom"        "$LOGS_DIR/waybar-bottom.log"
}

# ── Reload mode (full restart — SIGUSR2 is too flaky on multi-bar) ────────────
if [[ "${1:-}" == "reload" ]]; then
    pkill -x waybar 2>>/tmp/waybar_errors.log || echo "REload failed: $?" >>/tmp/waybar_errors.log
    sleep 0.3
    waybar -c "$CFG_DIR/config-top"      -s "$CFG_DIR/style/top.css"     >> "$LOGS_DIR/waybar-top.log"    2>&1 &
    disown
    sleep 0.5
    waybar -c "$CFG_DIR/config-vertical" -s "$CFG_DIR/style/vertical.css" >> "$LOGS_DIR/waybar-vertical.log" 2>&1 &
    disown
    sleep 0.5
    waybar -c "$CFG_DIR/config-vertical-lite" -s "$CFG_DIR/style/vertical-lite.css" >> "$LOGS_DIR/waybar-vertical-lite.log" 2>&1 &
    disown
    sleep 0.5
    waybar -c "$CFG_DIR/config-bottom"   -s "$CFG_DIR/style/bottom.css"  >> "$LOGS_DIR/waybar-bottom.log"   2>&1 &
    disown
    check_all_logs_deferred &
    disown
    exit 0
fi

# ── Full restart ──────────────────────────────────────────────────────────────
pkill -x waybar 2>>/tmp/waybar_errors.log || echo "Restart failed: $?" >>/tmp/waybar_errors.log

# Aggressively clean up background bash scripts to prevent duplicates
pkill -f "sysmon/poller.sh"   2>>/tmp/waybar_errors.log || echo "Cln failed: $?" >>/tmp/waybar_errors.log
pkill -f "keywatcher.sh"      2>>/tmp/waybar_errors.log || echo "Cln failed: $?" >>/tmp/waybar_errors.log
pkill -f "wifi-info.sh"       2>>/tmp/waybar_errors.log || echo "Cln failed: $?" >>/tmp/waybar_errors.log

# Start/restart the sysmon data poller (background data collection)
~/.config/waybar/scripts/sysmon/poller.sh &
disown

waybar -c "$CFG_DIR/config-top"      -s "$CFG_DIR/style/top.css"     >> "$LOGS_DIR/waybar-top.log"      2>&1 &
disown

sleep 0.5
waybar -c "$CFG_DIR/config-vertical" -s "$CFG_DIR/style/vertical.css" >> "$LOGS_DIR/waybar-vertical.log"  2>&1 &
disown

sleep 0.5
waybar -c "$CFG_DIR/config-vertical-lite" -s "$CFG_DIR/style/vertical-lite.css" >> "$LOGS_DIR/waybar-vertical-lite.log" 2>&1 &
disown

sleep 0.5
waybar -c "$CFG_DIR/config-bottom"   -s "$CFG_DIR/style/bottom.css"  >> "$LOGS_DIR/waybar-bottom.log"    2>&1 &
disown

# Deferred log check after all bars have had time to start
check_all_logs_deferred &
disown
