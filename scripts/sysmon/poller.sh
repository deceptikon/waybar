#!/usr/bin/env bash
# poller.sh — single writer for feeds/sysmon.json + module feeds
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
WAYBAR_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
FEEDS="${WAYBAR_HOME}/feeds"
LOG_DIR="${WAYBAR_HOME}/logs"
ENV_FILE="${WAYBAR_HOME}/sysmon.env"
SYSMON_LOG="${SYSMON_LOG:-$LOG_DIR/sysmon.log}"

mkdir -p "$FEEDS" "$LOG_DIR"

if [ -f "$ENV_FILE" ]; then
  # Optional SYSMON_* overrides (see sysmon.env)
  . "$ENV_FILE"
fi

SLEEP="${SYSMON_POLL_SLEEP:-2}"

log() {
  printf '%s poller: %s\n' "$(date -Iseconds)" "$*" >>"$SYSMON_LOG"
}

# Seed feeds so waybar tail -F always has a target
seed_modules=(
  gpu cpu ram ssd netfan
  compact-gpu compact-cpu compact-ram compact-ssd compact-netfan
)
for name in "${seed_modules[@]}"; do
  if [ ! -f "$FEEDS/${name}.json" ]; then
    printf '%s\n' '{"text":"…","class":"good"}' >"$FEEDS/${name}.json"
  fi
done
if [ ! -f "$FEEDS/sysmon.json" ]; then
  printf '%s\n' '{}' >"$FEEDS/sysmon.json"
fi

# One poller only
exec 9>"$FEEDS/.poller.lock"
if ! flock -n 9; then
  log "already running — exit"
  exit 0
fi

printf '%s\n' $$ >"$LOG_DIR/sysmon-poller.pid"
log "start pid=$$ sleep=${SLEEP}s env=$ENV_FILE feeds=$FEEDS"

cleanup() {
  rm -f "$LOG_DIR/sysmon-poller.pid"
}
trap cleanup EXIT

while true; do
  rc=0
  if ! "$DIR/collect.sh" | "$DIR/mapper.sh" >"$FEEDS/sysmon.json.tmp"; then
    rc=$?
    log "collect|map failed rc=$rc"
    rm -f "$FEEDS/sysmon.json.tmp"
  else
    mv "$FEEDS/sysmon.json.tmp" "$FEEDS/sysmon.json"
    if ! bash "$DIR/formatter.sh" <"$FEEDS/sysmon.json"; then
      log "formatter failed rc=$?"
    fi
  fi
  sleep "$SLEEP"
done
