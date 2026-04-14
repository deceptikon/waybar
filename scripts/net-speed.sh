#!/bin/bash
set -euo pipefail

interface=$(ip route show default | awk '/default/ {print $5}')
if [ -z "$interface" ]; then
    interface=$(ls /sys/class/net/ | grep -v lo | head -n 1)
fi

rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)

sleep 0.5

rx_bytes_new=$(cat /sys/class/net/$interface/statistics/rx_bytes)
tx_bytes_new=$(cat /sys/class/net/$interface/statistics/tx_bytes)

rx_kb=$(( (rx_bytes_new - rx_bytes) / 1024 / 2 ))
tx_kb=$(( (tx_bytes_new - tx_bytes) / 1024 / 2 ))

if [ $rx_kb -lt 0 ]; then rx_kb=0; fi
if [ $tx_kb -lt 0 ]; then tx_kb=0; fi

# Determine color class based on total speed
total_kb=$((rx_kb + tx_kb))
if [ $total_kb -gt 5000 ]; then
    net_class="critical"
elif [ $total_kb -gt 2000 ]; then
    net_class="warning"
elif [ $total_kb -gt 500 ]; then
    net_class="medium"
else
    net_class="good"
fi

# Format speed
format_speed() {
    local kb=$1
    if [ $kb -ge 1024 ]; then
        printf "%.1fM" "$(echo "scale=1; $kb/1024" | bc)"
    else
        printf "%dK" "$kb"
    fi
}

rx_fmt=$(format_speed $rx_kb)
tx_fmt=$(format_speed $tx_kb)

# Check if connected
if [ "$interface" = "lo" ] || [ -z "$interface" ]; then
    net_icon="󰌙"
    net_class="critical"
else
    # Check if wifi or ethernet
    if iw dev $interface link > /dev/null 2>&1; then
        signal=$(iw dev $interface link | awk '/signal:/ {print $2}')
        if [ -n "$signal" ]; then
            signal_value="${signal%-*}"
            if [ -n "$signal_value" ] && [ "$signal_value" -lt 70 ]; then
                net_icon="󰤨"
            elif [ -n "$signal_value" ] && [ "$signal_value" -lt 80 ]; then
                net_icon="󰤥"
            else
                net_icon="󰤢"
            fi
        else
            net_icon="󰈀"
        fi
    else
        net_icon="󰈀"
    fi
fi

jq -n --compact-output \
    --arg text "$net_icon
↓$rx_fmt ↑$tx_fmt" \
    --arg class "$net_class" \
    --arg tooltip "Network ($interface): ↓$rx_fmt/s ↑$tx_fmt/s" \
    '{text: $text, class: $class, tooltip: $tooltip}'
