#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if rfkill list wifi 2>>"$ERRLOG" | grep -q "Soft blocked: yes"; then
    rfkill unblock wifi
    notify-send "WiFi" "Enabled"
else
    rfkill block wifi
    notify-send "WiFi" "Disabled"
fi

signal_waybar SIGRTMIN+12
