#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

data=$(cat "$WAYBAR_HOME/feeds/sysmon.json" 2>>"$ERRLOG" || echo '{}')
read -r rx tx fan <<< "$(jq -r '[.net.rx_speed // 0, .net.tx_speed // 0, .temp.fan1 // 0] | @tsv' <<< "$data")"

: "${rx:=0}"; : "${tx:=0}"; : "${fan:=0}"

fmt_spd() {
  local b=$1
  if [ "$b" -ge 1048576 ]; then awk "BEGIN{printf \"%.1fM\", $b/1048576}"
  elif [ "$b" -ge 1024 ]; then awk "BEGIN{printf \"%.0fK\", $b/1024}"
  else echo "${b}B"; fi
}

rx_fmt=$(fmt_spd "$rx")
tx_fmt=$(fmt_spd "$tx")
total=$((rx + tx))

if [ "$total" -gt 5242880 ]; then cls="critical"
elif [ "$total" -gt 2097152 ]; then cls="warning"
elif [ "$total" -gt 512000 ]; then cls="medium"
else cls="good"; fi

text=$(printf "↓%s ↑%s\n󰈐 %s RPM" "$rx_fmt" "$tx_fmt" "$fan")
emit_json "$text" "$cls"
