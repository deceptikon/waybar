#!/usr/bin/env bash
set -euo pipefail

echo "TIMESTAMP $(date -Iseconds)"

echo "CPU_SNAP_1"
cat /proc/stat
sleep 0.3
echo "CPU_SNAP_2"
cat /proc/stat

echo "MEM_RAW"
cat /proc/meminfo

echo "SWAP_RAW"
cat /proc/swaps

echo "DISK_RAW"
cat /proc/diskstats

echo "NET_RAW"
cat /proc/net/dev

echo "SENSORS_JSON"
sensors -j 2>/dev/null || sensors || true

echo "GPU_RAW"
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] && echo "$d/gpu_busy_percent $(cat "$d/gpu_busy_percent")"
  [ -r "$d/mem_info_vram_used" ] && echo "$d/mem_info_vram_used $(cat "$d/mem_info_vram_used")"
  [ -r "$d/mem_info_vram_total" ] && echo "$d/mem_info_vram_total $(cat "$d/mem_info_vram_total")"
done

echo "ASUS_PROFILE"
asusctl profile get 2>/dev/null || true

echo "FAN_RAW"
for f in /sys/class/hwmon/hwmon*/fan*_input; do
  [ -r "$f" ] && echo "$f $(cat "$f")"
done
