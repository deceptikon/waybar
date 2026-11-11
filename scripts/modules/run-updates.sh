#!/usr/bin/env bash
# run-updates.sh — interactive system update via waybar click
set -euo pipefail

source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

yay -Syyu --noconfirm
yay -Sc --noconfirm
signal_waybar SIGRTMIN+8
notify-send "Обновление завершено"
