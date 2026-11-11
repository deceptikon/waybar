#!/usr/bin/env bash
# lang-indicator.sh — keyboard layout indicator for top bar
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

layout=$(swaymsg -t get_inputs 2>>"$ERRLOG" \
    | jq -r '[.[] | select(.type=="keyboard") | .xkb_active_layout_name] | first // ""' 2>>"$ERRLOG" \
    || true)
lang_code="${layout:0:2}"

if [[ -z "$lang_code" || "${lang_code^^}" == "EN" ]]; then
    emit_json "" "hidden" ""
else
    emit_json "${lang_code^^}" "active" ""
fi
