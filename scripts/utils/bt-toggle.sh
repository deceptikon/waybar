#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

rfkill toggle bluetooth
signal_waybar SIGRTMIN+8
