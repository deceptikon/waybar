#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

PORT=22222
CLASS="llama-server-term"
export GGUF_PATH="$HOME/.MODELS/gemma4-coding-q4_k_m.gguf"

health() {
    # On success, print the JSON body (used by status()). On failure, print
    # nothing and log the curl diagnostic to the project error log.
    local body rc
    body=$(curl -sS -f --max-time 2 --connect-timeout 1 \
        "http://127.0.0.1:${PORT}/health" 2>&1)
    rc=$?
    if (( rc == 0 )); then
        rm -f "$STATE_DIR/llama_health_lastlog"
        printf '%s' "$body"
        return 0
    fi

    local now last=0
    now=$(date +%s)
    if [[ -f "$STATE_DIR/llama_health_lastlog" ]]; then
        last=$(cat "$STATE_DIR/llama_health_lastlog" 2>/dev/null || echo 0)
    fi
    case "$last" in ''|*[!0-9]*) last=0 ;; esac

    local log_cooldown=300
    if [[ $body == *refused* || $body == *timed\ out* || $body == *Timeout* || $rc -eq 7 || $rc -eq 28 ]]; then
        if (( now - last >= log_cooldown )); then
            log_error "llama" "down rc=$rc $body"
            echo "$now" >"$STATE_DIR/llama_health_lastlog"
        fi
    else
        log_error "llama" "error rc=$rc $body"
        echo "$now" >"$STATE_DIR/llama_health_lastlog"
    fi
    return "$rc"
}

status() {
    local hdrs active
    hdrs=$(health)
    if [[ -z "$hdrs" ]]; then
        emit_json "󱚢" "off" "llama-server: OFF"
        return
    fi
    active=$(echo "$hdrs" | jq -r '(.slots_processing // 0) > 0' 2>>"$ERRLOG")
    if [[ "$active" = "true" ]]; then
        emit_json "󱚣" "active" "llama-server: ACTIVE"
    else
        emit_json "󱙺" "idle" "llama-server: IDLE"
    fi
}

start_server() {
    if [[ ! -r "${GGUF_PATH:-}" ]]; then
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
    pkill -f "kitty.*--class $CLASS" 2>>"$ERRLOG" || log_error "llama" "pkill kitty failed"
    sleep 0.3
    pkill -f "llama-server.*--port $PORT" 2>>"$ERRLOG" || log_error "llama" "pkill llama-server failed"
}

refresh() {
    signal_waybar SIGRTMIN+22
}

case "${1:-status}" in
    start) start_server && { sleep 1; refresh; } ;;
    stop)  stop_server; refresh ;;
    restart) stop_server; sleep 0.5; start_server && { sleep 1; refresh; } ;;
    *) status ;;
esac
