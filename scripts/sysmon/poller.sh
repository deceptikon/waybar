#!/usr/bin/env bash
set -euo pipefail
# sysmon-poller.sh — Background loop: collect data, write JSON cache.
#   Writes /tmp/sysmon.json every 2 seconds.
#   Start once via sway exec_always or systemd user service.

DIR="$(cd "$(dirname "$0")" && pwd)"
while true; do
  "$DIR/collect.sh" | "$DIR/mapper.sh" > /tmp/sysmon.json.tmp
  mv /tmp/sysmon.json.tmp /tmp/sysmon.json
  bash "$DIR/formatter.sh" < /tmp/sysmon.json
  sleep 2
done
