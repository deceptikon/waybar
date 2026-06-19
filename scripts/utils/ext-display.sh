#!/bin/bash
set -euo pipefail

# This script toggles the external display (HDMI-A-1).
# decoupling via 'swaymsg exec' in config handles the Waybar click-capture bug.

OUTPUT="HDMI-A-1"

get_info() {
  swaymsg -t get_outputs 2>/dev/null | jq --arg o "$OUTPUT" '.[] | select(.name==$o)'
}

emit() {
  local info="$1"
  if [ -z "$info" ]; then
    # Disconnected
    jq -n --compact-output '{
      text: "󰍹<sup>󱚦</sup>",
      tooltip: "External display: DISCONNECTED",
      class: "disconnected"
    }'
    return
  fi

  local active=$(echo "$info" | jq -r '.active')
  if [ "$active" = "true" ]; then
    # ON
    jq -n --compact-output '{
      text: "󰍹<sup>󰄬</sup>",
      tooltip: "External display: ON (HDMI-A-1)",
      class: "on"
    }'
  else
    # OFF
    jq -n --compact-output '{
      text: "󰍺<sup>󰄭</sup>",
      tooltip: "External display: OFF (HDMI-A-1)",
      class: "off"
    }'
  fi
}

# 1. Action Path: Toggle and signal
if [ "${1:-}" != "refresh" ]; then
    info=$(get_info)
    if [ -n "$info" ]; then
      active=$(echo "$info" | jq -r '.active')
      if [ "$active" = "true" ]; then
        swaymsg output "$OUTPUT" disable >/dev/null 2>&1
      else
        swaymsg output "$OUTPUT" enable >/dev/null 2>&1
      fi
      # Slight delay to let Sway finish layout reconfiguration
      sleep 0.3
      pkill -SIGRTMIN+11 waybar || true
    fi
    exit 0
fi

# 2. Refresh Path: Emit JSON
emit "$(get_info)"
