#!/bin/bash

# SSD icon tile — single disk icon (SSD or HDD)
# Uses printf with exact UTF-8 bytes (Monaspace Nerd Font glyphs)

DEVICE=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${DEVICE#/dev/}"

# Main icon: SSD vs HDD via rotational flag
rotational=1
if [ -r "/sys/block/$parent/queue/rotational" ]; then
  rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
fi

# nf-mdi-ssd = U+F0CCA  bytes: f3 b0 b3 8a
# nf-mdi-harddisk = U+F0CC9 bytes: f3 b0 b3 89
if [ "$rotational" = "0" ]; then
  icon=$(printf '\xf3\xb0\xb3\x8a')
else
  icon=$(printf '\xf3\xb0\xb3\x89')
fi

jq -n --compact-output \
  --arg txt "$icon" \
  '{text: $txt, class: "icon"}'
