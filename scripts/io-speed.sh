#!/bin/bash
set -euo pipefail

io_data=$(iostat -d 1 2 | grep '^nvme' | tail -n 1)

if [ -z "$io_data" ]; then
    jq -n --compact-output \
        --arg text "󰋊\\n-" \
        --arg class "good" \
        --arg tooltip "No NVMe device found" \
        '{text: $text, class: $class, tooltip: $tooltip}'
    exit 0
fi

read_mb=$(echo "$io_data" | awk '{printf "%.1f", $3/1024}')
write_mb=$(echo "$io_data" | awk '{printf "%.1f", $4/1024}')
iops=$(echo "$io_data" | awk '{printf "%d", $2}')

# Determine color class based on total MB/s
total_mb=$(echo "$read_mb + $write_mb" | bc)
if (( $(echo "$total_mb > 1000" | bc -l) )); then
    io_class="critical"
elif (( $(echo "$total_mb > 500" | bc -l) )); then
    io_class="warning"
elif (( $(echo "$total_mb > 100" | bc -l) )); then
    io_class="medium"
else
    io_class="good"
fi

jq -n --compact-output \
    --arg text "󰋊 $iops
↓$read_mb ↑$write_mb" \
    --arg class "$io_class" \
    --arg tooltip "IOPS: $iops | Read: $read_mb MB/s | Write: $write_mb MB/s" \
    '{text: $text, class: $class, tooltip: $tooltip}'
