#!/usr/bin/env bash
# recorder-status.sh — wf-recorder state indicator
set -euo pipefail

source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    emit_json "󰨜 <sup>󰑊</sup>" "recording"
else
    emit_json "󰨜 <sup></sup>" "stopped"
fi
