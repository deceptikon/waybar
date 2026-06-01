#!/bin/bash
set -euo pipefail

# --- WiFi info ---
wifi_info=$(nmcli -t -f active,ssid,signal,device dev wifi | grep '^yes' | head -1)

if [ -z "$wifi_info" ]; then
  ssid="Disconnected"
  signal=0
  icon="󰤮"
  net_class="disconnected"
  iface=""
else
  ssid=$(echo "$wifi_info" | cut -d: -f2)
  if [ ${#ssid} -gt 16 ]; then
    ssid="${ssid:0:13}…"
  fi
  signal=$(echo "$wifi_info" | cut -d: -f3)
  iface=$(echo "$wifi_info" | cut -d: -f4)

  if [ "$signal" -ge 80 ]; then
    icon="󰤨"
    net_class="good"
  elif [ "$signal" -ge 60 ]; then
    icon="󰤥"
    net_class="medium"
  elif [ "$signal" -ge 40 ]; then
    icon="󰤢"
    net_class="warning"
  elif [ "$signal" -ge 20 ]; then
    icon="󰤟"
    net_class="critical"
  else
    icon="󰤮"
    net_class="disconnected"
  fi
fi

# --- Net speed ---
if [ -z "$iface" ] || [ "$iface" = "lo" ]; then
  rx_fmt="-"
  tx_fmt="-"
  speed_class="critical"
else
  rx_bytes=$(cat /sys/class/net/"$iface"/statistics/rx_bytes)
  tx_bytes=$(cat /sys/class/net/"$iface"/statistics/tx_bytes)

  sleep 0.5

  rx_bytes_new=$(cat /sys/class/net/"$iface"/statistics/rx_bytes)
  tx_bytes_new=$(cat /sys/class/net/"$iface"/statistics/tx_bytes)

  rx_kb=$(( (rx_bytes_new - rx_bytes) / 1024 / 2 ))
  tx_kb=$(( (tx_bytes_new - tx_bytes) / 1024 / 2 ))

  [ "$rx_kb" -lt 0 ] && rx_kb=0
  [ "$tx_kb" -lt 0 ] && tx_kb=0

  total_kb=$((rx_kb + tx_kb))
  if [ "$total_kb" -gt 5000 ]; then
    speed_class="critical"
  elif [ "$total_kb" -gt 2000 ]; then
    speed_class="warning"
  elif [ "$total_kb" -gt 500 ]; then
    speed_class="medium"
  else
    speed_class="good"
  fi

  format_speed() {
    local kb=$1
    if [ "$kb" -ge 1024 ]; then
      printf "%.1fM" "$(echo "scale=1; $kb/1024" | bc)"
    else
      printf "%dK" "$kb"
    fi
  }

  rx_fmt=$(format_speed "$rx_kb")
  tx_fmt=$(format_speed "$tx_kb")
fi

# Take the worst class
class_rank() {
  case "$1" in
    disconnected) echo 5;;
    critical) echo 4;;
    warning) echo 3;;
    medium) echo 2;;
    *) echo 1;;
  esac
}
rank_net=$(class_rank "$net_class")
rank_speed=$(class_rank "$speed_class")
if [ "$rank_net" -ge "$rank_speed" ]; then
  combined_class="$net_class"
else
  combined_class="$speed_class"
fi

tooltip="WiFi: ${ssid^^} (${signal}%) | Network ($iface): ↓$rx_fmt/s ↑$tx_fmt/s"

# Build two-row text
# Row 1: large icon + SSID
# Row 2: small text with signal + speed
row1="<span size=\"24000\">${icon}</span> ${ssid}"
row2="<small>${icon}  ${signal}% | ↓$rx_fmt/s ↑$tx_fmt/s</small>"

jq -n --compact-output \
  --arg text "$row1
$row2" \
  --arg class "$combined_class" \
  --arg tooltip "$tooltip" \
  '{text: $text, class: $class, tooltip: $tooltip}'
