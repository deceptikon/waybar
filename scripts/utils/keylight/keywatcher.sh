#!/bin/bash
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
TIMEOUT=10
KBD_DEV="/dev/input/by-path/platform-i8042-serio-0-event-kbd"
LAST_ACTION="/tmp/kbd_last_action"
PID_FILE="/tmp/keywatcher.pid"
CHECKER_PID_FILE="/tmp/keywatcher_checker.pid"

echo $$ > "$PID_FILE"

turn_off() {
    echo 0 > "$KBD_LED"
}

(
    echo $BASHPID > "$CHECKER_PID_FILE"
    while true; do
        if [ -f "$LAST_ACTION" ]; then
            LAST=$(cat "$LAST_ACTION")
            NOW=$(date +%s)
            DIFF=$((NOW - LAST))
            if [ "$DIFF" -ge "$TIMEOUT" ]; then
                if [ "$(cat $KBD_LED)" -ne 0 ]; then
                    turn_off
                fi
            fi
        fi
        sleep 1
    done
) &

evtest "$KBD_DEV" | grep --line-buffered "value 1" | while read -r line; do
    if [ "$(cat $KBD_LED)" -eq 0 ]; then
        echo 2 > "$KBD_LED"
    fi
    date +%s > "$LAST_ACTION"
done
