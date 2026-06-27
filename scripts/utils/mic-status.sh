#!/bin/bash
# Returns JSON for waybar custom/mic module
# active = mic is ON (unmuted), inactive = mic is OFF (muted)

if amixer get Capture | grep -q '\[on\]'; then
    echo '{"text": "󰍬", "class": "active", "tooltip": "Microphone is ON (click to mute)"}'
else
    echo '{"text": "󰍭", "class": "inactive", "tooltip": "Microphone is MUTED (click to unmute)"}'
fi
