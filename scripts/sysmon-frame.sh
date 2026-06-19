#!/usr/bin/env bash
set -euo pipefail
# sysmon-frame.sh — Universal Waybar module: draws a colored box with icon + data rows
# Usage: sysmon-frame.sh <gpu|cpu|ram|ssd|temp|asus>
# Reads from sysmon-collect pipeline, outputs Waybar JSON with class for CSS styling

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/draw-module.sh"

metric="${1:-gpu}"

data=$("$DIR/sysmon-collect.sh" | "$DIR/sysmon-mapper.sh")

case "$metric" in
  gpu)
    ICON="󰢮"; ACCENT="#fab387"
    pct=$(jq -r '.gpu.busy_pct // 0' <<< "$data")
    temp=$(jq -r '.gpu.temp_c // 0' <<< "$data")
    freq=$(jq -r '.gpu.freq // 0' <<< "$data")
    pw=$(jq -r '.gpu.power_w // 0' <<< "$data")
    mu=$(jq -r '.gpu.mem_used // 0' <<< "$data")
    mt=$(jq -r '.gpu.mem_total // 0' <<< "$data")
    cls="good"; [ "$pct" -ge 40 ] && cls="medium"; [ "$pct" -ge 70 ] && cls="warning"; [ "$pct" -ge 90 ] && cls="critical"
    seg=4; fil=$((pct*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
    bar=""; for ((i=0; i<fil; i++)); do bar+="▐"; done; for ((i=0; i<emp; i++)); do bar+="░"; done
    ms="--"; [ "$mt" -gt 0 ] && ms=$(awk "BEGIN{printf \"%.0fM\", $mu/1048576}")"/"$(awk "BEGIN{printf \"%.0fM\", $mt/1048576}")
    pw_fmt=$(printf "%.1f" "$pw")
    draw_module "$ICON" "GPU${bar} ${pct}% ${freq}MHz" "MEM ${ms} ${temp}°C ${pw_fmt}W" "$ACCENT" "$cls"
    ;;

  cpu)
    ICON="󰍛"; ACCENT="#a6e3a1"
    avg=$(jq -r '.cpu.avg // 0' <<< "$data")
    cls="good"; [ "$avg" -ge 40 ] && cls="medium"; [ "$avg" -ge 70 ] && cls="warning"; [ "$avg" -ge 90 ] && cls="critical"
    bar=""
    for ((c=0; c<16; c++)); do
      p=$(jq -r ".cpu.per_core[$c] // -1" <<< "$data")
      if [ "$p" -ge 90 ]; then col="#f38ba8"
      elif [ "$p" -ge 70 ]; then col="#fab387"
      elif [ "$p" -ge 40 ]; then col="#f9e2af"
      elif [ "$p" -ge 15 ]; then col="#89b4fa"
      elif [ "$p" -ge 0 ]; then col="#383838"
      else col="#1e1e2a"; fi
      bar+="<span fgcolor=\"$col\">▓</span>"
    done
    draw_module "$ICON" "$bar" "<span fgcolor=\"#a6e3a1\"><b>AVG ${avg}%</b></span>" "$ACCENT" "$cls"
    ;;

  ram)
    ICON=""; ACCENT="#89b4fa"
    ukb=$(jq -r '.ram.used_kb // 0' <<< "$data")
    tkb=$(jq -r '.ram.total_kb // 0' <<< "$data")
    akb=$(jq -r '.ram.avail_kb // 0' <<< "$data")
    pct=$(jq -r '.ram.used_pct // 0' <<< "$data")
    swp=$(jq -r '.ram.swap_used_kb // 0' <<< "$data")
    cls="good"; [ "$pct" -ge 50 ] && cls="medium"; [ "$pct" -ge 75 ] && cls="warning"; [ "$pct" -ge 90 ] && cls="critical"
    ug=$(awk "BEGIN{printf \"%.0f\", $ukb/1048576}")
    tg=$(awk "BEGIN{printf \"%.0f\", $tkb/1048576}")
    sm=$(awk "BEGIN{printf \"%.0f\", $swp/1024}")
    seg=8; su=$((pct*seg/100)); [ "$su" -eq 0 ] && su=1; [ "$su" -gt "$seg" ] && su=$seg
    bar=""
    for ((i=0; i<seg; i++)); do [ "$i" -lt "$su" ] && bar+="●" || bar+="○"; done
    draw_module "$ICON" "<span fgcolor='#89b4fa'>${ug}G</span> <span fgcolor='#f8f8f8'>/ ${tg}G</span>" "${bar}  swp ${sm}M" "$ACCENT" "$cls"
    ;;

  ssd)
    ICON="󰋊"; ACCENT="#a6e3a1"
    up=$(df / | awk 'END{print $5}' | tr -d '%')
    drs=$(jq -r '.disk.read_sectors // 0' <<< "$data")
    dws=$(jq -r '.disk.write_sectors // 0' <<< "$data")
    cls="good"; [ "$up" -ge 70 ] && cls="medium"; [ "$up" -ge 85 ] && cls="warning"; [ "$up" -ge 95 ] && cls="critical"
    seg=4; fil=$((up*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
    fill=""; for ((i=0; i<fil; i++)); do fill+="▓"; done; for ((i=0; i<emp; i++)); do fill+="░"; done
    fmt_bytes() { local b=$1; if [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"; elif [ "$b" -ge 1048576 ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"; elif [ "$b" -ge 1024 ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"; else echo "${b}B"; fi; }
    rf=$(fmt_bytes $((drs * 512))); wf=$(fmt_bytes $((dws * 512)))
    draw_module "$ICON" "<b>${fill}</b> <b>${up}%</b>" "<span fgcolor='#94e2d5'>↑${rf}  ↓${wf}</span>" "$ACCENT" "$cls"
    ;;

  temp)
    ICON="󰔐"; ACCENT="#f38ba8"
    tc=$(jq -r '.temp.cpu_c // 0' <<< "$data")
    f1=$(jq -r '.temp.fan1 // 0' <<< "$data")
    cls="good"; [ "$(printf "%.0f" "$tc")" -ge 60 ] && cls="warning"; [ "$(printf "%.0f" "$tc")" -ge 85 ] && cls="critical"
    draw_module "$ICON" "$(printf "%.0f" "$tc")°C" "󰈐 ${f1} RPM" "$ACCENT" "$cls"
    ;;

  asus)
    ICON=""; ACCENT="#94e2d5"
    profile=$(jq -r '.asus.profile // "unknown"' <<< "$data")
    case "$profile" in
      Quiet)       r1="ECO";    r2="Quiet";       cls="good" ;;
      Balanced)    r1="BAL";    r2="Balanced";     cls="medium" ;;
      Performance) r1="PERF";   r2="Performance";  cls="warning" ;;
      *)           r1="$profile"; r2="";           cls="good" ;;
    esac
    draw_module "$ICON" "<b>${r1}</b>" "<span size='smaller'>${r2}</span>" "$ACCENT" "$cls"
    ;;

  *)
    echo "Unknown metric: $metric" >&2
    jq -nc '{text:"?", class:"good"}'
    ;;
esac
