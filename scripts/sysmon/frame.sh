#!/usr/bin/env bash
set -euo pipefail
# sysmon-frame.sh — Format one metric from cached JSON; output Waybar JSON.
#   <gpu|cpu|ram|ssd|temp|asus>
#   Reads /tmp/sysmon.json (written by sysmon-poller.sh).

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../lib/draw-module.sh"

metric="${1:-gpu}"
CACHE="/tmp/sysmon.json"

if [ ! -f "$CACHE" ] || [ ! -s "$CACHE" ]; then
  jq -nc '{text:"⏳", class:"good"}'
  exit 0
fi

data=$(<"$CACHE")

# ── Helpers ──
fmt_gb() { awk "BEGIN{printf \"%.0f\", $1/1048576}"; }
fmt_mb() { awk "BEGIN{printf \"%.0f\", $1/1048576}"; }
fmt_io() { local b=$1; if [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"; elif [ "$b" -ge 1048576 ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"; elif [ "$b" -ge 1024 ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"; else echo "${b}B"; fi; }

case "$metric" in
  gpu)
    ACCENT="#fab387"
    pct=$(jq -r '.gpu.busy_pct // 0' <<< "$data")
    temp=$(jq -r '.gpu.temp_c // 0' <<< "$data")
    freq=$(jq -r '.gpu.freq // 0' <<< "$data")
    cls="good"; [ "$pct" -ge 40 ] && cls="medium"; [ "$pct" -ge 70 ] && cls="warning"; [ "$pct" -ge 90 ] && cls="critical"
    seg=8; fil=$((pct*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
    bar=""; for ((i=0; i<fil; i++)); do bar+="▐"; done; for ((i=0; i<emp; i++)); do bar+="░"; done
    draw_module "" "<b>${bar} ${pct}%</b>" "<span size='small' style='italic'>${freq}MHz ${temp}°C</span>" "$ACCENT" "$cls"
    ;;
  cpu)
    ACCENT="#a6e3a1"
    avg=$(jq -r '.cpu.avg // 0' <<< "$data")
    tc=$(jq -r '.temp.cpu_c // 0' <<< "$data")
    cls="good"; [ "$avg" -ge 40 ] && cls="medium"; [ "$avg" -ge 70 ] && cls="warning"; [ "$avg" -ge 90 ] && cls="critical"
    bar1=""; bar2=""; for ((c=0; c<16; c++)); do
      p=$(jq -r ".cpu.per_core[$c] // -1" <<< "$data")
      if [ "$p" -ge 90 ]; then col="#f38ba8"
      elif [ "$p" -ge 70 ]; then col="#fab387"
      elif [ "$p" -ge 40 ]; then col="#f9e2af"
      elif [ "$p" -ge 15 ]; then col="#89b4fa"
      elif [ "$p" -ge 0 ]; then col="#383838"
      else col="#1e1e2a"; fi
      if [ "$c" -lt 8 ]; then
        [ -n "$bar1" ] && bar1+=$'\u2009'
        bar1+="<span fgcolor=\"$col\">▓</span>"
      else
        [ -n "$bar2" ] && bar2+=$'\u2009'
        bar2+="<span fgcolor=\"$col\">▓</span>"
      fi
    done
    tc_fmt=$(printf "%.0f" "$tc")
    draw_module "" "${bar1}"$'\n'"${bar2}" "<span size='small' style='italic'><span fgcolor=\"#a6e3a1\">AVG ${avg}%</span> 󰔐 ${tc_fmt}°C</span>" "$ACCENT" "$cls"
    ;;
  ram)
    ACCENT="#89b4fa"
    ukb=$(jq -r '.ram.used_kb // 0' <<< "$data"); tkb=$(jq -r '.ram.total_kb // 0' <<< "$data")
    pct=$(jq -r '.ram.used_pct // 0' <<< "$data"); swp=$(jq -r '.ram.swap_used_kb // 0' <<< "$data")
    cls="good"; [ "$pct" -ge 50 ] && cls="medium"; [ "$pct" -ge 75 ] && cls="warning"; [ "$pct" -ge 90 ] && cls="critical"
    ug=$(fmt_gb "$ukb"); tg=$(fmt_gb "$tkb"); sm=$(awk "BEGIN{printf \"%.0f\", $swp/1024}")
    seg=10; su=$((pct*seg/100)); [ "$su" -eq 0 ] && su=1; [ "$su" -gt "$seg" ] && su=$seg
    bar=""; for ((i=0; i<seg; i++)); do [ "$i" -lt "$su" ] && bar+="●" || bar+="○"; done
    draw_module "" "<b><span fgcolor='#89b4fa'>${ug}G</span> <span fgcolor='#f8f8f8'>/ ${tg}G</span></b>" "${bar}" "$ACCENT" "$cls" "<span size='small' style='italic'>swp ${sm}M</span>"
    ;;
  ssd)
    ACCENT="#a6e3a1"
    up=$(df / | awk 'END{print $5}' | tr -d '%')
    drs=$(jq -r '.disk.read_sectors // 0' <<< "$data"); dws=$(jq -r '.disk.write_sectors // 0' <<< "$data")
    cls="good"; [ "$up" -ge 70 ] && cls="medium"; [ "$up" -ge 85 ] && cls="warning"; [ "$up" -ge 95 ] && cls="critical"
    seg=9; fil=$((up*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
    fill=""; for ((i=0; i<fil; i++)); do fill+="▓"; done; for ((i=0; i<emp; i++)); do fill+="░"; done
    rf=$(fmt_io $((drs * 512))); wf=$(fmt_io $((dws * 512)))
    draw_module "" "<b>${fill} ${up}%</b>" "<span size='small' style='italic'><span fgcolor='#94e2d5'>↑${rf} ↓${wf}</span></span>" "$ACCENT" "$cls"
    ;;
  temp)
    ACCENT="#f38ba8"
    tc=$(jq -r '.temp.cpu_c // 0' <<< "$data"); f1=$(jq -r '.temp.fan1 // 0' <<< "$data")
    cls="good"; [ "$(printf "%.0f" "$tc")" -ge 60 ] && cls="warning"; [ "$(printf "%.0f" "$tc")" -ge 85 ] && cls="critical"
    draw_module "" "$(printf "%.0f" "$tc")°C" "󰈐 ${f1} RPM" "$ACCENT" "$cls"
    ;;
  asus)
    ACCENT="#94e2d5"
    profile=$(jq -r '.asus.profile // "unknown"' <<< "$data")
    f1=$(jq -r '.temp.fan1 // 0' <<< "$data")
    case "$profile" in
      Quiet)        r=" Quiet"; cls="good" ;;
      Balanced)     r=" Balanced"; cls="medium" ;;
      Performance)  r=" Performance"; cls="warning" ;;
      *)            r="$profile"; cls="good" ;;
    esac
    draw_module "" "<b>${r}</b>" "<span size='small' style='italic'>󰈐 ${f1} RPM</span>" "$ACCENT" "$cls"
    ;;
  *)
    echo "Unknown metric: $metric" >&2
    jq -nc '{text:"?", class:"good"}'
    ;;
esac
