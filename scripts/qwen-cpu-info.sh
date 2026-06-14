#!/bin/bash

# CPU info — per-core 4×4 grid of colored pct% cells, plus overall avg + temp.
# Uses two snapshots of /proc/stat (0.5s apart) piped through awk.

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

read_samples > /tmp/qb_r1
sleep 0.5
read_samples > /tmp/qb_r2

# awk computes per-core pct, produces 5 Pango-formatted lines:
#   line 1: overall_avg  (plain int)
#   lines 2-5: one row each, with Pango-colored "idx:pct%" cells
awk '
FNR==NR { tot1[$1]=$2; idle1[$1]=$3; next }
{
  n=$1; dt=$2-tot1[n]; di=$3-idle1[n];
  if (dt<=0) dt=1;
  pct=int((dt-di)*100/dt);
  if (pct<0) pct=0; if (pct>100) pct=100;
  loads[n]=pct; idx[n]=n;
  sum+=pct; cnt++;
}
END {
  avg=int(sum/cnt)
  printf "%d\n", avg
  rows=4; cols=4;
  sep="";
  for (r=0; r<rows; r++) {
    for (c=0; c<cols; c++) {
      i=r*cols+c;
      name="cpu"i;
      if (!(name in loads)) { if (c>0) printf "  "; continue }
      pct=loads[name];
      if      (pct<20)  col="#45475a";
      else if (pct<25)  col="#a6e3a1";
      else if (pct<40)  col="#89b4fa";
      else if (pct<70)  col="#b4befe";
      else if (pct<90)  col="#f9e2af";
      else              col="#f38ba8";
      printf "%s<span fgcolor=%s><span size=xx-small>%d:%d%%</span></span>", sep, col, i, pct;
      sep="  ";
    }
    sep="";
    printf "\n";
  }
}
' /tmp/qb_r1 /tmp/qb_r2 > /tmp/qb_grid

overall=$(head -1 /tmp/qb_grid)
row1=$(sed -n '2p' /tmp/qb_grid)
row2=$(sed -n '3p' /tmp/qb_grid)
row3=$(sed -n '4p' /tmp/qb_grid)
row4=$(sed -n '5p' /tmp/qb_grid)

# CPU temp
cpu_temp=0
for tz in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$tz" ] || continue
  t=$(($(cat "$tz" 2>/dev/null || echo 0) / 1000))
  [ "$t" -gt 99 ] && continue
  cpu_temp=$t; break
done
[ "$cpu_temp" -eq 0 ] && for hw in /sys/class/hwmon/hwmon*/temp1_input; do
  [ -r "$hw" ] || continue
  t=$(($(cat "$hw" 2>/dev/null || echo 0) / 1000))
  [ "$t" -gt 0 ] && [ "$t" -lt 99 ] && { cpu_temp=$t; break; }
done

# Color tiers
pct_color() {
  local p=$1; if [ "$p" -ge 90 ]; then echo "#f38ba8"
              elif [ "$p" -ge 70 ]; then echo "#f9e2af"
              elif [ "$p" -ge 40 ]; then echo "#b4befe"
              else echo "#45475a"; fi
}
temp_color() {
  local t=$1; if [ "$t" -ge 90 ]; then echo "#f38ba8"
              elif [ "$t" -ge 80 ]; then echo "#fab387"
              elif [ "$t" -ge 70 ]; then echo "#f9e2af"
              else echo "#a6e3a1"; fi
}
pc=$(pct_color "$overall"); tc=$(temp_color "$cpu_temp")

summary="<span fgcolor='$pc'><b>${overall}%</b></span>  <span fgcolor='$tc'><b>${cpu_temp}°C</b></span>"

text="${summary}\n${row1}\n${row2}\n${row3}\n${row4}"

jq -n --compact-output --arg text "$text" --arg cls "info" '{text:$text,class:$cls}'
