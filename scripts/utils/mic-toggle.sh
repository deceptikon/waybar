#!/bin/bash
# Toggle microphone mute state

amixer -q sset Capture toggle
sleep 0.1
pkill -SIGRTMIN+13 waybar || echo "Command failed: [mic] $?" >>/tmp/waybar_errors.log
