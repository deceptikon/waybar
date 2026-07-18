#!/usr/bin/env bash
# mapper.sh — stdin (collect sections) → unified sysmon JSON on stdout
# Side effect: feeds/.state for rate deltas
# Diagnostics: logs/sysmon.log only (never stdout)
set -euo pipefail
export LC_ALL=C

WAYBAR_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
FEEDS="${WAYBAR_HOME}/feeds"
LOG_DIR="${WAYBAR_HOME}/logs"
ENV_FILE="${WAYBAR_HOME}/sysmon.env"
SYSMON_LOG="${SYSMON_LOG:-${LOG_DIR}/sysmon.log}"
STATE_FILE="${FEEDS}/.state"

mkdir -p "$FEEDS" "$LOG_DIR"

if [ -f "$ENV_FILE" ]; then
  # optional SYSMON_* overrides — see sysmon.env at config root
  . "$ENV_FILE"
fi

log() {
  printf '%s mapper: %s\n' "$(date -Iseconds)" "$*" >>"$SYSMON_LOG"
}

# ── stdin sections ─────────────────────────────────────────────────────────
section=""
cpu1_lines="" cpu2_lines="" mem_lines="" disk_lines="" df_lines=""
net_lines="" sensors_json="" gpu_lines="" fan_lines="" timestamp_line=""

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    TIMESTAMP*) timestamp_line="$line"; section=""; continue ;;
    "CPU_SNAP_1") section="cpu1"; continue ;;
    "CPU_SNAP_2") section="cpu2"; continue ;;
    "MEM_RAW") section="mem"; continue ;;
    "DISK_RAW") section="disk"; continue ;;
    "DF_RAW") section="df"; continue ;;
    "NET_RAW") section="net"; continue ;;
    "SENSORS_JSON") section="sensors"; continue ;;
    "GPU_RAW") section="gpu"; continue ;;
    "FAN_RAW") section="fan"; continue ;;
    "SWAP_RAW"|"ASUS_PROFILE"|"WORKSPACE_RAW") section="skip"; continue ;;
  esac
  case "$section" in
    cpu1) cpu1_lines+="$line"$'\n' ;;
    cpu2) cpu2_lines+="$line"$'\n' ;;
    mem) mem_lines+="$line"$'\n' ;;
    disk) disk_lines+="$line"$'\n' ;;
    df) df_lines+="$line"$'\n' ;;
    net) net_lines+="$line"$'\n' ;;
    sensors) sensors_json+="$line" ;;
    gpu) gpu_lines+="$line"$'\n' ;;
    fan) fan_lines+="$line"$'\n' ;;
    skip|"") ;;
  esac
done

# ── CPU ────────────────────────────────────────────────────────────────────
cpu_avg=0
cpu_per_core='[]'
if [ -n "$cpu1_lines" ] && [ -n "$cpu2_lines" ]; then
  data=$(
    awk '
      FNR==NR && /^cpu[0-9]+ / {
        t=0; for (i=2;i<=NF;i++) t+=$i
        total[$1]=t; idle[$1]=$5+$6; next
      }
      /^cpu[0-9]+ / {
        n=$1; t2=0; for (i=2;i<=NF;i++) t2+=$i
        i2=$5+$6
        dt=t2-total[n]; di=i2-idle[n]
        if (dt<=0) dt=1
        used=dt-di
        p=int((used*100)/dt)
        if (p<0) p=0; if (p>100) p=100
        print "core", p
        su+=used; st+=dt
      }
      END {
        if (st>0) printf "avg %d\n", int((su*100)/st)
        else print "avg 0"
      }
    ' <(printf '%s' "$cpu1_lines") <(printf '%s' "$cpu2_lines")
  )
  cpu_avg=$(awk '/^avg / { print $2; exit }' <<< "$data")
  cpu_per_core=$(awk '/^core / { print $2 }' <<< "$data" \
    | jq -Rs 'split("\n") | map(select(length>0) | tonumber)')
fi
: "${cpu_avg:=0}"
: "${cpu_per_core:=[]}"

# ── RAM ────────────────────────────────────────────────────────────────────
ram_used_kb=0 ram_total_kb=0 ram_avail_kb=0 ram_used_pct=0
swap_used_kb=0 swap_total_kb=0 swap_pct=0
if [ -n "$mem_lines" ]; then
  ram_total_kb=$(awk '/^MemTotal:/ { print $2+0; exit }' <<< "$mem_lines")
  ram_avail_kb=$(awk '/^MemAvailable:/ { print $2+0; exit }' <<< "$mem_lines")
  ram_used_kb=$((ram_total_kb - ram_avail_kb))
  if [ "$ram_total_kb" -gt 0 ]; then
    ram_used_pct=$((ram_used_kb * 100 / ram_total_kb))
  fi
  swap_total_kb=$(awk '/^SwapTotal:/ { print $2+0; exit }' <<< "$mem_lines")
  swap_free_kb=$(awk '/^SwapFree:/ { print $2+0; exit }' <<< "$mem_lines")
  swap_used_kb=$((swap_total_kb - swap_free_kb))
  if [ "$swap_total_kb" -gt 0 ]; then
    swap_pct=$((swap_used_kb * 100 / swap_total_kb))
  fi
fi

human_bytes() {
  awk -v u="$1" 'BEGIN {
    if (u >= 1099511627776) printf "%.1fT", u/1099511627776
    else if (u >= 1073741824) printf "%.1fG", u/1073741824
    else if (u >= 1048576)    printf "%.0fM", u/1048576
    else if (u >= 1024)       printf "%.0fK", u/1024
    else                      printf "%dB", u
  }'
}

# ── DF + disk device (env → autodetect → empty) ────────────────────────────
disk_used_bytes=0 disk_total_bytes=0 disk_used_pct=0
disk_used_human="0G" disk_total_human="0G"
disk_dev="${SYSMON_DISK_DEV:-}"
df_fs=""

if [ -n "$df_lines" ]; then
  # df -B1 -P: Filesystem 1B-blocks Used Available Capacity Mounted
  df_row=$(awk 'NR==2 {
    gsub(/%/, "", $5)
    printf "%s %d %d %d %d %s\n", $1, $2+0, $3+0, $4+0, $5+0, $6
    exit
  }' <<< "$df_lines")
  if [ -n "$df_row" ]; then
    df_fs=$(awk '{ print $1 }' <<< "$df_row")
    disk_total_bytes=$(awk '{ print $2 }' <<< "$df_row")
    disk_used_bytes=$(awk '{ print $3 }' <<< "$df_row")
    disk_used_pct=$(awk '{ print $5 }' <<< "$df_row")
    disk_used_human=$(human_bytes "$disk_used_bytes")
    disk_total_human=$(human_bytes "$disk_total_bytes")
  else
    log "df: no data row in DF_RAW"
  fi
fi

if [ -z "$disk_dev" ] && [ -n "$df_fs" ]; then
  base=$(basename "$df_fs")
  if [ -b "$df_fs" ] && command -v lsblk >/dev/null; then
    pk=$(lsblk -no PKNAME "$df_fs" | head -1 | tr -d '[:space:]')
    if [ -n "$pk" ]; then
      base=$pk
    fi
  else
    # nvme0n1p5 → nvme0n1 ; sda1 → sda
    base=$(printf '%s\n' "$base" | sed -E 's/p?[0-9]+$//')
  fi
  disk_dev=$base
fi

if [ -z "$disk_dev" ]; then
  log "disk: no device (set SYSMON_DISK_DEV or check DF_RAW)"
fi

# always emits: ok|miss <read_sectors> <write_sectors>
disk_counters=$(awk -v dev="$disk_dev" '
  BEGIN { if (dev == "") { print "miss 0 0"; exit } }
  $3 == dev { printf "ok %d %d\n", $6+0, $10+0; found=1; exit }
  END { if (!found) print "miss 0 0" }
' <<< "$disk_lines")
disk_cnt_status=$(awk '{ print $1 }' <<< "$disk_counters")
disk_read_sectors=$(awk '{ print $2 }' <<< "$disk_counters")
disk_write_sectors=$(awk '{ print $3 }' <<< "$disk_counters")
if [ -n "$disk_dev" ] && [ "$disk_cnt_status" != "ok" ]; then
  log "disk: dev='${disk_dev}' not in diskstats"
fi

# ── Net iface (env → default route → busiest non-lo → empty) ───────────────
net_iface="${SYSMON_NET_IF:-}"
net_rx_bytes=0
net_tx_bytes=0

if [ -z "$net_iface" ] && command -v ip >/dev/null; then
  net_iface=$(ip -o route show default \
    | awk '/default/ {
        for (i = 1; i <= NF; i++)
          if ($i == "dev") { print $(i+1); exit }
      }')
fi

if [ -z "$net_iface" ] && [ -n "$net_lines" ]; then
  net_iface=$(awk '
    NR > 2 {
      gsub(/:/, "", $1)
      if ($1 == "lo") next
      sum = $2+0 + $10+0
      if (sum > best) { best = sum; iface = $1 }
    }
    END { if (iface != "") print iface }
  ' <<< "$net_lines")
fi

if [ -z "$net_iface" ]; then
  log "net: no iface (set SYSMON_NET_IF or check default route / NET_RAW)"
fi

# always emits: ok|miss <rx> <tx>
net_counters=$(awk -v iface="$net_iface" '
  BEGIN { if (iface == "") { print "miss 0 0"; exit } }
  NR > 2 {
    gsub(/:/, "", $1)
    if ($1 == iface) { printf "ok %d %d\n", $2+0, $10+0; found=1; exit }
  }
  END { if (!found) print "miss 0 0" }
' <<< "$net_lines")
net_cnt_status=$(awk '{ print $1 }' <<< "$net_counters")
net_rx_bytes=$(awk '{ print $2 }' <<< "$net_counters")
net_tx_bytes=$(awk '{ print $3 }' <<< "$net_counters")
if [ -n "$net_iface" ] && [ "$net_cnt_status" != "ok" ]; then
  log "net: iface='${net_iface}' not in /proc/net/dev"
fi

# ── Rate state ─────────────────────────────────────────────────────────────
# always emits five numbers (missing/corrupt state → zeros)
prev_line="0 0 0 0 0"
if [ -f "$STATE_FILE" ]; then
  prev_line=$(awk '{
    printf "%s %d %d %d %d\n", $1+0, $2+0, $3+0, $4+0, $5+0
    exit
  }' "$STATE_FILE")
fi
prev_ts=$(awk '{ print $1 }' <<< "$prev_line")
prev_d_r=$(awk '{ print $2 }' <<< "$prev_line")
prev_d_w=$(awk '{ print $3 }' <<< "$prev_line")
prev_n_rx=$(awk '{ print $4 }' <<< "$prev_line")
prev_n_tx=$(awk '{ print $5 }' <<< "$prev_line")

current_ts=$(awk '{ print $2+0 }' <<< "${timestamp_line:-}")
if [ -z "$current_ts" ] || [ "$current_ts" = "0" ]; then
  current_ts=$(date +%s.%N)
  log "ts: TIMESTAMP missing — using date +%s.%N"
fi

# always emits: d_ok rs ws rx tx
rate_line=$(awk \
  -v ts="$current_ts" -v pts="$prev_ts" \
  -v dr="$disk_read_sectors" -v pdr="$prev_d_r" \
  -v dw="$disk_write_sectors" -v pdw="$prev_d_w" \
  -v nr="$net_rx_bytes" -v pnr="$prev_n_rx" \
  -v nt="$net_tx_bytes" -v pnt="$prev_n_tx" \
  'BEGIN {
    dt = ts - pts
    ok = (dt > 0.05 && pts > 0) ? 1 : 0
    r = w = rx = tx = 0
    if (ok) {
      r  = (dr - pdr) * 512 / dt; if (r  < 0) r  = 0
      w  = (dw - pdw) * 512 / dt; if (w  < 0) w  = 0
      rx = (nr - pnr) / dt;       if (rx < 0) rx = 0
      tx = (nt - pnt) / dt;       if (tx < 0) tx = 0
    }
    printf "%d %.0f %.0f %.0f %.0f\n", ok, r, w, rx, tx
  }')
delta_ok=$(awk '{ print $1 }' <<< "$rate_line")
disk_read_speed=$(awk '{ print $2 }' <<< "$rate_line")
disk_write_speed=$(awk '{ print $3 }' <<< "$rate_line")
net_rx_speed=$(awk '{ print $4 }' <<< "$rate_line")
net_tx_speed=$(awk '{ print $5 }' <<< "$rate_line")

log "disk=${disk_dev:-?} rs=${disk_read_speed} ws=${disk_write_speed} net=${net_iface:-?} rx=${net_rx_speed} tx=${net_tx_speed} d_ok=${delta_ok} raw_d=${disk_read_sectors}/${disk_write_sectors} raw_n=${net_rx_bytes}/${net_tx_bytes} dt=${current_ts}-${prev_ts}"

# ── GPU sysfs ──────────────────────────────────────────────────────────────
gpu_busy_pct=0 gpu_mem_used=0 gpu_mem_total=0
if [ -n "$gpu_lines" ]; then
  while IFS=' ' read -r path val; do
    [ -z "${path:-}" ] && continue
    case "$path" in
      *gpu_busy_percent) gpu_busy_pct=$((val + 0)) ;;
      *mem_info_vram_used) gpu_mem_used=$((val + 0)) ;;
      *mem_info_vram_total) gpu_mem_total=$((val + 0)) ;;
    esac
  done <<< "$gpu_lines"
fi

# ── Sensors ────────────────────────────────────────────────────────────────
gpu_re="${SYSMON_SENSORS_GPU_REGEX:-amdgpu}"
cpu_re="${SYSMON_SENSORS_CPU_REGEX:-k10temp|zenpower|coretemp}"
gpu_temp_c=0 gpu_freq=0 gpu_power=0 cpu_temp=0

if [ -n "$sensors_json" ]; then
  if jq empty <<< "$sensors_json" 2>>"$SYSMON_LOG"; then
    gpu_temp_c=$(jq --arg re "$gpu_re" '
      [to_entries[] | select(.key|test($re)) | .value]
      | .[0].edge.temp1_input // .[0].junction.temp1_input // 0 | floor
    ' <<< "$sensors_json") || gpu_temp_c=0

    gpu_freq=$(jq --arg re "$gpu_re" '
      [to_entries[] | select(.key|test($re)) | .value]
      | .[0].sclk.freq1_input // 0 | . / 1000000 | floor
    ' <<< "$sensors_json") || gpu_freq=0

    gpu_power=$(jq --arg re "$gpu_re" '
      [to_entries[] | select(.key|test($re)) | .value]
      | .[0].PPT.power1_average // .[0].power1.power1_average // 0
    ' <<< "$sensors_json") || gpu_power=0

    cpu_temp=$(jq --arg re "$cpu_re" '
      [to_entries[] | select(.key|test($re)) | .value]
      | .[0].Tctl.temp1_input // .[0].Tdie.temp1_input
        // .[0].temp1.temp1_input // 0
    ' <<< "$sensors_json") || cpu_temp=0
  else
    log "sensors: invalid JSON from collect"
  fi
fi
: "${gpu_temp_c:=0}" "${gpu_freq:=0}" "${gpu_power:=0}" "${cpu_temp:=0}"

# ── Fans ───────────────────────────────────────────────────────────────────
fan1=0 fan2=0
if [ -n "$fan_lines" ]; then
  idx=0
  while IFS=' ' read -r path val; do
    [ -z "${path:-}" ] && continue
    case "$path" in
      *fan*_input)
        if [ "$idx" -eq 0 ]; then fan1=$((val + 0))
        elif [ "$idx" -eq 1 ]; then fan2=$((val + 0))
        fi
        idx=$((idx + 1))
        ;;
    esac
  done <<< "$fan_lines"
  while IFS=' ' read -r path val; do
    case "$path" in
      *fan1_input) fan1=$((val + 0)) ;;
      *fan2_input) fan2=$((val + 0)) ;;
    esac
  done <<< "$fan_lines"
fi

# ── Emit JSON ──────────────────────────────────────────────────────────────
jq -n \
  --argjson ts "$current_ts" \
  --argjson cpu_avg "${cpu_avg:-0}" \
  --argjson cpu_per_core "${cpu_per_core:-[]}" \
  --argjson ram_used_kb "${ram_used_kb:-0}" \
  --argjson ram_total_kb "${ram_total_kb:-0}" \
  --argjson ram_avail_kb "${ram_avail_kb:-0}" \
  --argjson ram_used_pct "${ram_used_pct:-0}" \
  --argjson swap_used_kb "${swap_used_kb:-0}" \
  --argjson swap_total_kb "${swap_total_kb:-0}" \
  --argjson swap_pct "${swap_pct:-0}" \
  --arg disk_dev "$disk_dev" \
  --argjson disk_read_sectors "${disk_read_sectors:-0}" \
  --argjson disk_write_sectors "${disk_write_sectors:-0}" \
  --argjson disk_read_speed "${disk_read_speed:-0}" \
  --argjson disk_write_speed "${disk_write_speed:-0}" \
  --argjson disk_used_bytes "${disk_used_bytes:-0}" \
  --argjson disk_total_bytes "${disk_total_bytes:-0}" \
  --argjson disk_used_pct "${disk_used_pct:-0}" \
  --arg disk_used_human "$disk_used_human" \
  --arg disk_total_human "$disk_total_human" \
  --arg net_iface "$net_iface" \
  --argjson net_rx_bytes "${net_rx_bytes:-0}" \
  --argjson net_tx_bytes "${net_tx_bytes:-0}" \
  --argjson net_rx_speed "${net_rx_speed:-0}" \
  --argjson net_tx_speed "${net_tx_speed:-0}" \
  --argjson gpu_busy_pct "${gpu_busy_pct:-0}" \
  --argjson gpu_mem_used "${gpu_mem_used:-0}" \
  --argjson gpu_mem_total "${gpu_mem_total:-0}" \
  --argjson gpu_temp_c "${gpu_temp_c:-0}" \
  --argjson gpu_freq "${gpu_freq:-0}" \
  --argjson gpu_power "${gpu_power:-0}" \
  --argjson cpu_temp "${cpu_temp:-0}" \
  --argjson fan1 "${fan1:-0}" \
  --argjson fan2 "${fan2:-0}" \
  '{
    ts: $ts,
    cpu: { avg: $cpu_avg, per_core: $cpu_per_core },
    ram: {
      used_kb: $ram_used_kb, total_kb: $ram_total_kb, avail_kb: $ram_avail_kb,
      used_pct: $ram_used_pct,
      swap_used_kb: $swap_used_kb, swap_total_kb: $swap_total_kb, swap_pct: $swap_pct
    },
    disk: {
      dev: $disk_dev,
      read_sectors: $disk_read_sectors, write_sectors: $disk_write_sectors,
      read_speed: $disk_read_speed, write_speed: $disk_write_speed,
      used_bytes: $disk_used_bytes, total_bytes: $disk_total_bytes,
      used_pct: $disk_used_pct,
      used_human: $disk_used_human, total_human: $disk_total_human
    },
    net: {
      iface: $net_iface,
      rx_bytes: $net_rx_bytes, tx_bytes: $net_tx_bytes,
      rx_speed: $net_rx_speed, tx_speed: $net_tx_speed
    },
    gpu: {
      busy_pct: $gpu_busy_pct, mem_used: $gpu_mem_used, mem_total: $gpu_mem_total,
      temp_c: $gpu_temp_c, freq: $gpu_freq, power_w: $gpu_power
    },
    temp: { cpu_c: $cpu_temp, fan1: $fan1, fan2: $fan2 }
  }'

# persist counters only after successful JSON emit
printf '%s %s %s %s %s\n' \
  "$current_ts" "$disk_read_sectors" "$disk_write_sectors" "$net_rx_bytes" "$net_tx_bytes" \
  >"${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"
