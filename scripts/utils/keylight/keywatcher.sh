#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
TIMEOUT=3
KBD_DEV="/dev/input/by-path/platform-i8042-serio-0-event-kbd"
LAST_ACTION="$RUNTIME_DIR/kbd_last_action"
PID_FILE="$RUNTIME_DIR/keywatcher.pid"
CHECKER_PID_FILE="$RUNTIME_DIR/keywatcher_checker.pid"

echo $$ > "$PID_FILE"

turn_off() {
    echo 0 > "$KBD_LED"
}

(
    echo "$BASHPID" > "$CHECKER_PID_FILE"
    while true; do
        if [[ -f "$LAST_ACTION" ]]; then
            last=$(cat "$LAST_ACTION")
            now=$(date +%s)
            diff=$((now - last))
            if [[ "$diff" -ge "$TIMEOUT" ]]; then
                if [[ "$(cat "$KBD_LED")" -ne 0 ]]; then
                    turn_off
                fi
            fi
        fi
        sleep 0.5
    done
) &

stdbuf -oL evtest "$KBD_DEV" 2>>"$ERRLOG" \
    | grep --line-buffered "value 1" \
    | while read -r _line; do
        if [[ "$(cat "$KBD_LED")" -eq 0 ]]; then
            echo 2 > "$KBD_LED"
        fi
        date +%s > "$LAST_ACTION"
    done
