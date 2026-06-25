#!/bin/bash
if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    jq -n '{text:"󰤮", class:"disabled", tooltip:"WiFi disabled"}'
    exit 0
fi
if iwgetid -r 2>/dev/null | grep -q .; then
    jq -n '{text:"󰤨", class:"connected", tooltip:"Connected to '"$(iwgetid -r)"'"}'
else
    jq -n '{text:"󰤨", class:"enabled", tooltip:"WiFi on (no connection)"}'
fi
