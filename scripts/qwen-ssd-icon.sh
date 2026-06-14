#!/bin/bash

# SSD icon tile — main disk icon + temperature badge
# Uses printf to embed exact UTF-8 bytes (Monaspace Nerd Font glyphs)

DEVICE=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${DEVICE#/dev/}"

# Main icon: SSD vs HDD via rotational flag
rotational=1
if [ -r "/sys/block/$parent/queue/rotational" ]; then
  rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
fi

# nf-mdi-ssd = U+F0CCA bytes: f3 b0 b3 8a
# nf-mdi-harddisk = U+F0CC9 bytes: f3 b0 b3 89
if [ "$rotational" = "0" ]; then
  main_icon=$(printf '\xf3\xb0\xb3\x8a')
else
  main_icon=$(printf '\xf3\xb0\xb3\x89')
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

# nf-mdi-thermometer = U+F050F bytes: f3 b0 94 8f
badge_icon=$(printf '\xf3\xb0\x94\x8f')

# Color class by temperature
if   [ "$temp_c" -ge 80 ]; then badge_cls="critical"
elif [ "$temp_c" -ge 70 ]; then badge_cls="warning"
elif [ "$temp_c" -ge 60 ]; then badge_cls="medium"
else badge_cls="good"; fi

jq -n --compact-output \
  --arg main "$main_icon" \
  --arg badge "$badge_icon" \
  --arg cls "$badge_cls" \
  '{text: ($main + " " + $badge), class: ("icon " + $cls)}'
