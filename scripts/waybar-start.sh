#!/bin/bash
set -euo pipefail

pkill -x waybar 2>/dev/null || true

waybar &>> /tmp/waybar.log &

waybar -c ~/.config/waybar/config-vertical -s ~/.config/waybar/style-new.css &>> /tmp/waybar-vertical.log &
