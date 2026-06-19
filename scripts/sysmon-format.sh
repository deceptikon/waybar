#!/usr/bin/env bash
set -euo pipefail
# sysmon-format.sh — Read JSON tree from stdin (mapper output), emit Waybar JSON lines
# Usage: bash scripts/sysmon-collect.sh | bash scripts/sysmon-mapper.sh | bash scripts/sysmon-format.sh
# Output: one line per module: "GPU {...}\nCPU {...}\nRAM {...}\nSSD {...}\nTEMP {...}"

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/draw-module.sh"

data=$(cat)

# ── GPU ──
gpu_pct=$(jq -r '.gpu.busy_pct // 0' <<< "$data")
gpu_temp=$(jq -r '.gpu.temp_c // 0' <<< "$data")
gpu_freq=$(jq -r '.gpu.freq // 0' <<< "$data")
gpu_power=$(jq -r '.gpu.power_w // 0' <<< "$data")
mem_used=$(jq -r '.gpu.mem_used // 0' <<< "$data")
mem_total=$(jq -r '.gpu.mem_total // 0' <<< "$data")
gpu_cls="good"; [ "$gpu_pct" -ge 40 ] && gpu_cls="medium"; [ "$gpu_pct" -ge 70 ] && gpu_cls="warning"; [ "$gpu_pct" -ge 90 ] && gpu_cls="critical"
seg=4; fil=$((gpu_pct*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
gpu_bar=""; for ((i=0; i<fil; i++)); do gpu_bar+="▐"; done; for ((i=0; i<emp; i++)); do gpu_bar+="░"; done
mem_str="--"; [ "$mem_total" -gt 0 ] && mem_str=$(awk "BEGIN{printf \"%.0fM\", $mem_used/1048576}")"/"$(awk "BEGIN{printf \"%.0fM\", $mem_total/1048576}")
pfmt=$(printf "%.1f" "$gpu_power")
gpu_out=$(draw_module "󰢮" "GPU${gpu_bar} ${gpu_pct}% ${gpu_freq}MHz" "MEM ${mem_str} ${gpu_temp}°C ${pfmt}W" "#fab387" "$gpu_cls")

# ── CPU ──
cpu_avg=$(jq -r '.cpu.avg // 0' <<< "$data")
cpu_cls="good"; [ "$cpu_avg" -ge 40 ] && cpu_cls="medium"; [ "$cpu_avg" -ge 70 ] && cpu_cls="warning"; [ "$cpu_avg" -ge 90 ] && cpu_cls="critical"
cpu_bar=""
for ((c=0; c<16; c++)); do
  p=$(jq -r ".cpu.per_core[$c] // -1" <<< "$data")
  if [ "$p" -ge 90 ]; then col="#f38ba8"
  elif [ "$p" -ge 70 ]; then col="#fab387"
  elif [ "$p" -ge 40 ]; then col="#f9e2af"
  elif [ "$p" -ge 15 ]; then col="#89b4fa"
  elif [ "$p" -ge 0 ]; then col="#383838"
  else col="#2a2a2a"; fi
  [ "$c" -eq 8 ] && cpu_bar+=$'\n'
  cpu_bar+="<span fgcolor=\"$col\">▓</span>"
done
cpu_out=$(draw_module "󰍛" "$cpu_bar" "<span fgcolor=\"#a6e3a1\"><b>AVG ${cpu_avg}%</b></span>" "#a6e3a1" "$cpu_cls")

# ── RAM ──
ram_used_kb=$(jq -r '.ram.used_kb // 0' <<< "$data")
ram_total_kb=$(jq -r '.ram.total_kb // 0' <<< "$data")
ram_avail_kb=$(jq -r '.ram.avail_kb // 0' <<< "$data")
ram_used_pct=$(jq -r '.ram.used_pct // 0' <<< "$data")
swap_used_kb=$(jq -r '.ram.swap_used_kb // 0' <<< "$data")
ram_cls="good"; [ "$ram_used_pct" -ge 50 ] && ram_cls="medium"; [ "$ram_used_pct" -ge 75 ] && ram_cls="warning"; [ "$ram_used_pct" -ge 90 ] && ram_cls="critical"
used_g=$(awk "BEGIN{printf \"%.0f\", $ram_used_kb/1048576}")
avail_g=$(awk "BEGIN{printf \"%.0f\", $ram_avail_kb/1048576}")
swap_m=$(awk "BEGIN{printf \"%.0f\", $swap_used_kb/1024}")
seg_total=8; seg_used=$((ram_used_pct*seg_total/100)); [ "$seg_used" -eq 0 ] && seg_used=1; [ "$seg_used" -gt "$seg_total" ] && seg_used=$seg_total
ram_bar=""
for ((i=0; i<seg_total; i++)); do [ "$i" -lt "$seg_used" ] && ram_bar+="●" || ram_bar+="○"; done
ram_out=$(draw_module "" "<span fgcolor='#89b4fa'>${used_g}G</span> <span fgcolor='#f8f8f8'>/ ${avail_g}G</span>" "${ram_bar}  swp ${swap_m}M" "#89b4fa" "$ram_cls")

# ── SSD ──
disk_usage_pct=$(df / | awk 'END{print $5}' | tr -d '%')
drs=$(jq -r '.disk.read_sectors // 0' <<< "$data")
dws=$(jq -r '.disk.write_sectors // 0' <<< "$data")
ssd_cls="good"; [ "$disk_usage_pct" -ge 70 ] && ssd_cls="medium"; [ "$disk_usage_pct" -ge 85 ] && ssd_cls="warning"; [ "$disk_usage_pct" -ge 95 ] && ssd_cls="critical"
seg=4; fil=$((disk_usage_pct*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
ssd_fill=""; for ((i=0; i<fil; i++)); do ssd_fill+="▓"; done; for ((i=0; i<emp; i++)); do ssd_fill+="░"; done
fmt_bytes() { local b=$1; if [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"; elif [ "$b" -ge 1048576 ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"; elif [ "$b" -ge 1024 ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"; else echo "${b}B"; fi; }
rd_fmt=$(fmt_bytes $((drs * 512))); wr_fmt=$(fmt_bytes $((dws * 512)))
ssd_out=$(draw_module "󰋊" "<b>${ssd_fill}</b> <b>${disk_usage_pct}%</b>" "<span fgcolor='#94e2d5'>↑${rd_fmt}  ↓${wr_fmt}</span>" "#a6e3a1" "$ssd_cls")

# ── TEMP ──
cpu_c=$(jq -r '.temp.cpu_c // 0' <<< "$data")
fan1=$(jq -r '.temp.fan1 // 0' <<< "$data")
temp_cls="good"; [ "$(printf "%.0f" "$cpu_c")" -ge 60 ] && temp_cls="warning"; [ "$(printf "%.0f" "$cpu_c")" -ge 85 ] && temp_cls="critical"
temp_out=$(draw_module "󰔐" "$(printf "%.0f" "$cpu_c")°C" "󰈐 ${fan1} RPM" "#f38ba8" "$temp_cls")

# ── OUTPUT ──
echo "GPU $gpu_out"
echo "CPU $cpu_out"
echo "RAM $ram_out"
echo "SSD $ssd_out"
echo "TEMP $temp_out"
