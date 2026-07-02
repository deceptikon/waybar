#!/bin/bash
set -euo pipefail

OUTPUT="HDMI-A-1"

get_info() {
  swaymsg -t get_outputs | jq --arg o "$OUTPUT" '.[] | select(.name==$o)'
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
      (set +e; sleep 0.5; ddcutil setvcp D6 1; swaymsg output "$OUTPUT" dpms on; swaymsg output "$OUTPUT" enable; pkill -SIGRTMIN+11 waybar) & disown
    else
      on=$(echo "$info" | jq -r '.dpms')
      if [ "$on" = "true" ]; then
        (set +e; sleep 0.2; swaymsg output "$OUTPUT" dpms off; swaymsg output "$OUTPUT" disable; ddcutil setvcp D6 5; pkill -SIGRTMIN+11 waybar) & disown
      else
        (set +e; sleep 0.2; ddcutil setvcp D6 1; swaymsg output "$OUTPUT" dpms on; swaymsg output "$OUTPUT" enable; pkill -SIGRTMIN+11 waybar) & disown
      fi
    fi
    exit 0
fi

emit "$(get_info)"
