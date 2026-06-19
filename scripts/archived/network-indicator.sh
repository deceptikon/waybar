#!/bin/bash

# Get network statistics
# Using /proc/net/dev to get RX/TX bytes
interface=$(ip route show default | awk '/default/ {print $5}')
if [ -z "$interface" ]; then
    # Fallback to first non-loopback interface
    interface=$(ls /sys/class/net/ | grep -v lo | head -n 1)
fi

# Get RX/TX bytes
rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)

# Convert to KB/s (we need to calculate rate, so we'll read twice with delay)
sleep 0.5
rx_bytes_new=$(cat /sys/class/net/$interface/statistics/rx_bytes)
tx_bytes_new=$(cat /sys/class/net/$interface/statistics/tx_bytes)

# Calculate KB/s
rx_kb=$(( (rx_bytes_new - rx_bytes) / 1024 / 2 ))  # Divide by 2 for 0.5s interval
tx_kb=$(( (tx_bytes_new - tx_bytes) / 1024 / 2 ))

# Handle negative values (counter wrap)
if [ $rx_kb -lt 0 ]; then rx_kb=0; fi
if [ $tx_kb -lt 0 ]; then tx_kb=0; fi

# Calculate total KB/s for progress bar (assuming max around 100000 KB/s = 100 MB/s)
total_kb=$((rx_kb + tx_kb))
# Cap at 100000 KB/s for percentage calculation
if [ $total_kb -gt 100000 ]; then
    total_kb=100000
fi

# Calculate percentage for progress bar (0-100000 KB/s -> 0-100%)
if [ $total_kb -gt 0 ]; then
    usage_percent=$(( total_kb * 100 / 100000 ))
else
    usage_percent=0
fi
usage_int=$(printf "%.0f" "$usage_percent")

# Determine class based on usage
if [ $usage_int -le 30 ]; then
    net_class="transparent"
    net_icon="󰈀"
elif [ $usage_int -le 50 ]; then
    net_class="low"
    net_icon="󰈀"
elif [ $usage_int -le 80 ]; then
    net_class="medium"
    net_icon="󰈀"
else
    net_class="high"
    net_icon="󰈀"
fi

# Create thinner progress bar visualization (5 blocks)
filled_blocks=$(( usage_int / 20 ))  # Each block represents 20%
empty_blocks=$(( 5 - filled_blocks ))   # Total of 5 blocks for 100%

# Create the progress bar using block characters
progress_bar=""
for ((i=0; i<filled_blocks; i++)); do
    progress_bar+="█"
done
for ((i=0; i<empty_blocks; i++)); do
    progress_bar+="░"
done

# Format numbers for display
rx_formatted=$(printf "%d" "$rx_kb")
tx_formatted=$(printf "%d" "$tx_kb")

# Output JSON for Waybar
echo "{\"text\":\"$net_icon $progress_bar ↓${rx_formatted}K ↑${tx_formatted}K\",\"tooltip\":\"Network ($interface): ↓${rx_formatted}KB/s ↑${tx_formatted}KB/s\",\"class\":\"$net_class\"}" | jq --compact-output