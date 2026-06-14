#!/bin/bash

# SSD icon tile — single disk icon
# Uses printf with exact UTF-8 bytes (Monaspace Nerd Font glyphs)

DEVICE=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${DEVICE#/dev/}"

# Main icon: SSD vs HDD via rotational flag
rotational=1
if [ -r "/sys/block/$parent/queue/rotational" ]; then
  rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
fi

# nf-mdi-harddisk = U+F1629 bytes: f3 b1 98 a9
# nf-mdi-ssd = U+F1632 bytes: f3 b1 98 b2
if [ "$rotational" = "0" ]; then
  icon=$(printf '\xf3\xb1\x98\xb2')
else
  icon=$(printf '\xf3\xb1\x98\xa9')
fi

jq -n --compact-output \
  --arg txt "$icon" \
  '{text: $txt, class: "icon"}'
