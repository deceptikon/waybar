#!/usr/bin/env bash
# mapper.sh — stdin (collect sections) → sysmon JSON on stdout
# Side effect: $FEEDS/.state for disk/net rates
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
[ -f "$DIR/sysmon.env" ] && . "$DIR/sysmon.env"

FEEDS="${SYSMON_FEEDS:-$CFG_HOME/feeds}"
LOG_DIR="${SYSMON_LOG_DIR:-$CFG_HOME/logs}"
mkdir -p "$FEEDS" "$LOG_DIR"
LOG="$LOG_DIR/sysmon.log"
log() { printf '%s mapper: %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

num() { awk -v v="${1:-0}" 'BEGIN{printf "%s", (v+0)}'; }

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
  ) || data="avg 0"
  cpu_avg=$(awk '/^avg /{print $2}' <<< "$data")
  cpu_per_core=$(awk '/^core /{print $2}' <<< "$data" \
    | jq -Rs 'split("\n")|map(select(length>0)|tonumber)' 2>/dev/null || echo '[]')
fi
cpu_avg=${cpu_avg:-0}
cpu_per_core=${cpu_per_core:-[]}

# ── RAM ────────────────────────────────────────────────────────────────────
ram_used_kb=0 ram_total_kb=0 ram_avail_kb=0 ram_used_pct=0
swap_used_kb=0 swap_total_kb=0 swap_pct=0
if [ -n "$mem_lines" ]; then
  ram_total_kb=$(awk '/^MemTotal:/{print $2+0}' <<< "$mem_lines")
  ram_avail_kb=$(awk '/^MemAvailable:/{print $2+0}' <<< "$mem_lines")
  ram_total_kb=${ram_total_kb:-0}
  ram_avail_kb=${ram_avail_kb:-0}
  ram_used_kb=$((ram_total_kb - ram_avail_kb))
  [ "$ram_used_kb" -lt 0 ] && ram_used_kb=0
  [ "$ram_total_kb" -gt 0 ] && ram_used_pct=$((ram_used_kb * 100 / ram_total_kb))
  swap_total_kb=$(awk '/^SwapTotal:/{print $2+0}' <<< "$mem_lines")
  swap_free_kb=$(awk '/^SwapFree:/{print $2+0}' <<< "$mem_lines")
  swap_total_kb=${swap_total_kb:-0}
  swap_free_kb=${swap_free_kb:-0}
  swap_used_kb=$((swap_total_kb - swap_free_kb))
  [ "$swap_used_kb" -lt 0 ] && swap_used_kb=0
  [ "$swap_total_kb" -gt 0 ] && swap_pct=$((swap_used_kb * 100 / swap_total_kb))
fi

# ── DF ─────────────────────────────────────────────────────────────────────
disk_used_bytes=0 disk_total_bytes=0 disk_used_pct=0
disk_used_human="0G" disk_total_human="0G"
disk_dev="${SYSMON_DISK_DEV:-}"
df_fs=""

human_bytes() {
  awk -v u="${1:-0}" 'BEGIN{
    if (u>=1099511627776) printf "%.1fT", u/1099511627776
    else if (u>=1073741824) printf "%.1fG", u/1073741824
    else if (u>=1048576)    printf "%.0fM", u/1048576
    else if (u>=1024)       printf "%.0fK", u/1024
    else                    printf "%dB", u+0
  }'
}

if [ -n "$df_lines" ]; then
  df_line=$(awk 'NR==2 {
    gsub(/%/,"",$5)
    printf "%s %s %s %s\n", $1, $2+0, $3+0, $5+0
  }' <<< "$df_lines" 2>/dev/null || true)
  if [ -n "$df_line" ]; then
    read -r df_fs blocks used cap <<<"$df_line" || true
    disk_total_bytes=${blocks:-0}
    disk_used_bytes=${used:-0}
    disk_used_pct=${cap:-0}
  fi
  case "$disk_used_pct" in ''|*[!0-9]*) disk_used_pct=0 ;; esac
  [ "$disk_used_pct" -gt 100 ] 2>/dev/null && disk_used_pct=100
  disk_used_human=$(human_bytes "$disk_used_bytes")
  disk_total_human=$(human_bytes "$disk_total_bytes")
fi

# ── Disk device for /proc/diskstats ────────────────────────────────────────
# Prefer SYSMON_DISK_DEV; else map df source → diskstats name; else busiest whole-disk.
pick_disk_dev() {
  local want="$1" fs="$2" lines="$3" cand="" base pk

  if [ -n "$want" ]; then
    if awk -v d="$want" '$3==d {found=1} END{exit !found}' <<< "$lines"; then
      echo "$want"
      return
    fi
  fi

  if [ -n "$fs" ]; then
    base=$(basename "$fs")
    # exact name in diskstats (dm-0, nvme0n1p2, sda1, …)
    if awk -v d="$base" '$3==d {found=1} END{exit !found}' <<< "$lines"; then
      echo "$base"
      return
    fi
    # parent disk via lsblk
    if command -v lsblk >/dev/null 2>&1; then
      if [ -b "$fs" ]; then
        pk=$(lsblk -no PKNAME "$fs" 2>/dev/null | head -1 | tr -d '[:space:]' || true)
        [ -z "$pk" ] && pk=$(lsblk -no PKNAME "$base" 2>/dev/null | head -1 | tr -d '[:space:]' || true)
        if [ -n "$pk" ] && awk -v d="$pk" '$3==d {found=1} END{exit !found}' <<< "$lines"; then
          echo "$pk"
          return
        fi
      fi
      # mapper/luks → backing disk
      pk=$(lsblk -no PKNAME,NAME,TYPE 2>/dev/null \
        | awk -v n="$base" '$2==n || $2==n {print $1; exit}' || true)
      # walk up: NAME that matches, get top disk
      pk=$(lsblk -ndo NAME,TYPE 2>/dev/null | awk -v n="$base" '
        $1==n { hit=1 }
      ' || true)
      top=$(lsblk -npslo NAME,TYPE "$fs" 2>/dev/null \
        | awk '$2=="disk"{print $1; exit}' || true)
      top=$(basename "${top:-}")
      if [ -n "$top" ] && awk -v d="$top" '$3==d {found=1} END{exit !found}' <<< "$lines"; then
        echo "$top"
        return
      fi
    fi
    # strip partition suffix
    cand=$(echo "$base" | sed -E 's/p?[0-9]+$//')
    if [ -n "$cand" ] && awk -v d="$cand" '$3==d {found=1} END{exit !found}' <<< "$lines"; then
      echo "$cand"
      return
    fi
  fi

  # busiest whole-disk (skip ram/loop/dm/partitions heuristically)
  awk '
    {
      name=$3
      if (name ~ /^(loop|ram|fd)/) next
      # prefer whole disks: nvme0n1, sda, vda — not nvme0n1p1 / sda1
      if (name ~ /nvme[0-9]+n[0-9]+p[0-9]+$/) next
      if (name ~ /[a-z]+[0-9]+$/ && name !~ /nvme/) next
      io=$6+$10
      if (io >= best) { best=io; pick=name }
    }
    END { if (pick!="") print pick }
  ' <<< "$lines"
}

disk_dev=$(pick_disk_dev "$disk_dev" "${df_fs:-}" "$disk_lines")
disk_dev=${disk_dev:-nvme0n1}

disk_read_sectors=0 disk_write_sectors=0
if [ -n "$disk_lines" ]; then
  dline=$(awk -v dev="$disk_dev" '$3==dev {print $6+0, $10+0; exit}' <<< "$disk_lines" || true)
  if [ -n "$dline" ]; then
    read -r disk_read_sectors disk_write_sectors <<<"$dline" || true
  fi
fi
disk_read_sectors=${disk_read_sectors:-0}
disk_write_sectors=${disk_write_sectors:-0}

# ── Net iface ──────────────────────────────────────────────────────────────
# Prefer SYSMON_NET_IF → default route → operstate up with max traffic → life max
net_iface="${SYSMON_NET_IF:-}"
net_rx_bytes=0 net_tx_bytes=0

pick_net_iface() {
  local want="$1" lines="$2" r=""
  if [ -n "$want" ]; then
    if awk -v i="$want" 'NR>2 {gsub(/:/,"",$1); if($1==i) f=1} END{exit !f}' <<< "$lines"; then
      echo "$want"
      return
    fi
  fi
  # default route
  r=$(ip -4 route show default 2>/dev/null | awk '/default/ {for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}' || true)
  if [ -n "$r" ] && awk -v i="$r" 'NR>2 {gsub(/:/,"",$1); if($1==i) f=1} END{exit !f}' <<< "$lines"; then
    echo "$r"
    return
  fi
  # interfaces with carrier / operstate up
  r=$(awk '
    NR>2 {
      gsub(/:/,"",$1)
      if ($1=="lo") next
      print $1, $2+0, $10+0
    }
  ' <<< "$lines" | while read -r ifc rx tx; do
      st=""
      [ -r "/sys/class/net/$ifc/operstate" ] && st=$(cat "/sys/class/net/$ifc/operstate" 2>/dev/null || true)
      [ "$st" = "up" ] || continue
      echo "$((rx+tx)) $ifc"
    done | sort -nr | head -1 | awk '{print $2}')
  if [ -n "$r" ]; then
    echo "$r"
    return
  fi
  # lifetime max traffic
  awk '
    NR>2 {
      gsub(/:/,"",$1)
      if ($1=="lo") next
      s=$2+$10
      if (s>best) { best=s; iface=$1 }
    }
    END { if (iface!="") print iface }
  ' <<< "$lines"
}

if [ -n "$net_lines" ]; then
  net_iface=$(pick_net_iface "$net_iface" "$net_lines")
  net_iface=${net_iface:-wlan0}
  nline=$(awk -v iface="$net_iface" '
    NR>2 {
      gsub(/:/,"",$1)
      if ($1==iface) { print $2+0, $10+0; exit }
    }
  ' <<< "$net_lines" || true)
  if [ -n "$nline" ]; then
    read -r net_rx_bytes net_tx_bytes <<<"$nline" || true
  fi
fi
net_rx_bytes=${net_rx_bytes:-0}
net_tx_bytes=${net_tx_bytes:-0}
net_iface=${net_iface:-wlan0}

# ── Rates (need previous .state) ───────────────────────────────────────────
state_file="$FEEDS/.state"
prev_ts=0 prev_d_r=0 prev_d_w=0 prev_n_rx=0 prev_n_tx=0 prev_disk="" prev_if=""
if [ -f "$state_file" ]; then
  # ts dr dw nrx ntx [disk_dev] [net_iface]
  read -r prev_ts prev_d_r prev_d_w prev_n_rx prev_n_tx prev_disk prev_if <"$state_file" || true
fi
prev_ts=${prev_ts:-0}
prev_d_r=${prev_d_r:-0}
prev_d_w=${prev_d_w:-0}
prev_n_rx=${prev_n_rx:-0}
prev_n_tx=${prev_n_tx:-0}

current_ts=$(awk '{print $2+0}' <<< "${timestamp_line:-}" 2>/dev/null || true)
if [ -z "${current_ts:-}" ] || [ "$current_ts" = "0" ]; then
  current_ts=$(date +%s.%N)
fi

disk_read_speed=0 disk_write_speed=0 net_rx_speed=0 net_tx_speed=0

# reset baselines if device/iface changed (avoid huge bogus spikes)
if [ -n "${prev_disk:-}" ] && [ "$prev_disk" != "$disk_dev" ]; then
  prev_d_r=0; prev_d_w=0; prev_ts=0
fi
if [ -n "${prev_if:-}" ] && [ "$prev_if" != "$net_iface" ]; then
  prev_n_rx=0; prev_n_tx=0; prev_ts=0
fi

delta_ok=$(awk -v dt="$current_ts" -v pt="$prev_ts" 'BEGIN{
  d=dt-pt; print (d>0.2 && pt+0>0)?1:0
}')
if [ "$delta_ok" = "1" ]; then
  rates=$(awk -v ts="$current_ts" -v pts="$prev_ts" \
    -v dr="$disk_read_sectors" -v pdr="$prev_d_r" \
    -v dw="$disk_write_sectors" -v pdw="$prev_d_w" \
    -v nr="$net_rx_bytes" -v pnr="$prev_n_rx" \
    -v nt="$net_tx_bytes" -v pnt="$prev_n_tx" 'BEGIN{
      dt=ts-pts
      if (dt < 0.2) dt=0.2
      r=(dr-pdr)*512.0/dt; if(r<0) r=0
      w=(dw-pdw)*512.0/dt; if(w<0) w=0
      rx=(nr-pnr)*1.0/dt;   if(rx<0) rx=0
      tx=(nt-pnt)*1.0/dt;   if(tx<0) tx=0
      printf "%.0f %.0f %.0f %.0f\n", r, w, rx, tx
    }' 2>/dev/null || true)
  if [ -n "${rates:-}" ]; then
    read -r disk_read_speed disk_write_speed net_rx_speed net_tx_speed <<<"$rates" || true
  fi
fi
disk_read_speed=${disk_read_speed:-0}
disk_write_speed=${disk_write_speed:-0}
net_rx_speed=${net_rx_speed:-0}
net_tx_speed=${net_tx_speed:-0}

# ── GPU sysfs ──────────────────────────────────────────────────────────────
gpu_busy_pct=0 gpu_mem_used=0 gpu_mem_total=0
if [ -n "$gpu_lines" ]; then
  while IFS=' ' read -r path val || [ -n "${path:-}" ]; do
    [ -z "${path:-}" ] && continue
    val=${val:-0}
    case "$path" in
      *gpu_busy_percent)    gpu_busy_pct=$((val+0)) ;;
      *mem_info_vram_used)  gpu_mem_used=$((val+0)) ;;
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
  ' <<< "$sensors_json" 2>>"$LOG" || echo 0)
  gpu_freq=$(jq --arg re "$gpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].sclk.freq1_input // 0 | . / 1000000 | floor
  ' <<< "$sensors_json" 2>>"$LOG" || echo 0)
  gpu_power=$(jq --arg re "$gpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].PPT.power1_average // .[0].power1.power1_average // 0
  ' <<< "$sensors_json" 2>>"$LOG" || echo 0)
  cpu_temp=$(jq --arg re "$cpu_re" '
    [to_entries[] | select(.key|test($re)) | .value]
    | .[0].Tctl.temp1_input // .[0].Tdie.temp1_input
      // .[0].temp1.temp1_input // 0
  ' <<< "$sensors_json" 2>>"$LOG" || echo 0)
fi
gpu_temp_c=${gpu_temp_c:-0}
gpu_freq=${gpu_freq:-0}
gpu_power=${gpu_power:-0}
cpu_temp=${cpu_temp:-0}

# ── Fans ───────────────────────────────────────────────────────────────────
fan1=0 fan2=0
if [ -n "$fan_lines" ]; then
  while IFS=' ' read -r path val || [ -n "${path:-}" ]; do
    [ -z "${path:-}" ] && continue
    val=${val:-0}
    case "$path" in
      *fan1_input) fan1=$((val+0)) ;;
      *fan2_input) fan2=$((val+0)) ;;
    esac
  done <<< "$fan_lines"
  if [ "$fan1" -eq 0 ] && [ "$fan2" -eq 0 ]; then
    idx=0
    while IFS=' ' read -r path val || [ -n "${path:-}" ]; do
      [ -z "${path:-}" ] && continue
      case "$path" in
        *fan*_input)
          val=${val:-0}
          if [ "$idx" -eq 0 ]; then fan1=$((val+0))
          elif [ "$idx" -eq 1 ]; then fan2=$((val+0)); fi
          idx=$((idx+1))
          ;;
      esacOR
    done <<< "$fan_lines"
  fi
fi

# ── Emit ───────────────────────────────────────────────────────────────────
if ! jq -n \
  --argjson ts "$(num "$current_ts")" \
  --argjson cpu_avg "$(num "$cpu_avg")" \
  --argjson cpu_per_core "${cpu_per_core}" \
  --argjson Island_used_kb "$(num "$ram_used_kb")" \
  --argjson ram_used_kb "$(num "$ram_used_kb")" \
  --argjson ram_total_kb "$(num "$ram_total_kb")" \
  --argjson ram_avail_kb "$(num "$ram_avail_kb")" \
  --argjson ram_used_pct "$(num "$ram_used_pct")" \
  --argjson swap_used_kb "$(num "$swap_used_kb")" \
  --argjson swap_total_kb "$(num "$swap_total_kb")" \
  --argjson swap_pct "$(num "$swap_pct")" \
  --arg disk_dev "$disk_dev" \
  --argjson disk_read_sectors "$(num "$disk_read_sectors")" \
  --argjson disk_write_sectors "$(num "$disk_write_sectors")" \
  --argjson disk_read_speed "$(num "$disk_read_speed")" \
  --argjson disk_write_speed "$(num "$disk_write_speed")" \
  --argjson disk_used_bytes "$(num "$disk_used_bytes")" \
  --argjson disk_total_bytes "$(num "$disk_total_bytes")" \
  --argjson disk_used_pct "$(num "$disk_used_pct")" \
  --arg disk_used_human "$disk_used_human" \
  --arg disk_total_human "$disk_total_human" \
  --arg net_iface "$net_iface" \
  --argjson net_rx_bytes "$(num "$net_rx_bytes")" \
  --argjson net_tx_bytes "$(num "$net_tx_bytes")" \
  --argjson net_rx_speed "$(num "$net_rx_speed")" \
  --argjson net_tx_speed "$(num "$net_tx_speed")" \
  --argjson gpu_busy_pct "$(num "$gpu_busy_pct")" \
  --argjson gpu_mem_used "$(num "$gpu_mem_used")" \
  --argjson gpu_mem_total "$(num "$gpu_mem_total")" \
  --argjson gpu_temp_c "$(num "$gpu_temp_c")" \
  --argjson gpu_freq "$(num "$gpu_freq")" \
  --argjson gpu_power "$(num "$gpu_power")" \
  --argjson cpu_temp "$(num "$cpu_temp")" \
  --argjson fan1 "$(num "$fan1")" \
  --argjson fan2 "$(num "$fan2")" \
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
      rx_bytes: $net_rx_bytes, tx.com_bytes: $net_tx_bytes,
      rx_bytes: $net_rx_bytes, tx_bytes: $net_tx_bytes,
      rx_speed: $net_rx_speed, tx_speed: $net_tx_speed
    },
    gpu: {
      busy_pct: $gpu_busy_pct, mem_used: $gpu_mem_used, mem_total: $gpu_mem_total,
      temp_c: $gpu_temp_c, freq: $gpu_freq, power_w: $gpu_power
    },
    temp: { cpu_c: $cpu_temp, fan1: $fan1, fan2: $fan2 }
  }'
then
  log "jq emit failed"
  exit 1
fi

# persist for next delta (include dev/iface so we can reset on change)
printf '%s %s %s %s %s %s %s\n' \
  "$current_ts" "$disk_read_sectors" "$disk_write_sectors" \
  "$net_rx_bytes" "$net_tx_bytes" "$disk_dev" "$net_iface" \
  >"$state_file.tmp" && mv "$state_file.tmp" "$state_file"

# periodic debug (every cycle is fine; small)
log "disk=${disk_dev} rsec=${disk_read_sectors} wsec=${disk_write_sectors} rs=${disk_read_speed} ws=${disk_write_speed} net=${net_iface} rx=${net_rx_speed} tx=${net_tx_speed} d_ok=${delta_ok}"
