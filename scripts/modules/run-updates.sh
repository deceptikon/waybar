#!/usr/bin/env bash
# run-updates.sh — interactive system update via waybar click
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

yay -Syyu --noconfirm
yay -Sc --noconfirm
signal_waybar SIGRTMIN+8
notify-send "Обновление завершено"
