#!/bin/bash
set -euo pipefail

OUTPUT="HDMI-A-1"

get_info() {
  swaymsg -t get_outputs 2>/dev/null | jq --arg o "$OUTPUT" '.[] | select(.name==$o)'
}

emit() {
  local info="$1"
  if [ -z "$info" ]; then
    jq -n --compact-output '{
      text: "󰍹<sup>󱚦</sup>",
      tooltip: "External display: DISCONNECTED",
      class: "disconnected"
    }'
    return
  fi

  local on=$(echo "$info" | jq -r '.dpms')
  if [ "$on" = "true" ]; then
    jq -n --compact-output '{
      text: "󰍹<sup>󰄬</sup>",
      tooltip: "External display: ON (HDMI-A-1)",
      class: "on"
    }'
  else
    jq -n --compact-output '{
      text: "󰍺<sup>󰄭</sup>",
      tooltip: "External display: OFF (HDMI-A-1)",
      class: "off"
    }'
  fi
}

if [ "${1:-}" != "refresh" ]; then
    info=$(get_info)
    if [ -z "$info" ]; then
      (sleep 0.5; swaymsg output "$OUTPUT" enable 2>/dev/null; swaymsg output "$OUTPUT" dpms on 2>/dev/null; pkill -SIGRTMIN+11 waybar 2>/dev/null) & disown
    else
      (sleep 0.2; swaymsg output "$OUTPUT" dpms off 2>/dev/null; swaymsg output "$OUTPUT" disable; pkill -SIGRTMIN+11 waybar 2>/dev/null) & disown
    fi
    exit 0
fi

emit "$(get_info)"
