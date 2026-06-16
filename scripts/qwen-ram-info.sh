#!/bin/bash
# RAM — inline capacity bar  usedG · · · totalG + swap

read_meminfo() {
  awk '
    /^MemTotal:/     {printf "mt %d\n", $2}
    /^MemAvailable:/ {printf "ma %d\n", $2}
    /^SwapTotal:/    {printf "st %d\n", $2}
    /^SwapFree:/     {printf "sf %d\n", $2}
  ' /proc/meminfo
}

declare -A m
while read key val; do m[$key]=$val; done < <(read_meminfo)

mt=${m[mt]}; ma=${m[ma]}
st=${m[st]:-0}; sf=${m[sf]:-0}

used=$((mt - ma)); pct=$((used * 100 / mt))
swap=$((st - sf))

total_gb=$((mt / 1048576))
ug=$((used / 1048576))

seg_total=12; seg_used=$((pct * seg_total / 100))

bar=""
if [ "$pct" -eq 100 ]; then
  # At 100%%: all filled, label after the last ▓
  for ((i=0; i<seg_total; i++)); do
    bar+=$(printf "<span fgcolor='#89b4fa'>▓</span>")
  done
else
  # Partial: print used ▓, then inject label at boundary, then empty · + total
  for ((i=0; i<seg_total; i++)); do
    #if [ "$i" -eq "$seg_used" ]; then
     # bar+=$(printf "<span fgcolor='#89b4fa'><span size='smaller' rise='-4000'>%dG</span></span>" "$ug")
    #fi
    if [ "$i" -lt "$seg_used" ]; then
      bar+=$(printf "<span fgcolor='#89b4fa'>▓</span>")
    else
      bar+=$(printf "<span fgcolor='#f8f8f8'>▓</span>")
    fi
  done
fi
bax=$(printf "<span fgcolor='#89b4fa'>%dG</span>" "$ug")
line1="$bar  "
line2="$bax"
line2+=$(printf "<span fgcolor='#6c7086' size='smaller'>swap: %sG</span>" "$(awk "BEGIN{printf \"%.1f\", $swap/1024/1024}")")

text=$(printf "%s\n%s" "$line1" "$line2")

cls="good"
[ "$pct" -ge 50 ] && cls="medium"
[ "$pct" -ge 75 ] && cls="warning"
[ "$pct" -ge 90 ] && cls="critical"

jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
