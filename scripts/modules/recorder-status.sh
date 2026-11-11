#!/usr/bin/env bash
# recorder-status.sh — wf-recorder state indicator
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    emit_json "󰨜 <sup>󰑊</sup>" "recording"
else
    emit_json "󰨜 <sup></sup>" "stopped"
fi
