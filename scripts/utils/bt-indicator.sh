#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

bt_rfkilled=$(rfkill list bluetooth 2>>"$ERRLOG" | grep "Soft blocked: yes" | wc -l)
bt_rfkilled=$((bt_rfkilled + 0))

if [[ "$bt_rfkilled" -gt 0 ]]; then
    emit_json "󰂲" "disabled" "Bluetooth disabled"
    exit 0
fi

connected_devices=$(bt-adapter --list 2>>"$ERRLOG" | grep "Connected: yes" | wc -l)
connected_devices=$((connected_devices + 0))

if [[ "$connected_devices" -gt 0 ]]; then
    device_name=$(bt-adapter --list 2>>"$ERRLOG" | grep -B1 "Connected: yes" | head -1 | sed 's/^[[:space:]]*//')
    device_battery=$(bt-adapter --list 2>>"$ERRLOG" | grep -A5 "Connected: yes" | grep "Battery" | awk '{print $2}' | head -1)
    if [[ -n "$device_battery" ]]; then
        emit_json "" "connected" "Connected: $device_name ($device_battery%)"
    else
        emit_json "" "connected" "Connected: $device_name"
    fi
else
    emit_json "" "enabled" "Bluetooth enabled, no devices connected"
fi
