#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if [[ "${1:-}" == "refresh" ]]; then
    if [[ -f /sys/class/net/kvnet/operstate ]]; then
        echo '{"class": "on"}'
    else
        echo '{"class": "off"}'
    fi
    exit 0
fi

if [[ -f /sys/class/net/kvnet/operstate ]]; then
    sudo kvpnc stop
    echo '{"class": "off"}'
else
    sudo kvpnc start
    echo '{"class": "on"}'
fi

signal_waybar SIGRTMIN+3
