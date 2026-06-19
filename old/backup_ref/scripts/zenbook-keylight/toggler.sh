#!/bin/bash
DAEMON="/usr/local/bin/kbd_auto_monitor.sh"
KBD_LED="/sys/class/leds/asus::kbd_backlight/brightness"

if pgrep -f "$DAEMON" > /dev/null; then
    pkill -f "$DAEMON"
    pkill -f "sleep .* && echo 0 > $KBD_LED"
    echo 0 > "$KBD_LED"
else
    # Запускаем монитор в фоне
    $DAEMON &
fi

# Посылаем сигнал Waybar, чтобы он обновил модуль (SIGRTMIN+8)
pkill -RTMIN+8 waybar
