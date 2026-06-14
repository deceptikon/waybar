#!/bin/bash

# RAM info — colored usage bar + RAM usage + swap usage
# Layout (2 lines):
#   Row 1: [bar  pct%]
#   Row 2: RAM: X.YG/A.BG   SWAP: X.YG/A.BG

# --- Read /proc/meminfo once, use awk to extract everything ---
read_meminfo() {
  awk '
    /^MemTotal:/     {printf "mt %d\n", $2}
    /^MemAvailable:/ {printf "ma %d\n", $2}
    /^MemFree:/      {printf "mf %d\n", $2}
    /^Buffers:/      {printf "buf %d\n", $2}
    /^Cached:/       {printf "cach %d\n", $2}
    /^SReclaimable:/ {printf "sr %d\n", $2}
    /^SwapTotal:/    {printf "st %d\n", $2}
    /^SwapFree:/     {printf "sf %d\n", $2}
  ' /proc/meminfo
}

declare -A m
while read key val; do
  m[$key]=$val
done < <(read_meminfo)

mt=${m[mt]}; ma=${m[ma]}
st=${m[st]:-0}; sf=${m[sf]:-0}

mem_used=$((mt - ma))
mem_pct=$((mem_used * 100 / mt))
swap_used=$((st - sf))
swap_pct=0
[ "$st" -gt 0 ] && swap_pct=$((swap_used * 100 / st))

# Convert kB → GiB (1 decimal)
to_gib() { awk "BEGIN{printf \"%.1f\", $1/1024/1024}"; }
used_g=$(to_gib "$mem_used"); total_g=$(to_gib "$mt")
swap_used_g=$(to_gib "$swap_used"); swap_total_g=$(to_gib "$st")

# Visual bar — 8 segments, Pango-colored
# Filled ▓, empty ▒
filled=$((mem_pct * 8 / 100))
[ "$filled" -gt 8 ] && filled=8
[ "$filled" -lt 0 ] && filled=0
empty=$((8 - filled))
filled_str=""; empty_str=""
[ "$filled" -gt 0 ] && filled_str=$(printf '▓%.0s' $(seq 1 $filled))
[ "$empty" -gt 0  ] && empty_str=$(printf '▒%.0s' $(seq 1 $empty))

# Bar color by usage
if   [ "$mem_pct" -ge 90 ]; then bar_col="#f38ba8"
elif [ "$mem_pct" -ge 75 ]; then bar_col="#f9e2af"
elif [ "$mem_pct" -ge 50 ]; then bar_col="#89b4fa"
else bar_col="#a6e3a1"; fi

pct_col="$bar_col"

# Two-row Pango:
#   Row 1: [colored bar] bold pct%
#   Row 2: RAM: X.YG/A.BG   (small teal label)   SWAP: X.YG/A.BG (small grey label)
# Use dim labels to keep focus on the bar + pct
text=$(printf "<span fgcolor='%s'><b>%s</b></span><span fgcolor='#444'><b>%s</b></span>  <span fgcolor='%s'><b>%d%%</b></span>\n<span fgcolor='#94e2d5'><span size='xx-small'>RAM:</span></span> <span size='xx-small'>%s/%sG</span>  <span fgcolor='#7f849c'><span size='xx-small'>SWAP:</span></span> <span size='xx-small'>%s/%sG</span>" \
  "$bar_col" "$filled_str" "$empty_str" "$pct_col" "$mem_pct" \
  "$used_g" "$total_g" "$swap_used_g" "$swap_total_g")

# Overall class by worst of mem_pct / swap_pct
rank() {
  local p=$1
  if   [ "$p" -ge 95 ]; then echo 4
  elif [ "$p" -ge 90 ]; then echo 3
  elif [ "$p" -ge 75 ]; then echo 2
  elif [ "$p" -ge 50 ]; then echo 1
  else echo 0; fi
}
rank_mem=$(rank "$mem_pct"); rank_swap=$(rank "$swap_pct")
[ "$rank_swap" -gt "$rank_mem" ] && rank_mem=$rank_swap
cls="good"
case "$rank_mem" in 1)cls="medium";; 2)cls="warning";; 3)cls="critical";; 4)cls="disconnected";; esac

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$cls" \
  '{text:$text,class:$cls}'
