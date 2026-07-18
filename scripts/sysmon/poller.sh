#!/usr/bin/env bash
# poller.sh — single writer for feeds/sysmon.json + module feeds
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FEEDS="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/feeds"
ENV_FILE="$DIR/sysmon.env"
mkdir -p "$FEEDS"

# shellcheck source=/dev/null
[ -f "$ENV_FILE" ] && . "$ENV_FILE"
SLEEP="${SYSMON_POLL_SLEEP:-2}"

# seed empty feeds so tail -F has a file
for f in gpu cpu ram ssd netfan \
         compact-gpucompact-cpu compact-cpu compact-ram compact-ssd compact-netfan sysmon; do
  true
done
for f in gpu cpu ram ssd netfan compact-gpu compact-cpu compact-ram compact-ssd compact-netfan; do
  [ -f "$FEEDS/$f.json" ] || echo '{"text":"…","class":"good"}' > "$FEEDS/$f.json"
done
[ -f "$FEEDS/sysmon.json" ] || echo '{}' > "$FEEDS/sysmon.json"

# flock prevents duplicate pollers
exec 9>"$FEEDS/.poller.lock"
if ! flock -n 9; then
  echo "poller: already running" >>/tmp/waybar_errors.log
  exit 0
fi

while true; do
  if "$DIR/collect.sh" | "$DIR/mapper.sh" > "$FEEDS/sysmon.json.tmp" 2>>/tmp/waybar_errors.log; then
    mv "$FEEDS/sysmon.json.tmp" "$FEEDS/sysmon.json"
    bash "$DIR/formatter.sh" < "$FEEDS/sysmon.json" 2>>/tmp/waybar_errors.log || \
      echo "poller: formatter failed: $?" >>/tmp/waybar_errors.log
  else
    echo "poller: collect|map failed: $?" >>/tmp/waybar_errors.log
    rm -f "$FEEDS/sysmon.json.tmp"
  fi
  sleep "$SLEEP"
done
