#!/bin/bash

set -euo pipefail

if [ "${1:-}" != "refresh" ]; then
  dunstctl set-paused toggle
fi

status=$(dunstctl is-paused)

if [ "$status" = "false" ]; then
  tooltip=$(dunstctl count | tr '\n' ' ')
  jq -n --arg tip "$tooltip" --compact-output '{
    text: "󰂚",
    tooltip: ("Notifications: " + $tip),
    class: "on"
  }'
else
  unread=$(dunstctl count waiting)
  jq -n --arg cnt "$unread" --compact-output '{
    text: ("󰂚 <small> " + $cnt + "</small>"),
    tooltip: ("Notifications paused, " + $cnt + " new"),
    class: "paused"
  }'
fi

if [ "${1:-}" != "refresh" ]; then
  pkill -SIGRTMIN+9 waybar || true
fi
