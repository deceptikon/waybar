#!/bin/bash
if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    jq -nc '{text:"󰤮", class:"disabled", tooltip:"WiFi disabled"}'
    exit 0
fi
ssid=$(iwgetid -r 2>/dev/null)
if [ -n "$ssid" ]; then
    jq -cn --arg ssid "$ssid" '{text:"󰤨", class:"connected", tooltip:("Connected to " + $ssid)}'
else
    jq -nc '{text:"󰤨", class:"enabled", tooltip:"WiFi on (no connection)"}'
fi
