#!/usr/bin/env bash
# collect.sh — RAW samples only. No JSON, no rates, no formatting.
set -euo pipefail

echo "TIMESTAMP $(date +%s.%N)"

echo "CPU_SNAP_1"
cat /proc/stat
sleep 0.3
echo "CPU_SNAP_2"
cat /proc/stat

echo "MEM_RAW"
cat /proc/meminfo

echo "DISK_RAW"
cat /proc/diskstats

echo "DF_RAW"
# 1-byte blocks for stable math in mapper
df -B1 -P / 2>>/tmp/waybar_errors.log || df -P /

echo "NET_RAW"
cat /proc/net/dev

echo "SENSORS_JSON"
if ! sensors -j 2>>/tmp/waybar_errors.log; then
  echo "{}"
  echo "collect: sensors -j failed: $?" >>/tmp/waybar_errors.log
fi

echo "GPU_RAW"
shopt -s nullglob
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] && echo "$d/gpu_busy_percent $(cat "$d/gpu_busy_percent")"
  [ -r "$d/mem_info_vram_used" ] && echo "$d/mem_info_vram_used $(cat "$d/mem_info_vram_used")"
  [ -r "$d/mem_info_vram_total" ] && echo "$d/mem_info_vram_total $(cat "$d/mem_info_vram_total")"
done

echo "FAN_RAW"
for f in /sys/class/hwmon/hwmon*/fan*_input; do
  [ -r "$f" ] && echo "$f $(cat "$f")"
done
