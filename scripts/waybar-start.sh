#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "reload" ]]; then
    killall -SIGUSR2 waybar 2>/dev/null || true
    echo "Waybar reloaded"
    exit 0
fi

pkill -x waybar 2>/dev/null || true

# Start/restart the sysmon data poller (background data collection)
pkill -f "sysmon/poller.sh" 2>/dev/null || true
~/.config/waybar/scripts/sysmon/poller.sh &
disown

waybar -c ~/.config/waybar/config-top -s ~/.config/waybar/style-top.css >> ~/.config/waybar/logs/waybar-top.log 2>&1 &
disown

sleep 1
waybar -c ~/.config/waybar/config-vertical -s ~/.config/waybar/style-new.css >> ~/.config/waybar/logs/waybar-vertical.log &
disown

sleep 1
waybar -c ~/.config/waybar/config-bottom -s ~/.config/waybar/style-bottom.css >> ~/.config/waybar/logs/waybar-bottom.log 2>&1 &
disown
