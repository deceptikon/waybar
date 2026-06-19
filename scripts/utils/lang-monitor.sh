#!/bin/bash

# Event-driven keyboard layout monitor for Waybar
# Hides on English, shows only on non-English layouts

get_layout() {
  layout=$(swaymsg -t get_inputs | jq -r '.[] | select(.type=="keyboard") | .xkb_active_layout_name' | head -1)
  lang_code="${layout:0:2}"
  
  # Hide indicator on English
  if [[ "${lang_code^^}" == "EN" ]]; then
    echo "{\"text\":\"\",\"class\":\"hidden\"}"
  else
    echo "{\"text\":\"${lang_code^^}\",\"class\":\"active\"}"
  fi
}

# Initial state
get_layout

# Subscribe to input events
swaymsg -t subscribe -m '["input"]' | while read -r _; do
  get_layout
done
