#!/usr/bin/env bash
set -euo pipefail
# sysmon-poller.sh — Background loop: collect data, write JSON cache.
#   Writes /tmp/sysmon.json every 2 seconds.
#   Start once via sway exec_always or systemd user service.

DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE="/tmp/sysmon.json"

while true; do
  tmp=$(mktemp /tmp/sysmon.XXXXXX.json)
  "$DIR/sysmon-collect.sh" | "$DIR/sysmon-mapper.sh" > "$tmp"
  mv "$tmp" "$CACHE"
  sleep 2
done
