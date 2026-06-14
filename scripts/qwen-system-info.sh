#!/bin/bash

# System info tile — CPU% + RAM% with colored bars

# === CPU usage — 2-s sampling of /proc/stat (field 5 = idle) ===
read_cpu_sample() {
  awk '/^cpu / {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; print tot, idle}' /proc/stat
}
total1=0; idle1=0; total2=0; idle2=0
{ read total1 idle1; } < <(read_cpu_sample)
sleep 0.5
{ read total2 idle2; } < <(read_cpu_sample)
dt=$((total2 - total1))
[ "$dt" -le 0 ] && dt=1
cpu_pct=$(( (dt - (idle2 - idle1)) * 100 / dt ))
[ "$cpu_pct" -lt 0 ] && cpu_pct=0
[ "$cpu_pct" -gt 100 ] && cpu_pct=100

# === RAM usage ===
mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))
mem_pct=$((mem_used * 100 / mem_total))
mem_used_g=$(awk "BEGIN{printf \"%.1f\", $mem_used/1024/1024}")
mem_total_g=$(awk "BEGIN{printf \"%.1f\", $mem_total/1024/1024}")

# === CPU temperature (thermal_zone) ===
cpu_temp=0
if [ -d /sys/class/thermal ]; then
  for tz in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$tz" ] || continue
    t=$(cat "$tz" 2>/dev/null || echo "0")
    t=$((t / 1000))
    [ "$t" -gt 99 ] && continue   # ignore outliers
    cpu_temp=$t; break
  done
fi

# Fallback: try hwmon if thermal zone didn't yield a sensible value
if [ "$cpu_temp" -eq 0 ]; then
  for hw in /sys/class/hwmon/hwmon*/temp1_input; do
    [ -r "$hw" ] || continue
    t=$(cat "$hw" 2>/dev/null || echo "0")
    t=$((t / 1000))
    [ "$t" -gt 0 ] && [ "$t" -lt 99 ] && { cpu_temp=$t; break; }
  done
fi

# === Build mini bar (8 segments) ===
make_bar() {
  local pct=$1 fg=$2
  local filled=$((pct * 8 / 100))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  local empty=$((8 - filled))
  local f e
  [ "$filled" -gt 0 ] && f=$(printf '▓%.0s' $(seq 1 $filled)) || f=""
  [ "$empty" -gt 0 ]  && e=$(printf '░%.0s' $(seq 1 $empty))  || e=""
  echo "<span fgcolor='$fg'>$f</span><span fgcolor='#444'>$e</span>"
}

# Temp-color helper
temp_cls() {
  local t=$1
  if   [ "$t" -ge 90 ]; then echo "critical"
  elif [ "$t" -ge 80 ]; then echo "warning"
  elif [ "$t" -ge 70 ]; then echo "medium"
  else echo "good"; fi
}
temp_color() {
  local t=$1
  if   [ "$t" -ge 90 ]; then echo "#f38ba8"
  elif [ "$t" -ge 80 ]; then echo "#fab387"
  elif [ "$t" -ge 70 ]; then echo "#f9e2af"
  else echo "#a6e3a1"; fi
}

cpu_bar=$(make_bar $cpu_pct '#89b4fa')
ram_bar=$(make_bar $mem_pct '#cba7f7')
t_color=$(temp_color $cpu_temp)
t_cls=$(temp_cls $cpu_temp)

# Overall class: worst of cpu% / ram% / temp
rank_cls() {
  case "$1" in good)echo 0;; medium)echo 1;; warning)echo 2;; critical)echo 3;; *)echo 0;;
  esac
}
unrank() { case "$1" in 0)echo good;; 1)echo medium;; 2)echo warning;; 3)echo critical;; esac; }
pct_rank() {
  local p=$1
  if   [ "$p" -ge 90 ]; then echo 3
  elif [ "$p" -ge 75 ]; then echo 2
  elif [ "$p" -ge 50 ]; then echo 1
  else echo 0; fi
}
r_cpu=$(pct_rank $cpu_pct); r_ram=$(pct_rank $mem_pct); r_tmp=$(rank_cls "$t_cls")
maxr=$r_cpu; [ "$r_ram" -gt "$maxr" ] && maxr=$r_ram; [ "$r_tmp" -gt "$maxr" ] && maxr=$r_tmp
overall=$(unrank $maxr)

# Two-row Pango layout:
#   Row 1: CPU  bar  pct%  temp
#   Row 2: RAM  bar  pct%  used/total
text=$(printf "<span size='small'>CPU</span> %s <b>%d%%</b>  <span fgcolor='%s'>%d°C</span>\n<span size='small'>RAM</span> %s <b>%d%%</b>  <span>%s/%sG</span>" \
  "$cpu_bar" "$cpu_pct" "$t_color" "$cpu_temp" \
  "$ram_bar" "$mem_pct" "$mem_used_g" "$mem_total_g")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$overall" \
  '{text: $text, class: $cls}'
