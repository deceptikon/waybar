#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/../lib/draw-module.sh"
FEEDS="/home/lexx/.config/waybar/feeds"

mkdir -p "$FEEDS"

data=$(cat)
[ -z "$data" ] && exit 0

echo "$data" > "$FEEDS/sysmon.json.tmp" && mv "$FEEDS/sysmon.json.tmp" "$FEEDS/sysmon.json"

fmt_gb() { awk -v val="$1" 'BEGIN{printf "%.0f", val/1048576}'; }
fmt_mb() { awk -v val="$1" 'BEGIN{printf "%.0f", val/1024}'; }
fmt_io() {
  local b=$1
  if [ "$b" -ge 1073741824 ]; then awk -v val="$b" 'BEGIN{printf "%.1fG", val/1073741824}'
  elif [ "$b" -ge 1048576 ]; then awk -v val="$b" 'BEGIN{printf "%.0fM", val/1048576}'
  elif [ "$b" -ge 1024 ]; then awk -v val="$b" 'BEGIN{printf "%.0fK", val/1024}'
  else echo "${b}B"; fi
}

eval $(jq -r '
  [
    (.gpu.busy_pct // 0),
    (.gpu.temp_c // 0),
    (.gpu.freq // 0),
    (.cpu.avg // 0),
    (.temp.cpu_c // 0),
    (.ram.used_kb // 0),
    (.ram.total_kb // 0),
    (.ram.used_pct // 0),
    (.ram.swap_used_kb // 0),
    (.disk.read_speed // 0),
    (.disk.write_speed // 0),
    (.temp.fan1 // 0),
    (.asus.profile // "unknown"),
    (.workspace.num // 1)
  ] | @sh "gpu_pct=\(.[0]); gpu_temp=\(.[1]); gpu_freq=\(.[2]); cpu_avg=\(.[3]); cpu_tc=\(.[4]); ram_ukb=\(.[5]); ram_tkb=\(.[6]); ram_pct=\(.[7]); ram_swp=\(.[8]); disk_r=\(.[9]); disk_w=\(.[10]); fan1=\(.[11]); asus_prof=\(.[12]); ws_num=\(.[13])"
' <<< "$data")

# 1. GPU
(
  ACCENT="#fab387"
  cls="good"; [ "$gpu_pct" -ge 40 ] && cls="medium"; [ "$gpu_pct" -ge 70 ] && cls="warning"; [ "$gpu_pct" -ge 90 ] && cls="critical"
  seg=10; fil=$((gpu_pct*seg/100)); [ "$fil" -gt "$seg" ] && fil=$seg; [ "$fil" -lt 0 ] && fil=0; emp=$((seg-fil))
  bar=""; for ((i=0; i<fil; i++)); do bar+="▐"; done; for ((i=0; i<emp; i++)); do bar+="░"; done
  draw_module "" "<b><span font='8'>${bar}</span> ${gpu_pct}%</b>" "<span size='small'>${gpu_freq}MHz 󰔐 ${gpu_temp}°C</span>" "$ACCENT" "$cls"
) > "$FEEDS/gpu.json.tmp" && mv "$FEEDS/gpu.json.tmp" "$FEEDS/gpu.json"

# 1b. Compact GPU (for vertical-lite bar)
(
  cls="good"; [ "$gpu_pct" -ge 40 ] && cls="medium"; [ "$gpu_pct" -ge 70 ] && cls="warning"; [ "$gpu_pct" -ge 90 ] && cls="critical"
  n=4; fill=$((gpu_pct * n / 100))
  [ "$fill" -gt "$n" ] && fill=$n; [ "$fill" -lt 0 ] && fill=0
  filled=""; dim=""
  for ((i=0; i<fill; i++)); do filled+="󰾲"; done
  for ((i=fill; i<n; i++)); do dim+="󰾲"; done
  text="${filled:+<span fgcolor='#fab387'>${filled}</span>}${dim:+<span fgcolor='#383838'>${dim}</span>}"
  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
) > "$FEEDS/compact-gpu.json.tmp" && mv "$FEEDS/compact-gpu.json.tmp" "$FEEDS/compact-gpu.json"

# 2. CPU
(
  ACCENT="#a6e3a1"
  thin_space=$(printf '\xe2\x80\x89')
  cls="good"; [ "$cpu_avg" -ge 40 ] && cls="medium"; [ "$cpu_avg" -ge 70 ] && cls="warning"; [ "$cpu_avg" -ge 90 ] && cls="critical"
  bar1=""; bar2=""
  
  cores_str=$(jq -r '.cpu.per_core[]? // -1' <<< "$data")
  c=0
  for p in $cores_str; do
    if [ "$p" -ge 90 ]; then col="#f38ba8"
    elif [ "$p" -ge 70 ]; then col="#fab387"
    elif [ "$p" -ge 40 ]; then col="#f9e2af"
    elif [ "$p" -ge 15 ]; then col="#89b4fa"
    elif [ "$p" -ge 1 ]; then col="#484848"
    elif [ "$p" -ge 0 ]; then col="#383838"
    else col="#1e1e2a"; fi
    
    if [ "$c" -lt 8 ]; then
      [ -n "$bar1" ] && bar1+="$thin_space"
      bar1+="<span fgcolor=\"$col\">󰘚</span>"
    else
      [ -n "$bar2" ] && bar2+="$thin_space"
      bar2+="<span fgcolor=\"$col\">󰘚</span>"
    fi
    c=$((c+1))
  done
  
  tc_fmt=$(printf "%.0f" "$cpu_tc")
  draw_module "" "<span font='11'>${bar1}"$'\n'"${bar2}</span>" "<span size='small'><span fgcolor=\"#a6e3a1\">AVG ${cpu_avg}%</span> 󰔐 ${tc_fmt}°C</span>" "$ACCENT" "$cls"
) > "$FEEDS/cpu.json.tmp" && mv "$FEEDS/cpu.json.tmp" "$FEEDS/cpu.json"

# 2b. Compact CPU (for vertical-lite bar)
(
  cls="good"; [ "$cpu_avg" -ge 40 ] && cls="medium"; [ "$cpu_avg" -ge 70 ] && cls="warning"; [ "$cpu_avg" -ge 90 ] && cls="critical"
  cores_str=$(jq -r '.cpu.per_core[]? // 0' <<< "$data")
  rows=""; c=0
  for r in $(seq 0 3); do
    row=""
    for col in $(seq 0 3); do
      p=$(echo "$cores_str" | sed -n "$((c+1))p")
      c=$((c+1))
      if [ "$p" -ge 90 ]; then col="#f38ba8"
      elif [ "$p" -ge 70 ]; then col="#fab387"
      elif [ "$p" -ge 40 ]; then col="#f9e2af"
      elif [ "$p" -ge 15 ]; then col="#89b4fa"
      elif [ "$p" -ge 1 ]; then col="#484848"
      else col="#383838"; fi
      row+="<span fgcolor=\"$col\">󰘚</span>"
    done
    rows+="$row"
    [ "$r" -lt 3 ] && rows+=$'\n'
  done
  text="<span line_height='0.65'>${rows}</span>"
  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
) > "$FEEDS/compact-cpu.json.tmp" && mv "$FEEDS/compact-cpu.json.tmp" "$FEEDS/compact-cpu.json"

# 3. RAM
(
  ACCENT="#89b4fa"
  thin_space=$(printf '\xe2\x80\x89')
  cls="good"; [ "$ram_pct" -ge 50 ] && cls="medium"; [ "$ram_pct" -ge 75 ] && cls="warning"; [ "$ram_pct" -ge 90 ] && cls="critical"
  fkb=$((ram_tkb - ram_ukb))
  ug=$(fmt_gb "$ram_ukb"); fg=$(fmt_gb "$fkb")
  swap_gb=$(awk "BEGIN {printf \"%.1f\", $ram_swp / 1048576}")
  seg=7; su=$((ram_pct*seg/100)); [ "$su" -eq 0 ] && su=1; [ "$su" -gt "$seg" ] && su=$seg
  row1=$(printf "<b><span fgcolor='%s'>%2sGb</span><span fgcolor='#a3a3a3' font='8'>  :: </span><span fgcolor='#ffffff'> %2sGb</span></b>" "$ACCENT" "$ug" "$fg")
  bar=""; for ((i=0; i<seg; i++)); do
    if [ "$i" -lt "$su" ]; then bar+="$thin_space"; else bar+="<span fgcolor='#ffffff'>$thin_space</span>"; fi
  done
  draw_module "" "<span font='8'>${row1}</span>" "<span font='12'>${bar}</span>" "$ACCENT" "$cls" "<span size='small'>swapped: ${swap_gb}Gb</span>"
) > "$FEEDS/ram.json.tmp" && mv "$FEEDS/ram.json.tmp" "$FEEDS/ram.json"

# 3b. Compact RAM (for vertical-lite bar)
(
  cls="good"; [ "$ram_pct" -ge 50 ] && cls="medium"; [ "$ram_pct" -ge 75 ] && cls="warning"; [ "$ram_pct" -ge 90 ] && cls="critical"
  n=4; total=$((n * 2))
  fill=$((ram_pct * total / 100))
  [ "$fill" -gt "$total" ] && fill=$total; [ "$fill" -lt 0 ] && fill=0
  r1=""; r2=""
  for ((i=0; i<n; i++)); do
    [ "$i" -lt "$fill" ] && r1+="<span fgcolor='#89b4fa'></span>" || r1+="<span fgcolor='#383838'></span>"
    [ "$((i + n))" -lt "$fill" ] && r2+="<span fgcolor='#89b4fa'></span>" || r2+="<span fgcolor='#383838'></span>"
  done
  text="${r1}"$'\n'"${r2}"
  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
) > "$FEEDS/compact-ram.json.tmp" && mv "$FEEDS/compact-ram.json.tmp" "$FEEDS/compact-ram.json"

# 4. SSD
(
  ACCENT="#a6e3a1"
  used_gb=$(df / | awk 'END{printf "%.0f", $3/1048576}')
  tot=$(df -h / | awk 'END{print $2}')
  up=$(df / | awk 'END{print $5}' | tr -d '%')
  cls="good"; [ "$up" -ge 70 ] && cls="medium"; [ "$up" -ge 85 ] && cls="warning"; [ "$up" -ge 95 ] && cls="critical"
  
  if [ "$disk_r" -gt 0 ]; then
    rf=$(printf "%6s" "$(fmt_io "$disk_r")/s" | sed 's/ /\&#160;/g')
    r_icon="<span fgcolor='#a6e3a1'>●</span>"
  else
    rf=$(printf "%6s" "-" | sed 's/ /\&#160;/g')
    r_icon="<span fgcolor='#585b70'>○</span>"
  fi

  if [ "$disk_w" -gt 0 ]; then
    wf=$(printf "%6s" "$(fmt_io "$disk_w")/s" | sed 's/ /\&#160;/g')
    w_icon="<span fgcolor='#f38ba8'>●</span>"
  else
    wf=$(printf "%6s" "-" | sed 's/ /\&#160;/g')
    w_icon="<span fgcolor='#585b70'>○</span>"
  fi

  row1="<b><span fgcolor='$ACCENT'>${used_gb}Gb</span><span fgcolor='#cdd6f4' font='7'> of </span><span fgcolor='#ffa6e1'>${tot}</span></b>"
  row2=$(printf "%s <span fgcolor='#cdd6f4'>read </span> <span fgcolor='#89b4fa'>%s</span>" "$r_icon" "$rf")
  row3=$(printf "%s <span fgcolor='#cdd6f4'>write</span> <span fgcolor='#89b4fa'>%s</span>" "$w_icon" "$wf")

  draw_module "" "$row1" "<span font='7'>$row2</span>" "$ACCENT" "$cls" "<span font='7'>$row3</span>"
) > "$FEEDS/ssd.json.tmp" && mv "$FEEDS/ssd.json.tmp" "$FEEDS/ssd.json"

# 4b. Compact SSD (for vertical-lite bar)
(
  up=$(df / | awk 'END{print $5}' | tr -d '%')
  cls="good"; [ "$up" -ge 70 ] && cls="medium"; [ "$up" -ge 85 ] && cls="warning"; [ "$up" -ge 95 ] && cls="critical"
  n=4; fill=$((up * n / 100))
  [ "$fill" -gt "$n" ] && fill=$n; [ "$fill" -lt 0 ] && fill=0
  filled=""; dim=""
  for ((i=0; i<fill; i++)); do filled+="󰋊"; done
  for ((i=fill; i<n; i++)); do dim+="󰋊"; done
  text="${filled:+<span fgcolor='#a6e3a1'>${filled}</span>}${dim:+<span fgcolor='#383838'>${dim}</span>}"
  jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
) > "$FEEDS/compact-ssd.json.tmp" && mv "$FEEDS/compact-ssd.json.tmp" "$FEEDS/compact-ssd.json"

# 5. TEMP
(
  ACCENT="#f38ba8"
  cls="good"; [ "$(printf "%.0f" "$cpu_tc")" -ge 60 ] && cls="warning"; [ "$(printf "%.0f" "$cpu_tc")" -ge 85 ] && cls="critical"
  draw_module "" "$(printf "%.0f" "$cpu_tc")°C" "󰈐 ${fan1} RPM" "$ACCENT" "$cls"
) > "$FEEDS/temp.json.tmp" && mv "$FEEDS/temp.json.tmp" "$FEEDS/temp.json"

# 6. ASUS
(
  ACCENT="#94e2d5"
  prof=$(echo "$asus_prof" | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  case "$prof" in
    *quiet*)        r=" Quiet"; cls="good" ;;
    *balanced*)     r=" Balanced"; cls="medium" ;;
    *performance*)  r=" Performance"; cls="warning" ;;
    *)              r="${asus_prof:-Unknown}"; cls="good" ;;
  esac
  draw_module "" "<b>${r}</b>" "<span size='small'>󰈐 ${fan1} RPM</span>" "$ACCENT" "$cls"
) > "$FEEDS/asus.json.tmp" && mv "$FEEDS/asus.json.tmp" "$FEEDS/asus.json"

# 7. WORKSPACE
printf '{"text":" %s ","class":"ws%s","tooltip":"Workspace %s"}\n' \
  "$ws_num" "$ws_num" "$ws_num" \
  > "$FEEDS/workspace.json.tmp" && mv "$FEEDS/workspace.json.tmp" "$FEEDS/workspace.json"
