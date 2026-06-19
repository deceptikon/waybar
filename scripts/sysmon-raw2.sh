#!/usr/bin/env bash
set -euo pipefail

echo "TIMESTAMP $(date -Iseconds)"

echo "CPU_ALL"
mpstat 1 1 || true

echo "MEM"
free -b || true

echo "DISK_IO"
iostat -dx 1 1 || true

echo "NET"
cat /proc/net/dev || true

echo "SENSORS_JSON"
sensors -j 2>/dev/null || sensors || true

echo "GPU_BUSY"
for d in /sys/class/drm/card*/device; do
  [ -r "$d/gpu_busy_percent" ] && echo "$d $(cat "$d/gpu_busy_percent")"
done

echo "ASUSCTL"
asusctl --help || true
