#!/bin/bash
if pgrep -f "kbd_auto_monitor.sh" > /dev/null; then
    echo '{"text": "󰛨 <sup></sup>", "class": "active", "tooltip": "Auto-backlight is ENABLED"}'
else
    echo '{"text": "󰌶 <sup></sup>", "class": "inactive", "tooltip": "Auto-backlight is DISABLED"}'
fi
