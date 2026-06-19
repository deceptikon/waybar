#!/bin/bash

# Read fan speed directly from sysfs instead of calling sensors
# Much faster and more efficient

for fan_input in /sys/class/hwmon/hwmon*/fan2_input; do
  if [ -r "$fan_input" ]; then
    rpm=$(cat "$fan_input" 2>/dev/null)
    if [ -n "$rpm" ]; then
      echo "$rpm RPM"
      exit 0
    fi
  fi
done

# Fallback to sensors if sysfs not available
sensors 2>/dev/null | awk '/fan2:/ {print $2,$3}'
