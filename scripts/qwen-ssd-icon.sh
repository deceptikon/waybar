#!/bin/bash

# SSD icon tile — main disk icon + temperature badge

device=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

# Main icon: SSD vs HDD
rotational=1
if [ -r "/sys/block/$parent/queue/rotational" ]; then
  rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
fi

if [ "$rotational" = "0" ]; then
  main_icon=""   # NF-MDFI_SSD
else
  main_icon=""   # NF-MDFI_HDD
fi

# Secondary badge: temperature from hwmon (millidegrees C)
temp_input=""
for hwmon_path in "/sys/block/$parent/device/hwmon"*/temp*_input; do
  if [ -r "$hwmon_path" ]; then
    temp_input="$hwmon_path"
    break
  fi
done

temp_c=0
if [ -n "$temp_input" ]; then
  temp_raw=$(cat "$temp_input" 2>/dev/null || echo "0")
  temp_c=$((temp_raw / 1000))
fi

# Color class by temperature
if   [ "$temp_c" -ge 80 ]; then badge_class="critical"
elif [ "$temp_c" -ge 70 ]; then badge_class="warning"
elif [ "$temp_c" -ge 60 ]; then badge_class="medium"
else badge_class="good"; fi

# Small badge icon for temperature
if   [ "$temp_c" -ge 70 ]; then badge_icon=""   # NF-MDFI_WARNING
elif [ "$temp_c" -gt 0 ];    then badge_icon="" # MDI_LIGHTBULB_ON / thermometer-ish
else badge_icon=""   # placeholder

fi


jq -n --compact-output \
  --arg main "$main_icon" \
  --arg badge "$badge_icon" \
  --arg cls "$badge_class" \
  '{text: ($main + $badge), class: ("icon " + $cls)}'
