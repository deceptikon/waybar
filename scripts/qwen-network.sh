#!/bin/bash

# Unified wifi+ssid+speeds module
# Outputs a single inline string: wifi-icon  SSID  ↓rx ↑tx

get_wifi_info() {
  nmcli -t -f active,ssid,signal,device dev wifi 2>/dev/null \
    | grep '^yes' | head -1
}

format_speed() {
  local kb="$1"
  if [ "$kb" -ge 1024 ]; then
    awk "BEGIN {printf \"%.0fM\", $kb/1024}"
  else
    printf "%dK" "$kb"
  fi
}

# Returns numeric rank: higher is worse
rank_class() {
  case "$1" in
    good)        echo 0 ;;
    medium)      echo 1 ;;
    warning)     echo 2 ;;
    critical)    echo 3 ;;
    disconnected) echo 5 ;;
    *)           echo 0 ;;
  esac
}

name_from_rank() {
  case "$1" in
    0) echo "good" ;;
    1) echo "medium" ;;
    2) echo "warning" ;;
    3) echo "critical" ;;
    *) echo "disconnected" ;;
  esac
}

# --- Main logic ---

wifi_info=$(get_wifi_info || true)

if [ -z "$wifi_info" ]; then
  jq -n --compact-output \
    --arg text " OFF" \
    '{text: $text, class: "disconnected", tooltip: "WiFi disconnected"}'
  exit 0
fi

ssid=$(printf  '%s' "$wifi_info" | cut -d: -f2)
signal_raw=$(printf '%s' "$wifi_info" | cut -d: -f3)
iface=$(printf '%s' "$wifi_info" | cut -d: -f4)

# Truncate long SSID
[ ${#ssid} -gt 18 ] && ssid="${ssid:0:15}…"

# Wifi icon by signal strength
if   [ "$signal_raw" -ge 80 ] 2>/dev/null; then icon="󰤨"
elif [ "$signal_raw" -ge 60 ] 2>/dev/null; then icon="󰤥"
elif [ "$signal_raw" -ge 40 ] 2>/dev/null; then icon=""
elif [ "$signal_raw" -ge 20 ] 2>/dev/null; then icon=""
else icon="󰤮"; fi

# Speed class from signal
if [ "$signal_raw" -ge 80 ] 2>/dev/null; then sig_class="good"
elif [ "$signal_raw" -ge 60 ] 2>/dev/null; then sig_class="medium"
elif [ "$signal_raw" -ge 40 ] 2>/dev/null; then sig_class="warning"
elif [ "$signal_raw" -ge 20 ] 2>/dev/null; then sig_class="critical"
else sig_class="disconnected"; fi

# Network speed — 0.5s delta sampling
rx_fmt="0K"; tx_fmt="0K"; spd_class="good"
if [ -n "$iface" ] && [ "$iface" != "lo" ]; then
  rx1=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx1=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
  sleep 0.5
  rx2=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
  tx2=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
  rx_kb=$(( (rx2 - rx1) / 1024 / 2 ))
  tx_kb=$(( (tx2 - tx1) / 1024 / 2 ))
  [ "$rx_kb" -lt 0 ] && rx_kb=0
  [ "$tx_kb" -lt 0 ] && tx_kb=0
  rx_fmt=$(format_speed "$rx_kb")
  tx_fmt=$(format_speed "$tx_kb")
  spd_class=$(name_from_rank "$(rank_class "$(
    if   [ $((rx_kb + tx_kb)) -gt 5000 ]; then echo "critical"
    elif [ $((rx_kb + tx_kb)) -gt 2000 ]; then echo "warning"
    elif [ $((rx_kb + tx_kb)) -gt 500  ]; then echo "medium"
    else echo "good"; fi
  )")")
fi

# Combined class = worst (highest rank) of signal + speed
rank_sig=$(rank_class "$sig_class")
rank_spd=$(rank_class "$spd_class")
final_class=$(name_from_rank $(if [ "$rank_sig" -ge "$rank_spd" ]; then echo "$rank_sig"; else echo "$rank_spd"; fi))

# Build text
text="$icon ${ssid^^} ↓$rx_fmt ↑$tx_fmt"
tooltip="WiFi: ${ssid} (${signal_raw}%) on $iface\n↓$rx_fmt/s  ↑$tx_fmt/s"

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$final_class" \
  --arg tip "$tooltip" \
  '{text: $text, class: $cls, tooltip: $tip}'
