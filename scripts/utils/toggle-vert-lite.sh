#!/bin/bash
set -euo pipefail

STATE_FILE="/tmp/waybar-vert-swap"

VERT_PID=$(pgrep -f "waybar.*config-vertical[^-]" | head -1)
LITE_PID=$(pgrep -f "waybar.*config-vertical-lite" | head -1)

if [ -f "$STATE_FILE" ]; then
  rm -f "$STATE_FILE"
  [ -n "$VERT_PID" ] && kill -SIGUSR1 "$VERT_PID"
  [ -n "$LITE_PID" ] && kill -SIGUSR1 "$LITE_PID"
else
  touch "$STATE_FILE"
  [ -n "$VERT_PID" ] && kill -SIGUSR1 "$VERT_PID"
  [ -n "$LITE_PID" ] && kill -SIGUSR1 "$LITE_PID"
fi
