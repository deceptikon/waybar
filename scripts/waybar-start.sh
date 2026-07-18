#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
# The correct XDG standard for logs is ~/.local/state
LOGS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
POLLER="${CFG_DIR}/scripts/sysmon/poller.sh"
PIDFILE="${LOGS_DIR}/sysmon-poller.pid"

# Now we create the folders (feeds still lives in config/cache though)
mkdir -p "$LOGS_DIR" "$CFG_DIR/feeds"

# Ensure the general start log doesn't grow infinitely (keeps last 50 lines)
if [[ -f "$LOGS_DIR/waybar-start.log" ]]; then
  tail -n 50 "$LOGS_DIR/waybar-start.log" > "$LOGS_DIR/waybar-start.log.tmp" 2>/dev/null && \
  mv "$LOGS_DIR/waybar-start.log.tmp" "$LOGS_DIR/waybar-start.log"
fi

log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOGS_DIR/waybar-start.log"; }

start_poller() {
  if [[ -f "$PIDFILE" ]]; then
    local old
    old=$(cat "$PIDFILE" 2>/dev/null || true)
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
      if tr '\0' ' ' <"/proc/$old/cmdline" 2>/dev/null | grep -q 'sysmon/poller'; then
        log "poller already pid=$old"
        return 0
      fi
    fi
  fi
  pkill -f "${CFG_DIR}/scripts/sysmon/poller.sh" 2>/dev/null || true
  rm -f "$CFG_DIR/feeds/.poller.lock" "$PIDFILE"
  sleep 0.2
  
  # Changed >> to > to overwrite the poller log on fresh starts
  nohup bash "$POLLER" >"$LOGS_DIR/sysmon.log" 2>&1 &
  echo $! >"$PIDFILE"
  log "poller started pid=$!"
}

stop_poller() {
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  pkill -f "${CFG_DIR}/scripts/sysmon/poller.sh" 2>/dev/null || true
  rm -f "$CFG_DIR/feeds/.poller.lock"
  log "poller stopped"
}

start_bars() {
  # Changed >> to > to overwrite logs on fresh starts (stops infinite growth)
  waybar -c "$CFG_DIR/config-top" -s "$CFG_DIR/style/top.css" \
    >"$LOGS_DIR/waybar-top.log" 2>&1 &
  sleep 0.4
  waybar -c "$CFG_DIR/config-vertical" -s "$CFG_DIR/style/vertical.css" \
    >"$LOGS_DIR/waybar-vertical.log" 2>&1 &
  sleep 0.4
  waybar -c "$CFG_DIR/config-vertical-lite" -s "$CFG_DIR/style/vertical-lite.css" \
    >"$LOGS_DIR/waybar-vertical-lite.log" 2>&1 &
  sleep 0.4
  waybar -c "$CFG_DIR/config-bottom" -s "$CFG_DIR/style/bottom.css" \
    >"$LOGS_DIR/waybar-bottom.log" 2>&1 &
}

stop_bars() {
  # kill every waybar we own, by absolute config path first, then name
  pkill -f "${CFG_DIR}/config-" 2>/dev/null || true
  pkill -x waybar 2>/dev/null || true
  # wait until gone (max ~2s)
  local i=0
  while pgrep -x waybar >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
    sleep 0.1
    i=$((i + 1))
  done
  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -9 -x waybar 2>/dev/null || true
    sleep 0.2
  fi
  log "bars stopped; remaining=$(pgrep -c -x waybar 2>/dev/null || echo 0)"
}

check_log() {
  local name="$1" file="$2" errors
  errors=$(tail -n 8 "$file" 2>/dev/null \
    | grep '\[error\]' \
    | grep -v 'power-profiles-daemon' \
    | grep -v 'desktop appearance' \
    | grep -v 'NameHasOwner' \
    | grep -v 'NameHasNoOwner' || true)
  if [[ -n "$errors" ]]; then
    command -v dunstify >/dev/null 2>&1 && \
      dunstify -u critical -t 0 "Waybar $name" "$errors" || true
    log "bar error $name: $errors"
  fi
}

deferred_checks() {
  sleep 2
  check_log top "$LOGS_DIR/waybar-top.log"
  check_log vertical "$LOGS_DIR/waybar-vertical.log"
  check_log vertical-lite "$LOGS_DIR/waybar-vertical-lite.log"
  check_log bottom "$LOGS_DIR/waybar-bottom.log"
}

case "${1:-start}" in
  start)
    start_poller
    start_bars
    deferred_checks &
    disown
    ;;
  stop)
    stop_bars
    stop_poller
    ;;
  reload)
    stop_bars
    stop_poller
    sleep 0.3
    start_poller
    start_bars
    deferred_checks &
    disown
    ;;
  poller-restart)
    stop_poller
    start_poller
    ;;
  *)
    echo "usage: $0 start|stop|reload|poller-restart" >&2
    exit 1
    ;;
esac
