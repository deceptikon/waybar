#!/bin/bash
# Workspace color signal sender.
# Fires SIGRTMIN+8 → triggers custom/ws-color module refresh (class update, no CSS reload).
# Mode hiding is handled entirely by CSS. No file writes. No SIGUSR2. No crashes.

swaymsg -t subscribe -m '["workspace"]' | while IFS= read -r _; do
    pkill -SIGRTMIN+8 waybar 2>/dev/null || true
done
