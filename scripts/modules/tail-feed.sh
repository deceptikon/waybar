#!/usr/bin/env bash
# tail-feed.sh — tail a sysmon feed by basename
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

FEED="${1:-}"
if [[ -z "$FEED" || "$FEED" =~ [^A-Za-z0-9_-] ]]; then
    log_error "tail-feed" "invalid feed name: $FEED"
    emit_json "?" "error" "invalid feed name"
    exit 1
fi

exec tail -F "$WAYBAR_HOME/feeds/${FEED}.json"
