#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"
export LC_ALL=C

wifi_info=$(nmcli -t -f active,ssid,signal,device dev wifi 2>>"$ERRLOG" \
  | grep '^yes' | head -1 || true)

if [ -z "$wifi_info" ]; then
  emit_json "" "disconnected"
  exit 0
fi

ssid=$(printf '%s' "$wifi_info" | cut -d: -f2)
signal=$(printf '%s' "$wifi_info" | cut -d: -f3)
iface=$(printf '%s' "$wifi_info" | cut -d: -f4)

[ ${#ssid} -gt 16 ] && ssid="${ssid:0:13}…"
signal=${signal:-0}

if   [ "$signal" -ge 80 ]; then sig_cls="good"
elif [ "$signal" -ge 60 ]; then sig_cls="medium"
elif [ "$signal" -ge 40 ]; then sig_cls="warning"
elif [ "$signal" -ge 20 ]; then sig_cls="critical"
else sig_cls="disconnected"; fi

rx_fmt="0B"; tx_fmt="0B"; spd_cls="$sig_cls"
if [ -n "$iface" ] && [ "$iface" != "lo" ]; then
  rx_speed=0
  tx_speed=0
  sysmon="$WAYBAR_HOME/feeds/sysmon.json"
  if [ -f "$sysmon" ]; then
    read -r rx_speed tx_speed <<< "$(jq -r '[.net.rx_speed // 0, .net.tx_speed // 0] | @tsv' "$sysmon" 2>>"$ERRLOG")"
  fi
  read -r rx_speed tx_speed <<< "$rx_speed $tx_speed"

  total=$((rx_speed + tx_speed))
  if   [ "$total" -gt 5242880 ]; then spd_cls="critical"
  elif [ "$total" -gt 2097152 ]; then spd_cls="warning"
  elif [ "$total" -gt 512000  ]; then spd_cls="medium"
  else spd_cls="good"; fi

  fmt_spd() {
    local b=$1
    if [ "$b" -ge 1048576 ]; then
      awk "BEGIN {printf \"%.1fM\", $b/1048576}"
    elif [ "$b" -ge 1024 ]; then
      awk "BEGIN {printf \"%.0fK\", $b/1024}"
    else
      echo "${b}B"
    fi
  }
  rx_fmt=$(fmt_spd "$rx_speed")
  tx_fmt=$(fmt_spd "$tx_speed")
fi

rank_cls() {
  case "$1" in
    good) echo 0;;
    medium) echo 1;;
    warning) echo 2;;
    critical) echo 3;;
    *) echo 5;;
  esac
}
unrank_cls() {
  case "$1" in
    0) echo good;;
    1) echo medium;;
    2) echo warning;;
    3) echo critical;;
    *) echo disconnected;;
  esac
}
r_sig=$(rank_cls "$sig_cls"); r_spd=$(rank_cls "$spd_cls")
final_cls=$(unrank_cls "$(if [ "$r_sig" -ge "$r_spd" ]; then echo "$r_sig"; else echo "$r_spd"; fi)")

text=$(printf "<b>%s</b>\n<span size='small'>↓%s ↑%s</span>" \
  "${ssid^^}" "$rx_fmt" "$tx_fmt")

emit_json "$text" "$final_cls"
