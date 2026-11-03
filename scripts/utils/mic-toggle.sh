#!/bin/bash
# Toggle microphone mute state

#amixer -q sset Capture toggle
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
sleep 0.1
pkill -SIGRTMIN+13 waybar || dunstify "Command failed: [mic]"
