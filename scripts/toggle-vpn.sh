#!/bin/bash

set -euo pipefail

if [ "${1:-}" == "refresh" ]; then
  if [ -f /sys/class/net/kvnet/operstate ]; then
    echo '{"class": "on"}'
  else
    echo '{"class": "off"}'
  fi
  # Never self-signal from refresh path — would cause infinite loop
  exit 0
fi

if [ -f /sys/class/net/kvnet/operstate ]; then
  sudo kvpnc stop
  echo '{"class": "off"}'
else
  sudo kvpnc start
  echo '{"class": "on"}'
fi
pkill -SIGRTMIN+3 waybar || true
