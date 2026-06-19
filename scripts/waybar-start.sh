#!/bin/bash
set -euo pipefail

pkill -x waybar 2>/dev/null || true

# Start/restart the sysmon data poller (background data collection)
pkill -f "[s]ysmon-poller" 2>/dev/null || true
~/.config/waybar/scripts/sysmon/poller.sh &

waybar -c ~/.config/waybar/config-top -s ~/.config/waybar/style-top.css &>> /tmp/waybar-top.log &

sleep 1
waybar -c ~/.config/waybar/config-vertical -s ~/.config/waybar/style-new.css &>> /tmp/waybar-vertical.log &

sleep 1
waybar -c ~/.config/waybar/config-bottom -s ~/.config/waybar/style-bottom.css &>> /tmp/waybar-bottom.log &
