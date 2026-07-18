#!/bin/bash

# Check bluetooth status via rfkill (wc -l always succeeds so no pipefail needed)
bt_rfkilled=$(rfkill list bluetooth 2>>/tmp/waybar_errors.log | grep "Soft blocked: yes" | wc -l)
bt_rfkilled=$((bt_rfkilled + 0))  # ensure integer

if [ "$bt_rfkilled" -gt 0 ]; then
  jq -n --compact-output \
    --arg text "󰂲" \
    --arg tooltip "Bluetooth disabled" \
    '{text: $text, class: "disabled", tooltip: $tooltip}'
  exit 0
fi

# Check for connected devices via bt-adapter
connected_devices=$(bt-adapter --list 2>>/tmp/waybar_errors.log | grep "Connected: yes" | wc -l)
connected_devices=$((connected_devices + 0))  # ensure integer

if [ "$connected_devices" -gt 0 ]; then
  device_name=$(bt-adapter --list 2>>/tmp/waybar_errors.log | grep -B1 "Connected: yes" | head -1 | sed 's/^[[:space:]]*//')
  device_battery=$(bt-adapter --list 2>>/tmp/waybar_errors.log | grep -A5 "Connected: yes" | grep "Battery" | awk '{print $2}' | head -1)
  if [ -n "$device_battery" ]; then
    jq -n --compact-output \
      --arg text "" \
      --arg tooltip "Connected: $device_name ($device_battery%)" \
      '{text: $text, class: "connected", tooltip: $tooltip}'
  else
    jq -n --compact-output \
      --arg text "" \
      --arg tooltip "Connected: $device_name" \
      '{text: $text, class: "connected", tooltip: $tooltip}'
  fi
else
  jq -n --compact-output \
    --arg text "" \
    --arg tooltip "Bluetooth enabled, no devices connected" \
    '{text: $text, class: "enabled", tooltip: $tooltip}'
fi
