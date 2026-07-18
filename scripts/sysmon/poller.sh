#!/usr/bin/env bash
# poller.sh — single writer: collect|map → feeds/sysmon.json → formatter
set -uo pipefail   # no -e: one bad cycle must not kill the daemon

DIR="$(cd "$(dirname "$0")" && pwd)"
WAYBAR_ROOT="$(cd "$DIR/../.." && pwd)"
CFG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"

# prefer live config location for feeds (waybar always tails here)
FEEDS="${SYSMON_FEEDS:-$CFG_HOME/feeds}"
LOG_DIR="${SYSMON_LOG_DIR:-$CFG_HOME/logs}"
mkdir -p "$FEEDS" "$LOG_DIR"
LOG="$LOG_DIR/sysmon.log"

# root sysmon.env then optional local override
# shellcheck disable=SC1091
[ -f "$CFG_HOME/sysmon.env" ] && . "$CFG_HOME/sysmon.env"
# shellcheck disable=SC1091
[ -f "$WAYBAR_ROOT/sysmon.env" ] && . "$WAYBAR_ROOT/sysmon.env"
# shellcheck disable=SC1091
[ -f "$DIR/sysmon.env" ] && . "$DIR/sysmon.env"

SLEEP="${SYSMON_POLL_SLEEP:-2}"
log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

for f in gpu cpu ram ssd netfan compact-gpu compact-cpu compact-ram compact-ssd compact-netfan; do
  [ -f "$FEEDS/$f.json" ] || printf '%s\n' '{"text":"…","class":"good"}' >"$FEEDS/$f.json"
done
[ -f "$FEEDS/sysmon.json" ] || echo '{}' >"$FEEDS/sysmon.json"

exec 9>"$FEEDS/.poller.lock"
if ! flock -n 9; then
  msg="poller: already running (lock $FEEDS/.poller.lock)"
  log "$msg"
  echo "$msg" >&2
  exit 0
fi
log "poller start pid=$$ feeds=$FEEDS dir=$DIR"

while true; do
  t0=$(date +%s)
  if ! "$DIR/collect.sh" 2>>"$LOG" \
      | "$DIR/mapper.sh" >"$FEEDS/sysmon.json.tmp" 2>>"$LOG"; then
    log "collect|map failed"
    rm -f "$FEEDS/sysmon.json.tmp"
    sleep "$SLEEP"
    continue
  fi
  mv "$FEEDS/sysmon.json.tmp" "$FEEDS/sysmon.json"

  if ! bash "$DIR/formatter.sh" <"$FEEDS/sysmon.json" >>"$LOG" 2>&1; then
    log "formatter failed"
  fi

  avg=$(jq -r '.cpu.avg // "?"' "$FEEDS/sysmon.json" 2>/dev/null || echo '?')
  log "ok $(( $(date +%s) - t0 ))s cpu=${avg}"
  sleep "$SLEEP"
done
