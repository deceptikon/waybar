#!/bin/bash
if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    rfkill unblock wifi
    notify-send "WiFi" "Enabled"
else
    rfkill block wifi
    notify-send "WiFi" "Disabled"
fi
pkill -SIGRTMIN+12 waybar
