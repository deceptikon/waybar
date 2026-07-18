#!/bin/bash
set -uo pipefail

PORT=22222
CLASS="llama-server-term"
export GGUF_PATH="$HOME/.MODELS/gemma4-coding-q4_k_m.gguf"

health() {
  local err_log=/tmp/waybar_errors.log
  local stamp_file=/tmp/llama_health_lastlog
  local cooldown=300
  local err rc now last=0

  err=$(curl -sS -f --max-time 2 --connect-timeout 1 \
    "http://127.0.0.1:${PORT}/health" 2>&1 >/dev/null)
  rc=$?
  (( rc == 0 )) && { rm -f "$stamp_file"; return 0; }

  now=$(date +%s)
  [[ -f $stamp_file ]] && last=$(cat "$stamp_file")

  # always log "interesting" failures; throttle refusal/timeout
  if [[ $err == *refused* || $err == *timed\ out* || $err == *Timeout* || $rc -eq 7 || $rc -eq 28 ]]; then
    if (( now - last >= cooldown )); then
      printf '%s [llama] down rc=%s %s\n' "$(date -Iseconds)" "$rc" "$err" >>"$err_log"
      echo "$now" >"$stamp_file"
    fi
  else
    printf '%s [llama] error rc=%s %s\n' "$(date -Iseconds)" "$rc" "$err" >>"$err_log"
    echo "$now" >"$stamp_file"
  fi
  return "$rc"
health() {
  local err_log=/tmp/waybar_errors.log
  local stamp_file=/tmp/llama_health_lastlog
  local cooldown=300
  local err rc now last=0

  err=$(curl -sS -f --max-time 2 --connect-timeout 1 \
    "http://127.0.0.1:${PORT}/health" 2>&1 >/dev/null)
  rc=$?
  (( rc == 0 )) && { rm -f "$stamp_file"; return 0; }

  now=$(date +%s)
  [[ -f $stamp_file ]] && last=$(cat "$stamp_file")

  # always log "interesting" failures; throttle refusal/timeout
  if [[ $err == *refused* || $err == *timed\ out* || $err == *Timeout* || $rc -eq 7 || $rc -eq 28 ]]; then
    if (( now - last >= cooldown )); then
      printf '%s [llama] down rc=%s %s\n' "$(date -Iseconds)" "$rc" "$err" >>"$err_log"
      echo "$now" >"$stamp_file"
    fi
  else
    printf '%s [llama] error rc=%s %s\n' "$(date -Iseconds)" "$rc" "$err" >>"$err_log"
    echo "$now" >"$stamp_file"
  fi
  return "$rc"
}

status() {
    local hdrs
    hdrs=$(health)
    if [ -z "$hdrs" ]; then
        jq -nc '{text:"󱚢", class:"off", tooltip:"llama-server: OFF"}'
        return
    fi
    local active
    active=$(echo "$hdrs" | jq -r '(.slots_processing // 0) > 0' 2>>/tmp/waybar_errors.log)
    if [ "$active" = "true" ]; then
        jq -nc '{text:"󱚣", class:"active", tooltip:"llama-server: ACTIVE"}'
    else
        jq -nc '{text:"󱙺", class:"idle", tooltip:"llama-server: IDLE"}'
    fi
}

start_server() {
    if [ ! -r "${GGUF_PATH:-}" ]; then
        notify-send "llama-server" "GGUF_PATH not readable: ${GGUF_PATH:-unset}"
        return 1
    fi
    stop_server
    sleep 0.3
    kitty --hold --class "$CLASS" --title "llama-server" \
        bash -c '
            export OMP_NUM_THREADS=16 GOMP_CPU_AFFINITY="0-15"
            exec ~/Q/llama.cpp/build/bin/llama-server \
                -m "$GGUF_PATH" --ctx-size 16384 --n-gpu-layers 99 --no-mmap \
                -fa on --cache-type-k q8_0 --cache-type-v q8_0 \
                --temp 1.0 --top-p 0.95 --top-k 64 \
                --host 127.0.0.1 --port '"$PORT"' --tools all
        ' &
    disown
}

stop_server() {
    pkill -f "kitty.*--class $CLASS" 2>>/tmp/waybar_errors.log || echo "Command failed [pkill]: $?" >>/tmp/waybar_errors.log
    sleep 0.3
    pkill -f "llama-server.*--port $PORT" 2>>/tmp/waybar_errors.log || echo "Command failed [pkill]: $?" >>/tmp/waybar_errors.log
}

case "${1:-status}" in
    start) start_server && { sleep 1; pkill -SIGRTMIN+22 waybar 2>>/tmp/waybar_errors.log || echo "Command failed [pkill]: $?" >>/tmp/waybar_errors.log; } ;;
    stop) stop_server; pkill -SIGRTMIN+22 waybar 2>>/tmp/waybar_errors.log || echo "Command failed [pokil]: $?" >>/tmp/waybar_errors.log ;;
    restart) stop_server; sleep 0.5; start_server && { sleep 1; pkill -SIGRTMIN+22 waybar 2>>/tmp/waybar_errors.log || echo "Command failed [restart] : $?" >>/tmp/waybar_errors.log; } ;;
    *) status ;;
esac
