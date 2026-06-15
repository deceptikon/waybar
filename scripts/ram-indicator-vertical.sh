#!/bin/bash
# RAM — inline capacity bar + swap (production module)
set -euo pipefail

read -r mem_total_kb mem_available_kb < <(awk '/MemTotal|MemAvailable/{print $2}' /proc/meminfo)
# meminfo order: MemAvailable is on next line after MemTotal
avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)

used=$((mem_total_kb - avail))
pct=$((used * 100 / mem_total_kb))
swap_used_kb=$(awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{if(t&&f)print t-f; else print 0}' /proc/meminfo)

to_gib() { awk "BEGIN{printf \"%.1f\", $1/1024/1024}"; }
ug=$(to_gib "$used"); sw=$(to_gib "$swap_used_kb")
total_gb=$((mem_total_kb / 1048576))

seg_total=8; seg_used=$((pct * seg_total / 100))
bar=""
for ((i=0; i<seg_total; i++)); do
  if [ "$i" -eq "$seg_used" ]; then
    bar+=$(printf "<span fgcolor='#89b4fa'><b>%sG</b></span>" "$ug")
  fi
  if [ "$i" -lt "$seg_used" ]; then
    bar+=$(printf "<span fgcolor='#89b4fa'>▓</span>")
  else
    bar+=$(printf "<span fgcolor='#383838'>·</span>")
  fi
done
[ "$pct" -ge 100 ] && bar+=$(printf "<span fgcolor='#89b4fa'><b>%sG</b></span>" "$ug")
bar+=$(printf "<span fgcolor='#383838' size='xx-small'>%dG</span>" "$total_gb")

line1="$bar"
line2=$(printf "<span fgcolor='#585b70' size='xx-small'>swap: %sG</span>" "$sw")

text=$(printf "%s\n%s" "$line1" "$line2")

cls="good"
[ "$pct" -ge 50 ] && cls="medium"
[ "$pct" -ge 75 ] && cls="warning"
[ "$pct" -ge 90 ] && cls="critical"

jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
