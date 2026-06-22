#!/bin/bash
PID_FILE="/tmp/keywatcher.pid"
if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo '{"text": "󰛨 <sup></sup>", "class": "active", "tooltip": "Auto-backlight is ENABLED"}'
else
    echo '{"text": "󰌶 <sup></sup>", "class": "inactive", "tooltip": "Auto-backlight is DISABLED"}'
fi
