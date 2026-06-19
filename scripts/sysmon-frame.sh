#!/usr/bin/env bash
set -euo pipefail
# sysmon-frame.sh — Universal Waybar module
#   <gpu|cpu|ram|ssd|temp|asus>  — single-metric box with icon
#   all                          — all metrics, one condensed output

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lib/draw-module.sh"

metric="${1:-gpu}"
data=$("$DIR/sysmon-collect.sh" | "$DIR/sysmon-mapper.sh")

# ── Helpers ──
fmt_gb() { awk "BEGIN{printf \"%.0f\", $1/1048576}"; }
fmt_mb() { awk "BEGIN{printf \"%.0f\", $1/1048576}"; }
fmt_io() { local b=$1; if [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"; elif [ "$b" -ge 1048576 ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"; elif [ "$b" -ge 1024 ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"; else echo "${b}B"; fi; }
worst_cls() { local a="$1" b="$2"; for c in "critical" "warning" "medium" "good"; do [ "$a" = "$c" ] && { echo "$c"; return; }; [ "$b" = "$c" ] && { echo "$c"; return; }; done; echo "good"; }

# ── Single-metric dispatch ──
single_metric() {
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
      ms="--"; [ "$mt" -gt 0 ] && ms="$(fmt_mb "$mu")/$(fmt_mb "$mt")"
      pw_fmt=$(printf "%.1f" "$pw")
      draw_module "$ICON" "GPU${bar} ${pct}% ${freq}MHz" "MEM ${ms} ${temp}°C ${pw_fmt}W" "$ACCENT" "$cls"
      ;;
    cpu)
      ICON="󰍛"; ACCENT="#a6e3a1"
      avg=$(jq -r '.cpu.avg // 0' <<< "$data")
      cls="good"; [ "$avg" -ge 40 ] && cls="medium"; [ "$avg" -ge 70 ] && cls="warning"; [ "$avg" -ge 90 ] && cls="critical"
      bar=""; for ((c=0; c<16; c++)); do
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
      ukb=$(jq -r '.ram.used_kb // 0' <<< "$data"); tkb=$(jq -r '.ram.total_kb // 0' <<< "$data")
      pct=$(jq -r '.ram.used_pct // 0' <<< "$data"); swp=$(jq -r '.ram.swap_used_kb // 0' <<< "$data")
      cls="good"; [ "$pct" -ge 50 ] && cls="medium"; [ "$pct" -ge 75 ] && cls="warning"; [ "$pct" -ge 90 ] && cls="critical"
      ug=$(fmt_gb "$ukb"); tg=$(fmt_gb "$tkb"); sm=$(awk "BEGIN{printf \"%.0f\", $swp/1024}")
      seg=8; su=$((pct*seg/100)); [ "$su" -eq 0 ] && su=1; [ "$su" -gt "$seg" ] && su=$seg
      bar=""; for ((i=0; i<seg; i++)); do [ "$i" -lt "$su" ] && bar+="●" || bar+="○"; done
      draw_module "$ICON" "<span fgcolor='#89b4fa'>${ug}G</span> <span fgcolor='#f8f8f8'>/ ${tg}G</span>" "${bar}  swp ${sm}M" "$ACCENT" "$cls"
      ;;
    ssd)
      ICON="󰋊"; ACCENT="#a6e3a1"
      up=$(df / | awk 'END{print $5}' | tr -d '%')
      drs=$(jq -r '.disk.read_sectors // 0' <<< "$data"); dws=$(jq -r '.disk.write_sectors // 0' <<< "$data")
      cls="good"; [ "$up" -ge 70 ] && cls="medium"; [ "$up" -ge 85 ] && cls="warning"; [ "$up" -ge 95 ] && cls="critical"
      seg=4; fil=$((up*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
      fill=""; for ((i=0; i<fil; i++)); do fill+="▓"; done; for ((i=0; i<emp; i++)); do fill+="░"; done
      rf=$(fmt_io $((drs * 512))); wf=$(fmt_io $((dws * 512)))
      draw_module "$ICON" "<b>${fill}</b> <b>${up}%</b>" "<span fgcolor='#94e2d5'>↑${rf}  ↓${wf}</span>" "$ACCENT" "$cls"
      ;;
    temp)
      ICON="󰔐"; ACCENT="#f38ba8"
      tc=$(jq -r '.temp.cpu_c // 0' <<< "$data"); f1=$(jq -r '.temp.fan1 // 0' <<< "$data")
      cls="good"; [ "$(printf "%.0f" "$tc")" -ge 60 ] && cls="warning"; [ "$(printf "%.0f" "$tc")" -ge 85 ] && cls="critical"
      draw_module "$ICON" "$(printf "%.0f" "$tc")°C" "󰈐 ${f1} RPM" "$ACCENT" "$cls"
      ;;
    asus)
      ICON=""; ACCENT="#94e2d5"
      profile=$(jq -r '.asus.profile // "unknown"' <<< "$data")
      case "$profile" in Quiet) r1="ECO"; r2="Quiet"; cls="good" ;; Balanced) r1="BAL"; r2="Balanced"; cls="medium" ;; Performance) r1="PERF"; r2="Performance"; cls="warning" ;; *) r1="$profile"; r2=""; cls="good" ;; esac
      draw_module "$ICON" "<b>${r1}</b>" "<span size='smaller'>${r2}</span>" "$ACCENT" "$cls"
      ;;
    *) echo "Unknown metric: $metric" >&2; jq -nc '{text:"?", class:"good"}' ;;
  esac
}

# ── All-metrics unified output ──
all_metrics() {
  # Extract all data
  local gpu_pct=$(jq -r '.gpu.busy_pct // 0' <<< "$data")
  local gpu_temp=$(jq -r '.gpu.temp_c // 0' <<< "$data")
  local gpu_freq=$(jq -r '.gpu.freq // 0' <<< "$data")
  local gpu_pw=$(jq -r '.gpu.power_w // 0' <<< "$data")
  local gpu_mu=$(jq -r '.gpu.mem_used // 0' <<< "$data")
  local gpu_mt=$(jq -r '.gpu.mem_total // 0' <<< "$data")

  local cpu_avg=$(jq -r '.cpu.avg // 0' <<< "$data")

  local ram_ukb=$(jq -r '.ram.used_kb // 0' <<< "$data")
  local ram_tkb=$(jq -r '.ram.total_kb // 0' <<< "$data")
  local ram_pct=$(jq -r '.ram.used_pct // 0' <<< "$data")
  local ram_swp=$(jq -r '.ram.swap_used_kb // 0' <<< "$data")

  local ssd_up=$(df / | awk 'END{print $5}' | tr -d '%')
  local ssd_drs=$(jq -r '.disk.read_sectors // 0' <<< "$data")
  local ssd_dws=$(jq -r '.disk.write_sectors // 0' <<< "$data")

  local temp_tc=$(jq -r '.temp.cpu_c // 0' <<< "$data")
  local temp_f1=$(jq -r '.temp.fan1 // 0' <<< "$data")

  local asus_profile=$(jq -r '.asus.profile // "unknown"' <<< "$data")

  # Classes per metric
  local gpu_cls="good"; [ "$gpu_pct" -ge 70 ] && gpu_cls="warning"; [ "$gpu_pct" -ge 90 ] && gpu_cls="critical"
  local cpu_cls="good"; [ "$cpu_avg" -ge 40 ] && cpu_cls="medium"; [ "$cpu_avg" -ge 70 ] && cpu_cls="warning"; [ "$cpu_avg" -ge 90 ] && cpu_cls="critical"
  local ram_cls="good"; [ "$ram_pct" -ge 50 ] && ram_cls="medium"; [ "$ram_pct" -ge 75 ] && ram_cls="warning"; [ "$ram_pct" -ge 90 ] && ram_cls="critical"
  local ssd_cls="good"; [ "$ssd_up" -ge 70 ] && ssd_cls="medium"; [ "$ssd_up" -ge 85 ] && ssd_cls="warning"; [ "$ssd_up" -ge 95 ] && ssd_cls="critical"
  local temp_cls="good"; [ "$(printf "%.0f" "$temp_tc")" -ge 60 ] && temp_cls="warning"; [ "$(printf "%.0f" "$temp_tc")" -ge 85 ] && temp_cls="critical"
  local asus_cls="good"; case "$asus_profile" in Balanced) asus_cls="medium" ;; Performance) asus_cls="warning" ;; esac

  local overall_cls="$gpu_cls"
  for c in "$cpu_cls" "$ram_cls" "$ssd_cls" "$temp_cls" "$asus_cls"; do
    overall_cls=$(worst_cls "$overall_cls" "$c")
  done

  # Format each metric as one colored line
  # GPU
  local gpu_ms="--"; [ "$gpu_mt" -gt 0 ] && gpu_ms="$(fmt_mb "$gpu_mu")/$(fmt_mb "$gpu_mt")"
  local gpu=$(printf "<span fgcolor='#fab387'>GPU %s%% %sMHz %s %s°C %.1fW</span>" \
    "$gpu_pct" "$gpu_freq" "$gpu_ms" "$gpu_temp" "$gpu_pw")

  # CPU — 16 blocks + avg
  local cpu_bar=""
  for ((c=0; c<16; c++)); do
    p=$(jq -r ".cpu.per_core[$c] // -1" <<< "$data")
    if [ "$p" -ge 90 ]; then col="#f38ba8"
    elif [ "$p" -ge 70 ]; then col="#fab387"
    elif [ "$p" -ge 40 ]; then col="#f9e2af"
    elif [ "$p" -ge 15 ]; then col="#89b4fa"
    elif [ "$p" -ge 0 ]; then col="#383838"
    else col="#1e1e2a"; fi
    cpu_bar+="<span fgcolor=\"$col\">▓</span>"
  done
  local cpu=$(printf "<span fgcolor='#a6e3a1'>CPU %s %s%%</span>" "$cpu_bar" "$cpu_avg")

  # RAM
  local ram_ug=$(fmt_gb "$ram_ukb"); local ram_tg=$(fmt_gb "$ram_tkb"); local ram_sm=$(awk "BEGIN{printf \"%.0f\", $ram_swp/1024}")
  local ram_seg=8; local ram_su=$((ram_pct*ram_seg/100)); [ "$ram_su" -eq 0 ] && ram_su=1; [ "$ram_su" -gt "$ram_seg" ] && ram_su=$ram_seg
  local ram_bar=""
  for ((i=0; i<ram_seg; i++)); do [ "$i" -lt "$ram_su" ] && ram_bar+="●" || ram_bar+="○"; done
  local ram=$(printf "<span fgcolor='#89b4fa'>RAM %s/%sG %s%% %s SWP %sM</span>" \
    "$ram_ug" "$ram_tg" "$ram_pct" "$ram_bar" "$ram_sm")

  # SSD
  local ssd_seg=4; local ssd_fil=$((ssd_up*ssd_seg/100)); [ "$ssd_fil" -gt "$ssd_seg" ] && ssd_fil=$ssd_seg; [ "$ssd_fil" -lt 0 ] && ssd_fil=0; local ssd_emp=$((ssd_seg-ssd_fil))
  local ssd_fill=""; for ((i=0; i<ssd_fil; i++)); do ssd_fill+="▓"; done; for ((i=0; i<ssd_emp; i++)); do ssd_fill+="░"; done
  local ssd_rf=$(fmt_io $((ssd_drs * 512))); local ssd_wf=$(fmt_io $((ssd_dws * 512)))
  local ssd=$(printf "<span fgcolor='#a6e3a1'>SSD %s %s%% %s %s</span>" \
    "$ssd_fill" "$ssd_up" "$ssd_rf" "$ssd_wf")

  # Temp
  local temp_tc_int=$(printf "%.0f" "$temp_tc")
  local temp=$(printf "<span fgcolor='#f38ba8'>TEMP %s°C FAN %s RPM</span>" "$temp_tc_int" "$temp_f1")

  # ASUS
  local asus_r1=""; local asus_r2=""
  case "$asus_profile" in Quiet) asus_r1="ECO"; asus_r2="Quiet" ;; Balanced) asus_r1="BAL"; asus_r2="Balanced" ;; Performance) asus_r1="PERF"; asus_r2="Performance" ;; *) asus_r1="$asus_profile" ;; esac
  local asus=$(printf "<span fgcolor='#94e2d5'>ASUS %s %s</span>" "$asus_r1" "$asus_r2")

  local text=$(printf "%s\n%s\n%s\n%s\n%s\n%s" "$gpu" "$cpu" "$ram" "$ssd" "$temp" "$asus")
  jq -nc --arg text "$text" --arg cls "$overall_cls" '{text: $text, class: $cls}'
}

# ── Entry ──
if [ "$metric" = "all" ]; then
  all_metrics
else
  single_metric
fi
