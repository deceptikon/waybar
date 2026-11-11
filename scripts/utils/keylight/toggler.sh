#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

DAEMON="$WAYBAR_HOME/scripts/utils/keylight/keywatcher.sh"
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
PID_FILE="$RUNTIME_DIR/keywatcher.pid"
CHECKER_PID_FILE="$RUNTIME_DIR/keywatcher_checker.pid"

cleanup() {
    local pid
    if [[ -f "$CHECKER_PID_FILE" ]]; then
        pid=$(cat "$CHECKER_PID_FILE" 2>>"$ERRLOG")
        if [[ -n "$pid" ]] && kill -0 "$pid" >>"$ERRLOG" 2>&1; then
            kill "$pid"
        fi
        rm -f "$CHECKER_PID_FILE"
    fi
    if [[ -f "$PID_FILE" ]]; then
        pid=$(cat "$PID_FILE" 2>>"$ERRLOG")
        if [[ -n "$pid" ]] && kill -0 "$pid" >>"$ERRLOG" 2>&1; then
            kill "$pid"
        fi
        rm -f "$PID_FILE"
    fi
    pkill -f "keylight/keywatcher.sh" 2>>"$ERRLOG" || log_error "keywatch" "pkill keywatcher failed"
    pkill -f "evtest.*platform-i8042" 2>>"$ERRLOG" || log_error "keywatch" "pkill evtest failed"
}

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>>"$ERRLOG"; then
    cleanup
    echo 0 > "$KBD_LED"
else
    cleanup
    "$DAEMON" &
    disown
fi

sleep 0.2
signal_waybar SIGRTMIN+8
