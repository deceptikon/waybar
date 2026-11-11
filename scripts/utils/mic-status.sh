#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q '\[MUTED\]'; then
    emit_json "󰍭" "inactive" "Microphone is MUTED (click to unmute)"
else
    emit_json "󰍬" "active" "Microphone is ON (click to mute)"
fi
