#!/bin/bash
set -euo pipefail

PORT=22222
PIDFILE="/tmp/llama-server.pid"

toggle() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    else
        export OMP_NUM_THREADS=16
        export GOMP_CPU_AFFINITY="0-15"
        nohup ~/Q/llama.cpp/build/bin/llama-server \
            -m "${GGUF_PATH:?GGUF_PATH not set}" \
            --ctx-size 16384 \
            --n-gpu-layers 99 \
            --no-mmap \
            -fa on \
            --cache-type-k q8_0 \
            --cache-type-v q8_0 \
            --temp 1.0 \
            --top-p 0.95 \
            --top-k 64 \
            --host 127.0.0.1 \
            --port "$PORT" &>/dev/null &
        echo $! > "$PIDFILE"
    fi
    pkill -SIGRTMIN+22 waybar || true
}

status() {
    local running=false
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        running=true
    elif command -v ss &>/dev/null && ss -tln 2>/dev/null | grep -q ":$PORT"; then
        running=true
    fi

    if $running; then
        jq -n --compact-output \
            --arg text "󰦝" \
            --arg class "running" \
            --arg tooltip "llama-server: Running on port $PORT" \
            '{text: $text, class: $class, tooltip: $tooltip}'
    else
        jq -n --compact-output \
            --arg text "󰦞" \
            --arg class "stopped" \
            --arg tooltip "llama-server: Stopped (click to toggle)" \
            '{text: $text, class: $class, tooltip: $tooltip}'
    fi
}

case "${1:-status}" in
    toggle) toggle ;;
    status|*) status ;;
esac
