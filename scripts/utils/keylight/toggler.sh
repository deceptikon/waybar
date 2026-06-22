#!/bin/bash
DAEMON="$HOME/.config/waybar/scripts/utils/keylight/keywatcher.sh"
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"
PID_FILE="/tmp/keywatcher.pid"

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    kill -9 $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
    pkill -f "evtest.*/platform-i8042"
    pkill -f "keylight/keywatcher.sh"
    echo 0 > "$KBD_LED"
else
    pkill -f "evtest.*/platform-i8042"
    pkill -f "keylight/keywatcher.sh"
    $DAEMON &
    echo $! > "$PID_FILE"
fi

sleep 0.2
pkill -SIGRTMIN+8 waybar
