#!/bin/bash
set -euo pipefail

pkill -x waybar 2>/dev/null || true

waybar &>> /tmp/waybar.log &

<<<<<<< HEAD
=======
sleep 1

>>>>>>> a4e4e84 (split styles, bar adjustment)
waybar -c ~/.config/waybar/config-vertical -s ~/.config/waybar/style-new.css &>> /tmp/waybar-vertical.log &
