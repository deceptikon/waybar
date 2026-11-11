#!/usr/bin/env bash
# ollama-status.sh — local ollama server status for waybar
set -euo pipefail

source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

OLLAMA_HOST="localhost:11111"
LOG_FILE="$LOG_DIR/ollama.log"

if ! curl -sS "http://${OLLAMA_HOST}/api/tags" >"$LOG_FILE" 2>&1; then
    emit_json "󱚣 DOWN" "off" "Ollama is not running"
    exit 0
fi

models=$(OLLAMA_HOST="$OLLAMA_HOST" ollama ps 2>>"$ERRLOG" \
    | awk 'NR>1 {print $1}' \
    | paste -sd ' ' -)

if [[ -n "$models" ]]; then
    emit_json "󱚣 $models" "on" "Running: $models"
else
    emit_json "󱚣 UP" "on" "Ollama is running (no models loaded)"
fi
