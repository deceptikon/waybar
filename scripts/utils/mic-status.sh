#!/bin/bash
# Returns JSON for waybar custom/mic module
# active = mic is ON (unmuted), inactive = mic is OFF (muted)

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@| grep -q '\[MUTED\]'; then
    echo '{"text": "󰍭", "class": "inactive", "tooltip": "Microphone is MUTED (click to unmute)"}'
else
    echo '{"text": "󰍬", "class": "active", "tooltip": "Microphone is ON (click to mute)"}'
fi
