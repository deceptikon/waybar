#!/bin/bash

# SSD/HDD icon tile — uses parent disk's rotational flag to pick icon
device=$(df / | tail -1 | awk '{print $1}')
# Parent disk (strip partition suffix)
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

rotational=1
if [ -r "/sys/block/$parent/queue/rotational" ]; then
  rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
fi

if [ "$rotational" = "0" ]; then
  icon=""   # NF-MDFI_SSD
else
  icon=""   # NF-MDFI_HDD
fi

jq -n --compact-output \
  --arg text "$icon" \
  '{text: $text, class: "icon"}'
