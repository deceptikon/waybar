#!/bin/bash

# System icon tile — single chip icon (CPU+RAM unified)
# Uses printf with exact UTF-8 bytes (Monaspace Nerd Font glyphs)

DEVICE=$(df / | tail -1 | awk '{print $1}')

# nf-mdi-chip = U+F0145 bytes: f3 b0 85 85  (system/processor chip)
icon=$(printf '\xf3\xb0\x85\x85')

jq -n --compact-output \
  --arg txt "$icon" \
  '{text: $txt, class: "icon"}'
