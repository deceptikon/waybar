#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

if rfkill list wifi 2>>"$ERRLOG" | grep -q "Soft blocked: yes"; then
    rfkill unblock wifi
    notify-send "WiFi" "Enabled"
else
    rfkill block wifi
    notify-send "WiFi" "Disabled"
fi

signal_waybar SIGRTMIN+12
