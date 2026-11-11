#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
sleep 0.1
signal_waybar SIGRTMIN+13 || dunstify "Command failed: [mic]"
