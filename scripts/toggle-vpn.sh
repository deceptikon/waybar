#!/bin/bash

set -euo pipefail

if [ "${1:-}" == "refresh" ]; then
  if [ -f /sys/class/net/kvnet/operstate ]; then
    echo '{"class": "on"}'
  else
    echo '{"class": "off"}'
  fi
  pkill -SIGRTMIN+3 waybar || true
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
