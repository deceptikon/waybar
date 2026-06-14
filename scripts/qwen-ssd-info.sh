#!/bin/bash

# SSD info tile — label + used/total + %, color class by usage

device=$(df / | tail -1 | awk '{print $1}')
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')
total_human=$(df --output=size -h / | tail -1 | tr -d ' ')
used_human=$(df --output=used -h / | tail -1 | tr -d ' ')

# Parent disk for label/model fallback
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

# Try label (partition) → model (parent disk) → parent disk name
label=$(lsblk -no LABEL "$device" 2>/dev/null | head -1)
if [ -z "$label" ]; then
  label=$(lsblk -dno MODEL "/dev/$parent" 2>/dev/null | head -1 | awk '{print $1}')
fi
[ -z "$label" ] && label="$parent"
[ ${#label} -gt 14 ] && label="${label:0:11}…"

# Color class by usage %
if   [ "$usage_pct" -ge 95 ]; then cls="critical"
elif [ "$usage_pct" -ge 85 ]; then cls="warning"
elif [ "$usage_pct" -ge 70 ]; then cls="medium"
else cls="good"; fi

# Two-row Pango markup (matches wifi info style)
text=$(printf "<b>%s</b>\n<span size='small' style='italic'>%s/%s · %d%%</span>" \
  "$label" "$used_human" "$total_human" "$usage_pct")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$cls" \
  '{text: $text, class: $cls}'
