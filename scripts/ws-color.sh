#!/bin/bash
# Outputs the focused workspace number as a Waybar JSON class.
# Used by custom/ws-color module to drive pure-CSS titlebox coloring.
# No file writes, no reloads — just a class signal.

WS_NUM=$(swaymsg -t get_workspaces 2>/dev/null \
    | jq '.[] | select(.focused==true) | .num' \
    || echo 1)
WS_NUM=${WS_NUM:-1}

printf '{"text":" %s ","class":"ws%s","tooltip":"Workspace %s"}\n' "$WS_NUM" "$WS_NUM" "$WS_NUM"
