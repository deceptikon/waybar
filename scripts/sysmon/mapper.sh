#!/usr/bin/env bash
set -euo pipefail
# sysmon-mapper.sh — Read sysmon raw data from stdin, emit JSON tree to stdout
# Usage: bash scripts/sysmon-raw3.sh | bash scripts/sysmon-mapper.sh

section=""
cpu1_lines=""
cpu2_lines=""
mem_lines=""
disk_lines=""
net_lines=""
sensors_json=""
gpu_lines=""
asus_line=""
fan_lines=""

while IFS= read -r line; do
  case "$line" in
    "CPU_SNAP_1") section="cpu1";   continue ;;
    "CPU_SNAP_2") section="cpu2";   continue ;;
    "MEM_RAW")    section="mem";    continue ;;
    "DISK_RAW")   section="disk";   continue ;;
    "NET_RAW")    section="net";    continue ;;
    "SENSORS_JSON") section="sensors"; continue ;;
    "GPU_RAW")    section="gpu";    continue ;;
    "ASUS_PROFILE") section="asus"; continue ;;
    "FAN_RAW")    section="fan";    continue ;;
  esac
  case "$section" in
    cpu1)     cpu1_lines+="$line"$'\n' ;;
    cpu2)     cpu2_lines+="$line"$'\n' ;;
    mem)      mem_lines+="$line"$'\n' ;;
    disk)     disk_lines+="$line"$'\n' ;;
    net)      net_lines+="$line"$'\n' ;;
    sensors)  sensors_json+="$line" ;;
    gpu)      gpu_lines+="$line"$'\n' ;;
    asus)     asus_line+="$line"$'\n' ;;
    fan)      fan_lines+="$line"$'\n' ;;
  esac
done

# ── CPU — delta between two /proc/stat snaps ──
cpu_avg=0; cpu_per_core="[]"
if [ -n "$cpu1_lines" ] && [ -n "$cpu2_lines" ]; then
  data=$(awk '
    FNR==NR { tot1[$1]=$2+$3+$4+$5+$6+$7+$8; idle1[$1]=$5; next }
    /^cpu[0-9]+ / {
      n=$1; dt=$2+$3+$4+$5+$6+$7+$8-tot1[n]; di=$5-idle1[n];
      if (dt<=0) dt=1;
      p=int((dt-di)*100/dt);
      if (p<0) p=0; if (p>100) p=100;
      printf "core %d\n", p;
      sum+=p; cnt++;
    }
    END { if (cnt>0) printf "avg %d\n", int(sum/cnt); else printf "avg 0\n" }
  ' <(printf '%s' "$cpu1_lines") <(printf '%s' "$cpu2_lines"))
  cpu_avg=$(awk '/^avg /{print $2}' <<< "$data")
  cpu_per_core=$(awk '/^core /{print $2}' <<< "$data" | jq -Rs 'split("\n") | map(select(length>0) | tonumber)')
  : "${cpu_avg:=0}"; : "${cpu_per_core:=[]}"
fi

# ── RAM (/proc/meminfo) ──
ram_used_kb=0; ram_total_kb=0; ram_avail_kb=0; ram_used_pct=0; swap_used_kb=0; swap_total_kb=0; swap_pct=0
if [ -n "$mem_lines" ]; then
  ram_total_kb=$(awk '/^MemTotal:/{print $2}' <<< "$mem_lines")
  ram_avail_kb=$(awk '/^MemAvailable:/{print $2}' <<< "$mem_lines")
  ram_used_kb=$((ram_total_kb - ram_avail_kb))
  [ "$ram_total_kb" -gt 0 ] && ram_used_pct=$((ram_used_kb * 100 / ram_total_kb))
  swap_total_kb=$(awk '/^SwapTotal:/{print $2}' <<< "$mem_lines")
  swap_free_kb=$(awk '/^SwapFree:/{print $2}' <<< "$mem_lines")
  swap_used_kb=$((swap_total_kb - swap_free_kb))
  [ "$swap_total_kb" -gt 0 ] && swap_pct=$((swap_used_kb * 100 / swap_total_kb))
fi

# ── Disk (/proc/diskstats) — cumulative sectors ──
disk_read_sectors=0; disk_write_sectors=0
if [ -n "$disk_lines" ]; then
  read -r disk_read_sectors disk_write_sectors <<< "$(awk '$3 == "nvme0n1" {print $6+0, $10+0}' <<< "$disk_lines")"
fi

# ── Net (/proc/net/dev) — cumulative bytes ──
net_rx_bytes=0; net_tx_bytes=0
if [ -n "$net_lines" ]; then
  read -r net_rx_bytes net_tx_bytes <<< "$(awk '/wlp98s0:/{print $2+0, $10+0}' <<< "$net_lines")"
fi

# ── GPU sysfs ──
gpu_busy_pct=0; gpu_mem_used=0; gpu_mem_total=0
if [ -n "$gpu_lines" ]; then
  while IFS=' ' read -r path val; do
    case "$path" in
      *gpu_busy_percent)  gpu_busy_pct=$((val+0)) ;;
      *mem_info_vram_used)  gpu_mem_used=$((val+0)) ;;
      *mem_info_vram_total) gpu_mem_total=$((val+0)) ;;
    esac
  done <<< "$gpu_lines"
fi

# ── Sensors JSON ──
gpu_temp_c=0; gpu_freq=0; gpu_power=0; cpu_temp=0
if [ -n "$sensors_json" ]; then
  gpu_temp_c=$(jq '.["amdgpu-pci-6300"].edge.temp1_input // 0 | floor' <<< "$sensors_json" 2>/dev/null)
  gpu_freq=$(jq '.["amdgpu-pci-6300"].sclk.freq1_input // 0 | . / 1000000 | floor' <<< "$sensors_json" 2>/dev/null)
  gpu_power=$(jq '.["amdgpu-pci-6300"].PPT.power1_average // 0' <<< "$sensors_json" 2>/dev/null)
  cpu_temp=$(jq '.["k10temp-pci-00c3"].Tctl.temp1_input // 0' <<< "$sensors_json" 2>/dev/null)
fi

# ── Fan ──
fan1=0; fan2=0
if [ -n "$fan_lines" ]; then
  while IFS=' ' read -r path val; do
    case "$path" in
      *fan1_input) fan1=$((val+0)) ;;
      *fan2_input) fan2=$((val+0)) ;;
    esac
  done <<< "$fan_lines"
fi

# ── ASUS profile ──
asus_profile="unknown"
if [ -n "$asus_line" ]; then
  asus_profile=$(awk -F': ' '/Active profile:/{print $2}' <<< "$asus_line" | head -1)
  [ -z "$asus_profile" ] && asus_profile="unknown"
fi

# ── Emit JSON ──
jq -n \
  --argjson ts "$(date +%s)" \
  --argjson cpu_avg "${cpu_avg:-0}" \
  --argjson cpu_per_core "${cpu_per_core:-[]}" \
  --argjson ram_used_kb "${ram_used_kb:-0}" \
  --argjson ram_total_kb "${ram_total_kb:-0}" \
  --argjson ram_avail_kb "${ram_avail_kb:-0}" \
  --argjson ram_used_pct "${ram_used_pct:-0}" \
  --argjson swap_used_kb "${swap_used_kb:-0}" \
  --argjson swap_total_kb "${swap_total_kb:-0}" \
  --argjson swap_pct "${swap_pct:-0}" \
  --argjson disk_read_sectors "${disk_read_sectors:-0}" \
  --argjson disk_write_sectors "${disk_write_sectors:-0}" \
  --argjson net_rx_bytes "${net_rx_bytes:-0}" \
  --argjson net_tx_bytes "${net_tx_bytes:-0}" \
  --argjson gpu_busy_pct "${gpu_busy_pct:-0}" \
  --argjson gpu_mem_used "${gpu_mem_used:-0}" \
  --argjson gpu_mem_total "${gpu_mem_total:-0}" \
  --argjson gpu_temp_c "${gpu_temp_c:-0}" \
  --argjson gpu_freq "${gpu_freq:-0}" \
  --argjson gpu_power "${gpu_power:-0}" \
  --argjson cpu_temp "${cpu_temp:-0}" \
  --argjson fan1 "${fan1:-0}" \
  --argjson fan2 "${fan2:-0}" \
  --arg asus_profile "${asus_profile:-unknown}" \
  '{
    ts: $ts,
    cpu: { avg: $cpu_avg, per_core: $cpu_per_core },
    ram: { used_kb: $ram_used_kb, total_kb: $ram_total_kb, avail_kb: $ram_avail_kb, used_pct: $ram_used_pct, swap_used_kb: $swap_used_kb, swap_total_kb: $swap_total_kb, swap_pct: $swap_pct },
    disk: { read_sectors: $disk_read_sectors, write_sectors: $disk_write_sectors },
    net: { rx_bytes: $net_rx_bytes, tx_bytes: $net_tx_bytes },
    gpu: { busy_pct: $gpu_busy_pct, mem_used: $gpu_mem_used, mem_total: $gpu_mem_total, temp_c: $gpu_temp_c, freq: $gpu_freq, power_w: $gpu_power },
    temp: { cpu_c: $cpu_temp, fan1: $fan1, fan2: $fan2 },
    asus: { profile: $asus_profile }
  }'
