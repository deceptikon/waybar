#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

OUTPUT="HDMI-A-1"

for cmd in ddcutil swaymsg jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        emit_json "󰍹<sup>?</sup>" "unknown" "Missing: $cmd"
        exit 0
    fi
done

get_info() {
    swaymsg -t get_outputs | jq --arg o "$OUTPUT" '.[] | select(.name==$o)'
}

emit() {
    local info="$1"
    if [[ -z "$info" ]]; then
        emit_json "󰍹<sup>󱚦</sup>" "disconnected" "External display: DISCONNECTED"
        return
    fi

    local on
    on=$(echo "$info" | jq -r '.dpms')
    if [[ "$on" = "true" ]]; then
        emit_json "󰍹<sup>󰄬</sup>" "on" "External display: ON ($OUTPUT)"
    else
        emit_json "󰍺<sup>󰄭</sup>" "off" "External display: OFF ($OUTPUT)"
    fi
}

if [[ "${1:-}" != "refresh" ]]; then
    info=$(get_info)
    if [[ -z "$info" ]]; then
        (set +e; sleep 0.5; ddcutil setvcp D6 1; swaymsg output "$OUTPUT" dpms on; swaymsg output "$OUTPUT" enable; signal_waybar SIGRTMIN+11) & disown
    else
        on=$(echo "$info" | jq -r '.dpms')
        if [[ "$on" = "true" ]]; then
            (set +e; sleep 0.2; swaymsg output "$OUTPUT" dpms off; swaymsg output "$OUTPUT" disable; ddcutil setvcp D6 5; signal_waybar SIGRTMIN+11) & disown
        else
            (set +e; sleep 0.2; ddcutil setvcp D6 1; swaymsg output "$OUTPUT" dpms on; swaymsg output "$OUTPUT" enable; signal_waybar SIGRTMIN+11) & disown
        fi
    fi
    exit 0
fi

emit "$(get_info)"
