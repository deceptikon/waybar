#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if [[ "${1:-}" != "refresh" ]]; then
    dunstctl set-paused toggle
fi
status=$(dunstctl is-paused)

if [[ "$status" = "false" ]]; then
    tooltip=$(dunstctl count | tr '\n' ' ')
    emit_json "󰂚" "on" "Notifications: $tooltip"
else
    unread=$(dunstctl count waiting)
    emit_json "󰂛 <sup>${unread}</sup>" "paused" "Notifications paused, $unread new"
fi

if [[ "${1:-}" != "refresh" ]]; then
    signal_waybar SIGRTMIN+9
fi
