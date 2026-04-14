#!/bin/bash
set -euo pipefail

# Get WiFi info
wifi_info=$(nmcli -t -f active,ssid,signal dev wifi | grep '^yes' | head -1)

if [ -z "$wifi_info" ]; then
  jq -n --compact-output \
    --arg text "󰤮 0%
Disconnected" \
    --arg tooltip "No WiFi connection" \
    '{text: $text, class: "disconnected", tooltip: $tooltip}'
  exit 0
fi

ssid=$(echo "$wifi_info" | cut -d: -f2)
signal=$(echo "$wifi_info" | cut -d: -f3)

# Determine icon based on signal strength
if [ "$signal" -ge 80 ]; then
  icon="󰤨"
  wifi_class="good"
elif [ "$signal" -ge 60 ]; then
  icon="󰤥"
  wifi_class="medium"
elif [ "$signal" -ge 40 ]; then
  icon="󰤢"
  wifi_class="warning"
elif [ "$signal" -ge 20 ]; then
  icon="󰤟"
  wifi_class="critical"
else
  icon="󰤮"
  wifi_class="disconnected"
fi

# Output: top row = icon + signal, bottom row = SSID (small)
jq -n --compact-output \
   --arg text "$icon ${signal}%
<small>${ssid^^}</small>" \
   --arg class "$wifi_class" \
   --arg tooltip "WiFi: ${ssid^^} Signal: $signal%" \
   '{text: $text, class: $class, tooltip: $tooltip}'
