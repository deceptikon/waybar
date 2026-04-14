#!/bin/bash

# Dynamically find coretemp hwmon path
# Output format for Waybar temperature module

for hwmon in /sys/class/hwmon/hwmon*/name; do
  if grep -q "coretemp" "$hwmon" 2>/dev/null; then
    hwmon_dir=$(dirname "$hwmon")
    # Find all temp*_input files
    for temp_input in "$hwmon_dir"/temp*_input; do
      if [ -r "$temp_input" ]; then
        echo "\"$temp_input\""
      fi
    done
    exit 0
  fi
done

echo "[]"
