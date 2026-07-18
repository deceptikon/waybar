#!/usr/bin/env bash
# mapper.sh — stdin (collect sections) → unified sysmon JSON on stdout
# Side effect: updates rate state file under feeds/.state
set -euo pipefail
export LC_ALL=C

FEEDS="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/feeds"
ENV_FILE="$(cd "$(dirname "$0")" && pwd)/sysmon.env"
mkdir -p "$FEEDS"

# shellcheck source=/dev/null
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

section=""
cpu1_lines="" cpu2_lines="" mem_lines="" disk_lines="" df_lines=""
net_lines="" sensors_json="" gpu_lines="" fan_lines="" timestamp_line=""

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    TIMESTAMP*)     timestamp_line="$line"; section=""; continue ;;
    "CPU_SNAP_1")   section="cpu1";     continue ;;
    "CPU_SNAP_2")   section="cpu2";     continue ;;
    "MEM_RAW")      section="mem";      continue ;;
    "DISK_RAW")     section="disk";     continue ;;
    "DF_RAW")       section="df";       continue ;;
    "NET_RAW")      section="net";      continue ;;
    "SENSORS_JSON") section="sensors";  continue ;;
    "GPU_RAW")      section="gpu";      continue ;;
    "FAN_RAW")      section="fan";      continue ;;
    # ignore unknown headers / legacy sections
    "SWAP_RAW"|"ASUS_PROFILE"|"WORKSPACE_RAW") section="skip"; continue ;;
  esac
  case "$section" in
    cpu1)    cpu1_lines+="$line"$'\n' ;;
    cpu2)    cpu2_lines+="$line"$'\n' ;;
    mem)     mem_lines+="$line"$'\n' ;;
    disk)    disk_lines+="$line"$'\n' ;;
    df)      df_lines+="$line"$'\n' ;;
    net)     net_lines+="$line"$'\n' ;;
    sensors) sensors_json+="$line" ;;
    gpu)     gpu_lines+="$line"$'\n' ;;
    fan)     fan_lines+="$line"$'\n' ;;
    skip|"") ;;
  esac
done

# ── CPU delta ──────────────────────────────────────────────────────────────
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
  cpu_avg=$(awk '/^avg /{print $2}' <<< "$data")
  cpu_per_core=$(awk '/^core /{print $2}' <<< "$data" | jq -Rs 'split("\n")|map(select(length>0)|tonumber)')
fi
: "${cpu_avg:=0}"
: "${cpu_per_core:=[]}"

# ── RAM ────────────────────────────────────────────────────────────────────
ram_used_kb=0 ram_total_kb=0 ram_avail_kb=0 ram_used_pct=0
swap_used_kb=0 swap_total_kb=0 swap_pct=0
if [ -n "$mem_lines" ]; then
  ram_total_kb=$(awk '/^MemTotal:/{print $2+0}' <<< "$mem_lines")
  ram_avail_kb=$(awk '/^MemAvailable:/{print $2+0}' <<< "$mem_lines")
  ram_used_kb=$((ram_total_kb - ram_avail_kb))
  [ "$ram_total_kb" -gt 0 ] && ram_used_pct=$((ram_used_kb * 100 / ram_total_kb))
  swap_total_kb=$(awk '/^SwapTotal:/{print $2+0}' <<< "$mem_lines")
  swap_free_kb=$(awk '/^SwapFree:/{print $2+0}' <<< "$mem_lines")
  swap_used_kb=$((swap_total_kb - swap_free_kb))
  [ "$swap_total_kb" -gt 0 ] && swap_pct=$((swap_used_kb * 100 / swap_total_kb))
fi

# ── DF + disk device autodetect ────────────────────────────────────────────
disk_used_bytes=0 disk_total_bytes=0 disk_used_pct=0
disk_used_human="0G" disk_total_human="0G"
disk_dev="${SYSMON_DISK_DEV:-}"

human_bytes() {
  awk -v u="$1" 'BEGIN{
    if (u>=1099511627776) printf "%.1fT", u/1099511627776
    else if (u>=1073741824) printf "%.1fG", u/1073741824
    else if (u>=1048576) printf "%.0fM", u/1048576
    else if (u>=1024) printf "%.0fK", u/1024
    else printf "%dB", u
  }'
}

if [ -n "$df_lines" ]; then
  # df -B1 -P: Filesystem 1B-blocks Used Available Capacity Mounted
  read -r fs blocks used _av cap _mnt <<< "$(awk 'NR==2 {
    gsub(/%/,"",$5)
    print $1, $2+0, $3+0, $4+0, $5+0, $6
  }' <<< "$df_lines")"
  disk_total_bytes=${blocks:-0}
  disk_used_bytes=${used:-0}
  disk_used_pct=${cap:-0}
  disk_used_human=$(human_bytes "$disk_used_bytes")
  disk_total_human=$(human_bytes "$disk_total_bytes")

  if [ -z "$disk_dev" ] && [ -n "${fs:-}" ]; then
    base=$(basename "$fs")
    # partition → parent disk (nvme0n1p2 → nvme0n1, sda1 → sda)
    if command -v lsblk >/dev/null 2>&1 && [ -b "$fs" ]; then
      pk=$(lsblk -no PKNAME "$fs" 2>>/tmp/waybar_errors.log | head -1 | tr -d '[:space:]')
      [ -n "$pk" ] && base=$pk
    else
      base=$(echo "$base" | sed -E 's/p?[0-9]+$//')
    fi
    disk_dev=$base
  fi
fi
: "${disk_dev:=nvme0n1}"

disk_read_sectors=0 disk_write_sectors=0
if [ -n "$disk_lines" ]; then
  read -r disk_read_sectors disk_write_sectors <<< "$(
    awk -v dev="$disk_dev" '$3==dev {print $6+0, $10+0; exit}' <<< "$disk_lines"
  )"
fi
: "${disk_read_sectors:=0}"
: "${disk_write_sectors:=0}"

# ── Net iface autodetect ───────────────────────────────────────────────────
net_iface="${SYSMON_NET_IF:-}"
net_rx_bytes=0 net_tx_bytes=0
if [ -n "$net_lines" ]; then
  if [ -z "$net_iface" ]; then
    net_iface=$(awk '
      NR>2 {
        gsub(/:/,"",$1)
        if ($1=="lo") next
        rx=$2+0; tx=$10+0; sum=rx+tx
        if (sum > best) { best=sum; iface=$1 }
      }
      END { if (iface!="") print iface }
    ' <<< "$net_lines")
  fi
  : "${net_iface:=wlan0}"
  read -r net_rx_bytes net_tx_bytes <<< "$(
    awk -v iface="$net_iface" '
      NR>2 {
        gsub(/:/,"",$1)
        if ($1==iface) { print $2+0, $10+0; exit }
      }
    ' <<< "$net_lines"
  )"
fi
: "${net_rx_bytes:=0}"
: "${net_tx_bytes:=0}"
: "${net_iface:=wlan0}"

# ── Rates from previous state ──────────────────────────────────────────────
state_file="$FEEDS/.state"
prev_ts=0 prev_d_r=0 prev_d_w=0 prev_n_rx=0 prev_n_tx=0
if [ -f "$state_file" ]; then
  read -r prev_ts prev_d_r prev_d_w prev_n_rx prev_n_tx < "$state_file" || true
fi
: "${prev_ts:=0}" "${prev_d_r:=0}" "${prev_d_w:=0}" "${prev_n_rx:=0}" "${prev_n_tx:=0}"

current_ts=$(awk '{print $2+0}' <<< "${timestamp_line:-}")
if [ -z "$current_ts" ] || [ "$current_ts" = "0" ]; then
  current_ts=$(date +%s.%N)
fi

disk_read_speed=0 disk_write_speed=0 net_rx_speed=0 net_tx_speed=0
delta_ok=$(awk -v dt="$current_ts" -v pt="$prev_ts" 'BEGIN{
  d=dt-pt; print (d>0.05 && pt>0)?1:0
}')
if [ "$delta_ok" = "1" ]; then
  read -r disk_read_speed disk_write_speed net_rx_speed net_tx_speed <<< "$(
    awk -v ts="$current_ts" -v pts="$prev_ts" \
        -v dr="$disk_read_sectors" -v pdr="$prev_d_r" \
        -v dw="$disk_write_sectors" -v pdw="$prev_d_w" \
        -v nr="$net_rx_bytes" -v pnr="$prev_n_rx" \
        -v nt="$net_tx_bytes" -v pnt="$prev_n_tx" 'BEGIN{
      dt=ts-pts
      r=(dr-pdr)*512/dt; if(r<0)r=0
      w=(dw-pdw)*512/dt; if(w<0)w=0
      rx=(nr-pnr)/dt; if(rx<0)rx=0
      tx=(nt-pnt)/dt; if(tx<0)tx=0
      printf "%.0f %.0f %.0f %.0f\n", r,w,rx,tx
    }'
  )"
fi

# ── GPU sysfs ──────────────────────────────────────────────────────────────
gpu_busy_pct=0 gpu_mem_used=0 gpu_mem_total=0
if [ -n "$gpu_lines" ]; then
  while IFS=' ' read -r path val; do
    [ -z "${path:-}" ] && continue
    case "$path" in
      *gpu_busy_percent)   gpu_busy_pct=$((val+0)) ;;
      *mem_info_vram_used) gpu_mem_used=$((val+0)) ;;
      *mem_info_vram_total) gpu_mem_total=$((val+0)) ;;
    esac
  done <<< "$gpu_lines"
fi

# ── Sensors ────────────────────────────────────────────────────────────────
gpu_re="${SYSMON_SENSORS_GPU_REGEX:-amdgpu}"
cpu_re="${SYSMON_SENSORS_CPU_REGEX:-k10temp|zenpower|coretemp}"
gpu_temp_c=0 gpu_freq=0 gpu_power=0 cpu_temp=0

if [ -n "$sensors_json" ] && jq -e . >/dev/null 2>&1 <<< "$sensors_json"; then
  gpu_temp_c=$(jq --arg re "$gpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].edge.temp1_input // .[0].junction.temp1_input // 0 | floor
  ' <<< "$sensors_json" 2>>/tmp/waybar_errors.log || echo 0)
  gpu_freq=$(jq --arg re "$gpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].sclk.freq1_input // 0 | . / 1000000 | floor
  ' <<< "$sensors_json" 2>>/tmp/waybar_errors.log || echo 0)
  gpu_power=$(jq --arg re "$gpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].PPT.power1_average // .[0].power1.power1_average // 0
  ' <<< "$sensors_json" 2>>/tmp/waybar_errors.log || echo 0)
  cpu_temp=$(jq --arg re "$cpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].Tctl.temp1_input // .[0].Tdie.temp1_input
      // .[0].temp1.temp1_input // 0
  ' <<< "$sensors_json" 2>>/tmp/waybar_errors.log || echo 0)
fi
: "${gpu_temp_c:=0}" "${gpu_freq:=0}" "${gpu_power:=0}" "${cpu_temp:=0}"

# ── Fans ───────────────────────────────────────────────────────────────────
fan1=0 fan2=0
if [ -n "$fan_lines" ]; then
  # take first two fan*_input values in path order
  idx=0
  while IFS=' ' read -r path val; do
    [ -z "${path:-}" ] && continue
    case "$path" in
      *fan*_input)
        if [ "$idx" -eq 0 ]; then fan1=$((val+0))
        elif [ "$idx" -eq 1 ]; then fan2=$((val+0)); fi
        idx=$((idx+1))
        ;;
    esac
  done <<< "$fan_lines"
  # named preference if present
  while IFS=' ' read -r path val; do
    case "$path" in
      *fan1_input) fan1=$((val+0)) ;;
      *fan2_input) fan2=$((val+0)) ;;
    esac
  done <<< "$fan_lines"
fi

# ── Emit JSON (stdout only) ────────────────────────────────────────────────
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

# persist counters for next rate sample (after successful emit)
printf '%s %s %s %s %s\n' \
  "$current_ts" "$disk_read_sectors" "$disk_write_sectors" "$net_rx_bytes" "$net_tx_bytes" \
  > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
