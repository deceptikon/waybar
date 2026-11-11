#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

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

signal_waybar SIGRTMIN+3 || log_error "vpn" "signal failed"
