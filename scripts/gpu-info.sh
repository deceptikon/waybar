#!/bin/bash
set -euo pipefail
# gpu-info.sh — Waybar GPU module
#
# Auto-starts gpu-collector daemon if not running, reads latest
# sample from /dev/shm/gpu-stats.jsonl, formats with draw_module,
# and outputs Waybar JSON.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/lib/draw-module.sh"
source "$LIB"

COLLECTOR="$SCRIPT_DIR/gpu-collector.sh"
JSONL_FILE="/dev/shm/gpu-stats.jsonl"
PIDFILE="/dev/shm/gpu-collector.pid"
ACCENT="#fab387"  # peach
WAIT_LIMIT=3      # max seconds to wait for first data

# ── Ensure collector is running ──
ensure_collector() {
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid=$(<"$PIDFILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0  # already running
    fi
    rm -f "$PIDFILE"
  fi

  nohup "$COLLECTOR" >/dev/null 2>&1 &
  local waited=0
  while [[ ! -f "$JSONL_FILE" && "$waited" -lt "$WAIT_LIMIT" ]]; do
    sleep 0.5
    waited=$((waited + 1))
  done
}

# ── Read latest sample ──
read_latest() {
  if [[ ! -f "$JSONL_FILE" ]]; then
    echo ""
    return
  fi
  tail -1 "$JSONL_FILE" 2>/dev/null || echo ""
}

# ── Format stats for display ──
format_stats() {
  local json="$1"
  if [[ -z "$json" ]]; then
    draw_module "GPU --" "MEM --" "$ACCENT" "good"
    exit 0
  fi

  local gpu_pct mem_used mem_total temp_c freq_sclk power_w
  gpu_pct=$(jq -r '.gpu_pct // 0' <<< "$json")
  mem_used=$(jq -r '.mem_used // 0' <<< "$json")
  mem_total=$(jq -r '.mem_total // 0' <<< "$json")
  temp_c=$(jq -r '.temp_c // 0' <<< "$json")
  freq_sclk=$(jq -r '.freq_sclk // 0' <<< "$json")
  power_w=$(jq -r '.power_w // 0' <<< "$json")

  # Clamp
  [[ "$gpu_pct" -gt 100 ]] && gpu_pct=100
  [[ "$gpu_pct" -lt 0 ]] && gpu_pct=0

  # Determine class
  local cls="good"
  if   [[ "$gpu_pct" -ge 90 ]]; then cls="critical"
  elif [[ "$gpu_pct" -ge 70 ]]; then cls="warning"
  elif [[ "$gpu_pct" -ge 40 ]]; then cls="medium"
  fi

  # Visual GPU usage bar (4 segments)
  local segments=4
  local filled=$((gpu_pct * segments / 100))
  [[ "$filled" -gt "$segments" ]] && filled=$segments
  [[ "$filled" -lt 0 ]] && filled=0
  local empty=$((segments - filled))

  local bar=""
  for ((i=0; i<filled; i++)); do bar+="▐"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done

  # Memory display: convert bytes to human
  local mem_str
  if [[ "$mem_total" -gt 0 ]]; then
    mem_str=$(awk "BEGIN{printf \"%.1fG\", $mem_used/1073741824}")"/"$(awk "BEGIN{printf \"%.1fG\", $mem_total/1073741824}")
  else
    mem_str="--"
  fi

  # Row 1: GPU usage bar + percent + clock
  local row1="GPU${bar} ${gpu_pct}%  ${freq_sclk}MHz"
  # Row 2: memory + temp + power
  local row2="MEM ${mem_str}  ${temp_c}°C  ${power_w}W"

  draw_module "$row1" "$row2" "$ACCENT" "$cls"
}

# ── Main ──
ensure_collector
latest=$(read_latest)
format_stats "$latest"
