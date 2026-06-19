#!/usr/bin/env bash
set -euo pipefail
# format-gpu.sh — Read sysmon JSON from stdin, emit Waybar JSON for GPU module
# Usage: bash scripts/sysmon-collect.sh | bash scripts/format-gpu.sh

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/draw-module.sh"

ACCENT="#fab387"
ICON="󰢮"

data=$(cat)

gpu_pct=$(jq -r '.gpu.busy_pct // 0' <<< "$data")
gpu_temp=$(jq -r '.gpu.temp_c // 0' <<< "$data")
gpu_freq=$(jq -r '.gpu.freq // 0' <<< "$data")
gpu_power=$(jq -r '.gpu.power_w // 0' <<< "$data")
mem_used=$(jq -r '.gpu.mem_used // 0' <<< "$data")
mem_total=$(jq -r '.gpu.mem_total // 0' <<< "$data")

# Class
cls="good"
[ "$gpu_pct" -ge 40 ] && cls="medium"
[ "$gpu_pct" -ge 70 ] && cls="warning"
[ "$gpu_pct" -ge 90 ] && cls="critical"

# Visual bar (4 segments)
segments=4
filled=$((gpu_pct * segments / 100))
[ "$filled" -gt "$segments" ] && filled=$segments
[ "$filled" -lt 0 ] && filled=0
empty=$((segments - filled))
bar=""
for ((i=0; i<filled; i++)); do bar+="▐"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

mem_str="--"
[ "$mem_total" -gt 0 ] && mem_str=$(awk "BEGIN{printf \"%.0fM\", $mem_used/1048576}")"/"$(awk "BEGIN{printf \"%.0fM\", $mem_total/1048576}")
gpu_power_fmt=$(printf "%.1f" "$gpu_power")

row1="GPU${bar} ${gpu_pct}% ${gpu_freq}MHz"
row2="MEM ${mem_str} ${gpu_temp}°C ${gpu_power_fmt}W"

draw_module "$ICON" "$row1" "$row2" "$ACCENT" "$cls"
