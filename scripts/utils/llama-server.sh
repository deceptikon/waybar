#!/bin/bash
set -uo pipefail

PORT=22222
CLASS="llama-server-term"
export GGUF_PATH="/home/lexx/.MODELS/gemma4-coding-q4_k_m.gguf"

health() {
    curl -sf --max-time 2 "http://127.0.0.1:$PORT/health" 2>/dev/null || true
}

status() {
    local hdrs
    hdrs=$(health)
    if [ -z "$hdrs" ]; then
        jq -nc '{text:"󱚢", class:"off", tooltip:"llama-server: OFF"}'
        return
    fi
    local active
    active=$(echo "$hdrs" | jq -r '(.slots_processing // 0) > 0' 2>/dev/null)
    if [ "$active" = "true" ]; then
        jq -nc '{text:"󱚣", class:"active", tooltip:"llama-server: ACTIVE"}'
    else
        jq -nc '{text:"󱙺", class:"idle", tooltip:"llama-server: IDLE"}'
    fi
}

start_server() {
    notify-send "suka" "$GGUF_PATH"
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
                --host 127.0.0.1 --port '"$PORT"'
        ' &
    disown
}

stop_server() {
    pkill -f "kitty.*--class $CLASS" 2>/dev/null || true
    sleep 0.3
    pkill -f "llama-server.*--port $PORT" 2>/dev/null || true
}

case "${1:-status}" in
    start) start_server && { sleep 1; pkill -SIGRTMIN+22 waybar 2>/dev/null || true; } ;;
    stop) stop_server; pkill -SIGRTMIN+22 waybar 2>/dev/null || true ;;
    restart) stop_server; sleep 0.5; start_server && { sleep 1; pkill -SIGRTMIN+22 waybar 2>/dev/null || true; } ;;
    *) status ;;
esac
