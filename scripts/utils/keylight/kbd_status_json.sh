#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

PID_FILE="$RUNTIME_DIR/keywatcher.pid"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>>"$ERRLOG"; then
    emit_json "󰛨 <sup></sup>" "active" "Auto-backlight is ENABLED"
else
    emit_json "󰌶 <sup></sup>" "inactive" "Auto-backlight is DISABLED"
fi
