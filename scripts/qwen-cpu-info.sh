#!/bin/bash
# CPU info — Row 1: 16 per-core usage blocks, Row 2: big avg + temp

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

read_samples > /tmp/qb_r1
sleep 0.3
read_samples > /tmp/qb_r2

AWKOUT=$(awk '
FNR==NR { tot1[$1]=$2; idle1[$1]=$3; next }
{
  n=$1; dt=$2-tot1[n]; di=$3-idle1[n];
  if (dt<=0) dt=1;
  p=int((dt-di)*100/dt);
  if (p<0) p=0; if (p>100) p=100;
  loads[n]=p;
  sum+=p; cnt++;
}
END {
  avg=int(sum/cnt);
  # Row 1: all 16 cores
  for (c=0; c<16; c++) {
    name = "cpu"c;
    p = (name in loads) ? loads[name] : -1;
    if      (p >= 90)  col = "#f38ba8";
    else if (p >= 70)  col = "#fab387";
    else if (p >= 40)  col = "#f9e2af";
    else if (p >= 15)  col = "#89b4fa";
    else if (p >= 0)   col = "#383838";
    else               col = "#2a2a2a";
    printf "<span fgcolor=\"%s\">▓</span>", col;
  }
  printf "\nAVG %d\n", avg;
}
' /tmp/qb_r1 /tmp/qb_r2)

line1=$(echo "$AWKOUT" | sed -n '1p')
avg=$(echo "$AWKOUT" | sed -n '2p' | awk '{print $2}')

# CPU temp
cpu_temp=0
for tz in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$tz" ] || continue
  t=$(($(cat "$tz" 2>/dev/null || echo 0) / 1000))
  if [ "$t" -gt 0 ] && [ "$t" -lt 99 ]; then
    cpu_temp=$t; break
  fi
done

# Temp color
if [ "$cpu_temp" -gt 0 ]; then
  if   [ "$cpu_temp" -ge 80 ]; then tcol="#f38ba8"
  elif [ "$cpu_temp" -ge 70 ]; then tcol="#fab387"
  else                             tcol="#6c7086"; fi
  line2=$(printf "<span fgcolor='#89b4fa' size='large'><b>%d%%</b></span> <span fgcolor='%s' size='medium'>%d°C</span>" "$avg" "$tcol" "$cpu_temp")
else
  line2=$(printf "<span fgcolor='#89b4fa' size='large'><b>%d%%</b></span>" "$avg")
fi

cls="good"
[ "$avg" -ge 50 ] && cls="medium"
[ "$avg" -ge 75 ] && cls="warning"
[ "$avg" -ge 90 ] && cls="critical"

text=$(printf "%s\n%s" "$line1" "$line2")
jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
