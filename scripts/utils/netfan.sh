#!/bin/bash
data=$(cat /tmp/sysmon.json 2>/dev/null || echo '{}')
eval "$(jq -r '
  [.net.rx_speed // 0, .net.tx_speed // 0, .temp.fan1 // 0]
  | @sh "rx=\(.[0]); tx=\(.[1]); fan=\(.[2])"
' <<< "$data")"

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

text=$(printf "  ↓%s ↑%s\n󰈐 %s RPM" "$rx_fmt" "$tx_fmt" "$fan")
jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
