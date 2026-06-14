#!/bin/bash
# RAM info — bar used/totalG + swap:usedG

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

to_gib() { awk "BEGIN{printf \"%.1f\", $1/1024/1024}"; }
ug=$(to_gib "$used"); tg=$(to_gib "$mt"); sw=$(to_gib "$swap")

# 4-segment bar
filled=$((pct * 4 / 100)); [ "$filled" -gt 4 ] && filled=4
empty=$((4 - filled))
fs=""; es=""
[ "$filled" -gt 0 ] && fs=$(printf '\xe2\x96\x93%.0s' $(seq 1 $filled))
[ "$empty" -gt 0  ] && es=$(printf '\xe2\x96\x92%.0s' $(seq 1 $empty))

if   [ "$pct" -ge 90 ]; then bc="#f38ba8"; cls="critical"
elif [ "$pct" -ge 75 ]; then bc="#f9e2af"; cls="warning"
elif [ "$pct" -ge 50 ]; then bc="#89b4fa"; cls="medium"
else bc="#a6e3a1"; cls="good"; fi

# printf interprets \n inside its format string as a REAL newline byte
text=$(printf "<span fgcolor='%s'>%s</span><span fgcolor='#383838'>%s</span> <span fgcolor='%s'><b>%s/%sG</b></span>\n<span fgcolor='#585b70' size='xx-small'>swap:%sG</span>" \
  "$bc" "$fs" "$es" "$bc" "$ug" "$tg" "$sw")

jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
