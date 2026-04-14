#!/bin/bash
set -euo pipefail

if [ "${1:-}" != "refresh" ]; then
  dunstctl set-paused toggle
fi
DND="DND"

status=$(dunstctl is-paused)

if [ "$status" = "false" ]; then
  export ${DND}="1"
  tooltip=$(dunstctl count | tr '\n' ' ')
  jq -n --arg tip "$tooltip" --compact-output '{
    text: "󰂚",
    tooltip: ("Notifications: " + $tip),
    class: "on"
  }'
else
  export ${DND}="0"
  unread=$(dunstctl count waiting)
  jq -n --arg cnt "$unread" --compact-output '{
    text: ("󰂛 <small> " + $cnt + "</small>"),
    tooltip: ("Notifications paused, " + $cnt + " new"),
    class: "paused"
  }'
fi

if [ "${1:-}" != "refresh" ]; then
  pkill -SIGRTMIN+9 waybar || true
fi