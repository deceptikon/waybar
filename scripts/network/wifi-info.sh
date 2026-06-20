#!/bin/bash
set -euo pipefail

# Net info — two-row output: SSID (bold large) + speeds (small italic below)
wifi_info=$(nmcli -t -f active,ssid,signal,device dev wifi 2>/dev/null \
  | grep '^yes' | head -1 || true)

if [ -z "$wifi_info" ]; then
  jq -n --compact-output '{"text": "", "class": "disconnected"}'
  exit 0
fi

ssid=$(printf '%s' "$wifi_info" | cut -d: -f2)
signal=$(printf '%s' "$wifi_info" | cut -d: -f3)
iface=$(printf '%s' "$wifi_info" | cut -d: -f4)

[ ${#ssid} -gt 16 ] && ssid="${ssid:0:13}…"

# Signal-based class for info tile
if   [ "$signal" -ge 80 ] 2>/dev/null; then sig_cls="good"
elif [ "$signal" -ge 60 ] 2>/dev/null; then sig_cls="medium"
elif [ "$signal" -ge 40 ] 2>/dev/null; then sig_cls="warning"
elif [ "$signal" -ge 20 ] 2>/dev/null; then sig_cls="critical"
else sig_cls="disconnected"; fi

# Speed sampling — state-based rate calculation (no sleep on subsequent runs)
rx_fmt="0K"; tx_fmt="0K"; spd_cls="$sig_cls"
if [ -n "$iface" ] && [ "$iface" != "lo" ]; then
  STATE_FILE="/tmp/wifi-info-state-${iface}"
  
  current_time=$(date +%s.%N)
  rx_now=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx_now=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
  
  rx_kb=0
  tx_kb=0
  
  if [ -f "$STATE_FILE" ]; then
    read -r prev_time prev_rx prev_tx < "$STATE_FILE"
    delta_t=$(awk "BEGIN {print $current_time - $prev_time}")
    
    if (( $(awk "BEGIN {print ($delta_t > 0.05) ? 1 : 0}") )); then
      rx_bytes_diff=$((rx_now - prev_rx))
      tx_bytes_diff=$((tx_now - prev_tx))
      
      [ "$rx_bytes_diff" -lt 0 ] && rx_bytes_diff=0
      [ "$tx_bytes_diff" -lt 0 ] && tx_bytes_diff=0
      
      rx_kb=$(awk "BEGIN {printf \"%.0f\", ($rx_bytes_diff / $delta_t) / 1024}")
      tx_kb=$(awk "BEGIN {printf \"%.0f\", ($tx_bytes_diff / $delta_t) / 1024}")
    fi
  else
    # First run fallback: sleep 0.2s to sample
    sleep 0.2
    current_time2=$(date +%s.%N)
    rx_now2=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx_now2=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
    
    delta_t=$(awk "BEGIN {print $current_time2 - $current_time}")
    if (( $(awk "BEGIN {print ($delta_t > 0.05) ? 1 : 0}") )); then
      rx_bytes_diff=$((rx_now2 - rx_now))
      tx_bytes_diff=$((tx_now2 - tx_now))
      [ "$rx_bytes_diff" -lt 0 ] && rx_bytes_diff=0
      [ "$tx_bytes_diff" -lt 0 ] && tx_bytes_diff=0
      
      rx_kb=$(awk "BEGIN {printf \"%.0f\", ($rx_bytes_diff / $delta_t) / 1024}")
      tx_kb=$(awk "BEGIN {printf \"%.0f\", ($tx_bytes_diff / $delta_t) / 1024}")
    fi
    current_time=$current_time2
    rx_now=$rx_now2
    tx_now=$tx_now2
  fi
  
  # Save state
  echo "$current_time $rx_now $tx_now" > "$STATE_FILE"
  
  # Ensure they are valid integers
  [[ "$rx_kb" =~ ^[0-9]+$ ]] || rx_kb=0
  [[ "$tx_kb" =~ ^[0-9]+$ ]] || tx_kb=0
  
  total=$((rx_kb + tx_kb))
  if   [ "$total" -gt 5000 ]; then spd_cls="critical"
  elif [ "$total" -gt 2000 ]; then spd_cls="warning"
  elif [ "$total" -gt 500  ]; then spd_cls="medium"
  else spd_cls="good"; fi
  
  fmt_spd() {
    local k=$1
    if [ "$k" -ge 1024 ]; then
      awk "BEGIN {printf \"%.1fM\", $k/1024}"
    else
      printf "%dK" "$k"
    fi
  }
  rx_fmt=$(fmt_spd "$rx_kb")
  tx_fmt=$(fmt_spd "$tx_kb")
fi

# Worst-of class for info tile
rank_cls() {
  case "$1" in
    good) echo 0;; medium) echo 1;; warning) echo 2;; critical) echo 3;; *) echo 5;;
  esac
}
unrank_cls() {
  case "$1" in
    0) echo good;; 1) echo medium;; 2) echo warning;; 3) echo critical;; *) echo disconnected;;
  esac
}
r_sig=$(rank_cls "$sig_cls"); r_spd=$(rank_cls "$spd_cls")
final_cls=$(unrank_cls $(if [ "$r_sig" -ge "$r_spd" ]; then echo "$r_sig"; else echo "$r_spd"; fi))

# Two-row Pango markup
text=$(printf "<b>%s</b>\n<span size='small'>↓%s ↑%s</span>" \
  "${ssid^^}" "$rx_fmt" "$tx_fmt")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$final_cls" \
  '{text: $text, class: $cls}'
