#!/bin/bash
set -euo pipefail

# Big WiFi icon module — outputs a large centered icon
wifi_info=$(nmcli -t -f active,ssid,signal,device dev wifi | grep '^yes' | head -1 || true)

if [ -z "$wifi_info" ]; then
  icon="󰤮"
  signal_text="OFF"
  net_class="disconnected"
else
  signal=$(echo "$wifi_info" | cut -d: -f3)
  signal_text="${signal}%"
  if [ "$signal" -ge 80 ]; then
    icon="󰤨"
    net_class="good"
  elif [ "$signal" -ge 60 ]; then
    icon="󰤥"
    net_class="medium"
  elif [ "$signal" -ge 40 ]; then
    icon="󰤢"
    net_class="warning"
  elif [ "$signal" -ge 20 ]; then
    icon="󰤟"
    net_class="critical"
  else
    icon="󰤮"
    net_class="disconnected"
  fi
fi

# Use a specific Pango size and dim the color for the signal text
full_text=$(printf "%s\n<span size='5000' foreground='#666666' weight='light'>%s</span>" "$icon" "$signal_text")

jq -n --compact-output \
  --arg text "$full_text" \
  --arg class "$net_class" \
  '{text: $text, class: $class}'
