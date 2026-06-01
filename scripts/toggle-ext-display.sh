#!/bin/bash
set -euo pipefail

OUTPUT="HDMI-A-1"

get_state() {
  swaymsg -t get_outputs 2>/dev/null | jq -e --arg o "$OUTPUT" '.[] | select(.name==$o) | .active' >/dev/null 2>&1 && echo "on" || echo "off"
}

emit() {
  local state="$1"
  if [ "$state" = "on" ]; then
    jq -n --compact-output '{
      text: "󰍹",
      tooltip: "External display: ON (HDMI-A-1)",
      class: "on"
    }'
  else
    jq -n --compact-output '{
      text: "󰍺",
      tooltip: "External display: OFF (HDMI-A-1)",
      class: "off"
    }'
  fi
}

if [ "${1:-}" != "refresh" ]; then
  current=$(get_state)
  if [ "$current" = "on" ]; then
    swaymsg output "$OUTPUT" disable >/dev/null 2>&1
  else
    swaymsg output "$OUTPUT" enable >/dev/null 2>&1
  fi
fi

emit "$(get_state)"

if [ "${1:-}" != "refresh" ]; then
  pkill -SIGRTMIN+11 waybar || true
fi
