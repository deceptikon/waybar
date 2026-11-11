#!/usr/bin/env bash
# lang-indicator.sh — keyboard layout indicator for top bar
set -euo pipefail

source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

layout=$(swaymsg -t get_inputs 2>>"$ERRLOG" \
    | jq -r '.[] | select(.type=="keyboard") | .xkb_active_layout_name' 2>>"$ERRLOG" \
    | head -1)
lang_code="${layout:0:2}"

if [[ "${lang_code^^}" == "EN" ]]; then
    emit_json "" "hidden" ""
else
    emit_json "${lang_code^^}" "active" ""
fi
