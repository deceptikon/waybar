#!/bin/bash
DAEMON="$HOME/.config/waybar/scripts/utils/keylight/keywatcher.sh"
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
PID_FILE="/tmp/keywatcher.pid"
CHECKER_PID_FILE="/tmp/keywatcher_checker.pid"

cleanup() {
    local pid
    if [ -f "$CHECKER_PID_FILE" ]; then
        pid=$(cat "$CHECKER_PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
        rm -f "$CHECKER_PID_FILE"
    fi
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    pkill -f "keylight/keywatcher.sh" 2>/dev/null || true
    pkill -f "evtest.*platform-i8042" 2>/dev/null || true
}

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    cleanup
    echo 0 > "$KBD_LED"
else
    cleanup
    $DAEMON &
    disown
fi

sleep 0.2
pkill -SIGRTMIN+8 waybar || true
