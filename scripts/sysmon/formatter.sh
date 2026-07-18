#!/usr/bin/env bash
# formatter.sh — sysmon JSON on stdin → feeds for 5 full + 5 compact modules
# Feed-only. No df / sensors / swaymsg.
set -uo pipefail
export LC_ALL=C

DIR="$(cd "$(dirname "$0")" && pwd)"
CFG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
WAYBAR_ROOT="$(cd "$DIR/../.." && pwd)"

# shellcheck disable=SC1091
[ -f "$CFG_HOME/sysmon.env" ] && . "$CFG_HOME/sysmon.env"
# shellcheck disable=SC1091
[ -f "$WAYBAR_ROOT/sysmon.env" ] && . "$WAYBAR_ROOT/sysmon.env"
# shellcheck disable=SC1091
source "$DIR/../lib/draw-module.sh"

FEEDS="${SYSMON_FEEDS:-$CFG_HOME/feeds}"
LOG_DIR="${SYSMON_LOG_DIR:-$CFG_HOME/logs}"
mkdir -p "$FEEDS" "$LOG_DIR"
LOG="$LOG_DIR/sysmon.log"
log() { printf '%s formatter: %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

data=$(cat)
[ -z "$data" ] && exit 0

if ! jq -e . >/dev/null 2>&1 <<< "$data"; then
  log "invalid JSON on stdin"
  exit 0
fi

printf '%s\n' "$data" >"$FEEDS/sysmon.json.tmp" && mv "$FEEDS/sysmon.json.tmp" "$FEEDS/sysmon.json"

fmt_gb() { awk -v val="${1:-0}" 'BEGIN{printf "%.0f", val/1048576}'; }
fmt_io() {
  local b=${1:-0}
  if [ "$b" -ge 1073741824 ]; then awk -v v="$b" 'BEGIN{printf "%.1fG", v/1073741824}'
  elif [ "$b" -ge 1048576 ]; then awk -v v="$b" 'BEGIN{printf "%.0fM", v/1048576}'
  elif [ "$b" -ge 1024 ]; then awk -v v="$b" 'BEGIN{printf "%.0fK", v/1024}'
  else echo "${b}B"; fi
}
fmt_spd() {
  local b=${1:-0}
  if [ "$b" -ge 1048576 ]; then awk -v v="$b" 'BEGIN{printf "%.1fM", v/1048576}'
  elif [ "$b" -ge 1024 ]; then awk -v v="$b" 'BEGIN{printf "%.0fK", v/1024}'
  else echo "${b}B"; fi
}

safe_mod() {
  local name="$1" fn="$2"
  if ! "$fn" >"$FEEDS/${name}.json.tmp" 2>>"$LOG"; then
    log "$name failed"
    rm -f "$FEEDS/${name}.json.tmp"
    return 0
  fi
  mv "$FEEDS/${name}.json.tmp" "$FEEDS/${name}.json"
}

eval "$(jq -r '
  [
    (.gpu.busy_pct // 0 | floor),
    (.gpu.temp_c // 0 | floor),
    (.gpu.freq // 0 | floor),
    (.cpu.avg // 0 | floor),
    (.temp.cpu_c // 0),
    (.ram.used_kb // 0 | floor),
    (.ram.total_kb // 0 | floor),
    (.ram.used_pct // 0 | floor),
    (.ram.swap_used_kb // 0 | floor),
    (.disk.read_speed // 0 | floor),
    (.disk.write_speed // 0 | floor),
    (.disk.used_pct // 0 | floor),
    (.disk.used_bytes // 0 | floor),
    (.disk.total_human // "?"),
    (.temp.fan1 // 0 | floor),
    (.net.rx_speed // 0 | floor),
    (.net.tx_speed // 0 | floor)
  ] | @sh "
    gpu_pct=\(.[0]); gpu_temp=\(.[1]); gpu_freq=\(.[2]);
    cpu_avg=\(.[3]); cpu_tc=\(.[4]);
    ram_ukb=\(.[5]); ram_tkb=\(.[6]); ram_pct=\(.[7]); ram_swp=\(.[8]);
    disk_r=\(.[9]); disk_w=\(.[10]); disk_up=\(.[11]); disk_used_b=\(.[12]);
    disk_th=\(.[13]);
    fan1=\(.[14]); net_rx=\(.[15]); net_tx=\(.[16])
  "
' <<< "$data")" || { log "field extract failed"; exit 0; }

gpu_pct=${gpu_pct:-0}; gpu_temp=${gpu_temp:-0}; gpu_freq=${gpu_freq:-0}
cpu_avg=${cpu_avg:-0}; cpu_tc=${cpu_tc:-0}
ram_ukb=${ram_ukb:-0}; ram_tkb=${ram_tkb:-0}; ram_pct=${ram_pct:-0}; ram_swp=${ram_swp:-0}
disk_r=${disk_r:-0}; disk_w=${disk_w:-0}; disk_up=${disk_up:-0}; disk_used_b=${disk_used_b:-0}
disk_th=${disk_th:-?}
fan1=${fan1:-0}; net_rx=${net_rx:-0}; net_tx=${net_tx:-0}

# ── 1. GPU ─────────────────────────────────────────────────────────────────
mod_gpu() {
  local ACCENT="#fab387" cls="good"
  [ "$gpu_pct" -ge 40 ] && cls="medium"
  [ "$gpu_pct" -ge 70 ] && cls="warning"
  [ "$gpu_pct" -ge 90 ] && cls="critical"
  local seg=10
  local fil=$((gpu_pct * seg / 100))
  [ "$fil" -gt "$seg" ] && fil=$seg
  [ "$fil" -lt 0 ] && fil=0
  local emp=$((seg - fil))
  local bar="" i
  for ((i = 0; i < fil; i++)); do bar+="▐"; done
  for ((i = 0; i < emp; i++)); do bar+="░"; done  
  draw_module "" \
    "<b><span font='9'>${bar}</span> ${gpu_pct}%</b>" \
    "<span size='small' line_height='1.4'>${gpu_freq}MHz 󰔐 ${gpu_temp}°C</span>" \
    "$ACCENT" "$cls"
}

mod_compact_gpu() {
  local cls="good"
  [ "$gpu_pct" -ge 40 ] && cls="medium"
  [ "$gpu_pct" -ge 70 ] && cls="warning"
  [ "$gpu_pct" -ge 90 ] && cls="critical"
  local n=4
  local fill=$((gpu_pct * n / 100))
  local i
  [ "$fill" -gt "$n" ] && fill=$n
  [ "$fill" -lt 0 ] && fill=0
  local filled="" dim=""
  for ((i = 0; i < fill; i++)); do filled+="󰾲"; done
  for ((i = fill; i < n; i++)); do dim+="󰾲"; done
  local text=""
  [ -n "$filled" ] && text+="<span fgcolor='#fab387'>${filled}</span>"
  [ -n "$dim" ] && text+="<span fgcolor='#383838'>${dim}</span>"
  jq -nc --arg text "$text" --arg cls "$cls" '{text:$text, class:$cls}'
}

# ── 2. CPU ─────────────────────────────────────────────────────────────────
mod_cpu() {
  local ACCENT="#a6e3a1" cls="good"
  local thin_space
  thin_space=$(printf '\xe2\x80\x8b')
  [ "$cpu_avg" -ge 40 ] && cls="medium"
  [ "$cpu_avg" -ge 70 ] && cls="warning"
  [ "$cpu_avg" -ge 90 ] && cls="critical"
  local bar1="" bar2="" c=0 col p
  local cores_str
  cores_str=$(jq -r '.cpu.per_core[]? // -1' <<< "$data")
  for p in $cores_str; do
    if   [ "$p" -ge 90 ]; then col="#f38ba8"
    elif [ "$p" -ge 70 ]; then col="#fab387"
    elif [ "$p" -ge 40 ]; then col="#09e2af"
    elif [ "$p" -ge 15 ]; then col="#89b4fa"
    elif [ "$p" -ge 1 ];  then col="#484848"
    elif [ "$p" -ge 0 ];  then col="#383838"
    else col="#1e1e2a"; fi
    if [ "$c" -lt 8 ]; then
      [ -n "$bar1" ] && bar1+="$thin_space"
      bar1+="<span fgcolor=\"$col\" font='9' line_height='0.4'></span>"
    else
      [ -n "$bar2" ] && bar2+="$thin_space"
      bar2+="<span fgcolor=\"$col\" font='9' line_height='0.4'></span>"
    fi
    c=$((c + 1))
  done
  local tc_fmt
  tc_fmt=$(printf "%.0f" "$cpu_tc")
  draw_module "" \
    "<span line_height='0.8' letter_spacing='3000'>${bar1}"$'\n'"${bar2}</span>" \
    "<span line_height='1.4' size='small'><span fgcolor=\"#a6e3a1\">AVG ${cpu_avg}%</span> 󰔐 ${tc_fmt}°C</span>" \
    "$ACCENT" "$cls"
}

mod_compact_cpu() {
  local cls="good"
  [ "$cpu_avg" -ge 40 ] && cls="medium"
  [ "$cpu_avg" -ge 70 ] && cls="warning"
  [ "$cpu_avg" -ge 90 ] && cls="critical"
  local cores_str c=0 rows="" r coli p color
  cores_str=$(jq -r '.cpu.per_core[]? // 0' <<< "$data")
  for r in $(seq 0 3); do
    local row=""
    for coli in $(seq 0 3); do
      p=$(printf '%s\n' "$cores_str" | sed -n "$((c + 1))p")
      p=${p:-0}
      c=$((c + 1))
      if   [ "$p" -ge 90 ]; then color="#f38ba8"
      elif [ "$p" -ge 70 ]; then color="#fab387"
      elif [ "$p" -ge 40 ]; then color="#f9e2af"
      elif [ "$p" -ge 15 ]; then color="#89b4fa"
      elif [ "$p" -ge 1 ];  then color="#484848"
      else color="#383838"; fi
      row+="<span fgcolor=\"$color\">󰘚</span>"
    done
    rows+="$row"
    [ "$r" -lt 3 ] && rows+=$'\n'
  done
  jq -nc --arg text "<span line_height='0.65'>${rows}</span>" --arg cls "$cls" \
    '{text:$text, class:$cls}'
}

# ── 3. RAM ─────────────────────────────────────────────────────────────────
mod_ram() {
  local ACCENT="#89b4fa" cls="good"
  local thin_space
  thin_space=$(printf '\xe2\x80\x8b')
  [ "$ram_pct" -ge 50 ] && cls="medium"
  [ "$ram_pct" -ge 75 ] && cls="warning"
  [ "$ram_pct" -ge 90 ] && cls="critical"
  local fkb=$((ram_tkb - ram_ukb))
  local ug fg swap_gb
  ug=$(fmt_gb "$ram_ukb")
  fg=$(fmt_gb "$fkb")
  swap_gb=$(awk -v s="$ram_swp" 'BEGIN{printf "%.1f", s/1048576}')
  local n=6
  local seg=$((n * 2))
  local su=$((ram_pct * seg / 100))
  [ "$su" -eq 0 ] && [ "$ram_pct" -gt 0 ] && su=1
  [ "$su" -gt "$seg" ] && su=$seg
  local row1 bar="" bar2="" i
  row1=$(printf "<b><span fgcolor='%s'>%2sGb</span><span fgcolor='#a3a3a3' font='8'>  :: </span><span fgcolor='#ffffff'> %2sGb</span></b>" \
    "$ACCENT" "$ug" "$fg")
  for ((i = 0; i < n; i++)); do
    if [ "$i" -lt "$su" ]; then bar+="$thin_space"
    else bar+="<span fgcolor='#ffffff'>$thin_space</span>"; fi
    if [ "$((i + n))" -lt "$su" ]; then bar2+="$thin_space"
    else bar2+="<span fgcolor='#ffffff'>$thin_space</span>"; fi
  done
  # draw_module: with row4 set → prints r1, r2, r4, r3
  draw_module "" \
    "<span font='8'>${row1}</span>" \
    "<span font='12' letter_spacing='4000'>${bar}</span>" \
    "$ACCENT" "$cls" \
    "<span size='small'>swapped: ${swap_gb}Gb</span>" \
    "<span font='12' line_height='0.5' letter_spacing='4000'>${bar2}</span>"
}

mod_compact_ram() {
  local cls="good"
  [ "$ram_pct" -ge 50 ] && cls="medium"
  [ "$ram_pct" -ge 75 ] && cls="warning"
  [ "$ram_pct" -ge 90 ] && cls="critical"
  local n=4
  local total=$((n * 2))
  local fill=$((ram_pct * total / 100))
  local i
  [ "$fill" -gt "$total" ] && fill=$total
  [ "$fill" -lt 0 ] && fill=0
  local r1="" r2=""
  for ((i = 0; i < n; i++)); do
    if [ "$i" -lt "$fill" ]; then r1+="<span fgcolor='#89b4fa'></span>"
    else r1+="<span fgcolor='#383838'></span>"; fi
    if [ "$((i + n))" -lt "$fill" ]; then r2+="<span fgcolor='#89b4fa'></span>"
    else r2+="<span fgcolor='#383838'></span>"; fi
  done
  jq -nc --arg text "${r1}"$'\n'"${r2}" --arg cls "$cls" '{text:$text, class:$cls}'
}

# ── 4. SSD / IO  (capacity + usage bar from feed used_pct) ─────────────────
mod_ssd() {
  local ACCENT="#a6e3a1" cls="good" up="$disk_up"
  case "$up" in ''|*[!0-9]*) up=0 ;; esac
  [ "$up" -ge 70 ] && cls="medium"
  [ "$up" -ge 85 ] && cls="warning"
  [ "$up" -ge 95 ] && cls="critical"

  local used_gb
  used_gb=$(awk -v b="$disk_used_b" 'BEGIN{printf "%.0f", b/1073741824}')

  local rf wf r_icon w_icon
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

  # usage bar — 12 segments from disk.used_pct
  local n=12
  local fill=$((up * n / 100))
  local i bar=""
  [ "$fill" -gt "$n" ] && fill=$n
  [ "$fill" -lt 0 ] && fill=0
  # show at least 1 block if up>0 so empty disks aren't "full empty" confusion
  [ "$fill" -eq 0 ] && [ "$up" -gt 0 ] && fill=1
  for ((i = 0; i < fill; i++)); do
    bar+="<span fgcolor='#a6e3a1'>━</span>"
  done
  for ((i = fill; i < n; i++)); do
    bar+="<span fgcolor='#45475a'>━</span>"
  done

  local row1 row_read row_write
  row1="<b><span fgcolor='$ACCENT'>${used_gb}Gb</span><span fgcolor='#cdd6f4' font='7'> of </span><span fgcolor='#ffa6e1'>${disk_th}</span></b>"
  row_read=$(printf "%s <span fgcolor='#cdd6f4'>read </span> <span fgcolor='#89b4fa'>%s</span>" "$r_icon" "$rf")
  row_write=$(printf "%s <span fgcolor='#cdd6f4'>write</span> <span fgcolor='#89b4fa'>%s</span>" "$w_icon" "$wf")

  # draw_module order with r4: r1, r2, r4, r3 → capacity, bar, read, write
  draw_module "" \
    "$row1" \
    "<span font='9'>${bar}</span>" \
    "$ACCENT" "$cls" \
    "<span font='7'>${row_write}</span>" \
    "<span font='7'>${row_read}</span>"
}

mod_compact_ssd() {
  local up="$disk_up" cls="good"
  case "$up" in ''|*[!0-9]*) up=0 ;; esac
  [ "$up" -ge 70 ] && cls="medium"
  [ "$up" -ge 85 ] && cls="warning"
  [ "$up" -ge 95 ] && cls="critical"
  local n=4
  local fill=$((up * n / 100))
  local i filled="" dim=""
  [ "$fill" -gt "$n" ] && fill=$n
  [ "$fill" -lt 0 ] && fill=0
  [ "$fill" -eq 0 ] && [ "$up" -gt 0 ] && fill=1
  for ((i = 0; i < fill; i++)); do filled+="󰋊"; done
  for ((i = fill; i < n; i++)); do dim+="󰋊"; done
  local text=""
  [ -n "$filled" ] && text+="<span fgcolor='#a6e3a1'>${filled}</span>"
  [ -n "$dim" ] && text+="<span fgcolor='#383838'>${dim}</span>"
  jq -nc --arg text "$text" --arg cls "$cls" '{text:$text, class:$cls}'
}

# ── 5. Net + fan ───────────────────────────────────────────────────────────
mod_netfan() {
  local ACCENT="#89dceb" cls="good"
  local total=$((net_rx + net_tx))
  if   [ "$total" -gt 5242880 ]; then cls="critical"
  elif [ "$total" -gt 2097152 ]; then cls="warning"
  elif [ "$total" -gt 512000 ];  then cls="medium"
  fi
  local rx_fmt tx_fmt
  rx_fmt=$(fmt_spd "$net_rx")
  tx_fmt=$(fmt_spd "$net_tx")
  draw_module "" \
    "<b>↓${rx_fmt} ↑${tx_fmt}</b>" \
    "󰈐 ${fan1} RPM" \
    "$ACCENT" "$cls"
}

mod_compact_netfan() {
  local cls="good"
  local total=$((net_rx + net_tx))
  if   [ "$total" -gt 5242880 ]; then cls="critical"
  elif [ "$total" -gt 2097152 ]; then cls="warning"
  elif [ "$total" -gt 512000 ];  then cls="medium"
  fi
  local n=4 fill=0
  if   [ "$total" -gt 5242880 ]; then fill=4
  elif [ "$total" -gt 2097152 ]; then fill=3
  elif [ "$total" -gt 512000 ];  then fill=2
  elif [ "$total" -gt 1024 ];    then fill=1
  fi
  local i filled="" dim=""
  for ((i = 0; i < fill; i++)); do filled+="󰈀"; done
  for ((i = fill; i < n; i++)); do dim+="󰈀"; done
  local line1=""
  [ -n "$filled" ] && line1+="<span fgcolor='#89dceb'>${filled}</span>"
  [ -n "$dim" ] && line1+="<span fgcolor='#383838'>${dim}</span>"
  local line2
  line2=$(printf "<span fgcolor='#a6adc8' size='small'>󰈐 %s</span>" "$fan1")
  jq -nc --arg text "${line1}"$'\n'"${line2}" --arg cls "$cls" '{text:$text, class:$cls}'
}

safe_mod gpu            mod_gpu
safe_mod compact-gpu    mod_compact_gpu
safe_mod cpu            mod_cpu
safe_mod compact-cpu    mod_compact_cpu
safe_mod ram            mod_ram
safe_mod compact-ram    mod_compact_ram
safe_mod ssd            mod_ssd
safe_mod compact-ssd    mod_compact_ssd
safe_mod netfan         mod_netfan
safe_mod compact-netfan mod_compact_netfan
