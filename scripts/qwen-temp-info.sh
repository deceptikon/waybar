#!/bin/bash
set -euo pipefail

# Get CPU temperature
cpu_temp=$(sensors k10temp-pci-00c3 2>/dev/null | awk '/Tctl:/ {gsub(/[+°C]/,"",$2); print $2}')
if [ -z "$cpu_temp" ]; then
    cpu_temp=$(sensors 2>/dev/null | awk '/Tctl|Tdie/ {gsub(/[+°C]/,"",$2); print $2; exit}')
fi

if [ -z "$cpu_temp" ]; then
    cpu_temp="--"
    temp_class="good"
else
    temp_int=${cpu_temp%.*}
    if [ "$temp_int" -gt 85 ]; then temp_class="critical"
    elif [ "$temp_int" -gt 60 ]; then temp_class="warning"
    elif [ "$temp_int" -gt 40 ]; then temp_class="medium"
    else temp_class="good"; fi
fi

# Get fan RPM
fan_rpm=$(cat /sys/class/hwmon/hwmon8/fan1_input 2>/dev/null || echo "0")
fan_rpm2=$(cat /sys/class/hwmon/hwmon8/fan2_input 2>/dev/null || echo "0")

# Determine fan class
if [ "$fan_rpm" -eq 0 ] && [ "$fan_rpm2" -eq 0 ]; then
    fan_class="good"
    fan_display="0 RPM"
elif [ "$fan_rpm" -gt 3000 ] || [ "$fan_rpm2" -gt 3000 ]; then
    fan_class="critical"
    fan_display="${fan_rpm}/${fan_rpm2}"
elif [ "$fan_rpm" -gt 2000 ] || [ "$fan_rpm2" -gt 2000 ]; then
    fan_class="warning"
    fan_display="${fan_rpm}/${fan_rpm2}"
else
    fan_class="good"
    fan_display="${fan_rpm}/${fan_rpm2}"
fi

# Overall class
if [ "$temp_class" = "critical" ] || [ "$fan_class" = "critical" ]; then overall_class="critical"
elif [ "$temp_class" = "warning" ] || [ "$fan_class" = "warning" ]; then overall_class="warning"
elif [ "$temp_class" = "medium" ] || [ "$fan_class" = "medium" ]; then overall_class="medium"
else overall_class="good"; fi

# Two-row layout
# Row 1: Temperature
# Row 2: Fan speed
text=$(printf "<b>%s°C</b>\n<span size='smaller'>\uf863 %s</span>" "$cpu_temp" "$fan_display")

jq -n --compact-output \
    --arg text "$text" \
    --arg class "$overall_class" \
    --arg tooltip "CPU: ${cpu_temp}°C | Fan1: ${fan_rpm} RPM | Fan2: ${fan_rpm2} RPM" \
    '{text: $text, class: $class, tooltip: $tooltip}'