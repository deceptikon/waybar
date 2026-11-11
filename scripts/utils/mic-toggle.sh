#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
sleep 0.1
signal_waybar SIGRTMIN+13
