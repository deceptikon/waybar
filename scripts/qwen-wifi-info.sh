#!/bin/bash

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

# Speed sampling — 0.5s delta
rx_fmt="-"; tx_fmt="-"; spd_cls="$sig_cls"
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
  total=$((rx_kb + tx_kb))
  if   [ "$total" -gt 5000 ]; then spd_cls="critical"
  elif [ "$total" -gt 2000 ]; then spd_cls="warning"
  elif [ "$total" -gt 500  ]; then spd_cls="medium"
  else spd_cls="good"; fi

  fmt_spd() {
    local k=$1
    if [ "$k" -ge 1024 ]; then awk "BEGIN{printf\"%.0fM\",$k/1024}"
    else printf "%dK" "$k"; fi
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
text=$(printf "<b>%s</b>\n<span size='small' style='italic'>↓%s  ↑%s</span>" \
  "${ssid^^}" "$rx_fmt" "$tx_fmt")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$final_cls" \
  '{text: $text, class: $cls}'
