#!/bin/bash
# CPU info — per-core 4×4 grid, avg + temp header

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

read_samples > /tmp/qb_r1
sleep 0.5
read_samples > /tmp/qb_r2

awk '
BEGIN { sq = sprintf("%c", 39) }
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
  printf "%d\n", avg;
  for (r=0; r<4; r++) {
    sep="";
    for (c=0; c<4; c++) {
      i=r*4+c; name="cpu"i;
      if (!(name in loads)) { if (c>0) printf "  "; continue }
      p=loads[name];
      if      (p<20)  col="#45475a";
      else if (p<25)  col="#a6e3a1";
      else if (p<40)  col="#89b4fa";
      else if (p<70)  col="#b4befe";
      else if (p<90)  col="#f9e2af";
      else              col="#f38ba8";
      printf "%s<span fgcolor=" sq "%s" sq "><span size=xx-small>%d:%d%%</span></span>", sep, col, i, p;
      sep="  ";
    }
    if (r<3) printf "\n";
  }
}
' /tmp/qb_r1 /tmp/qb_r2 > /tmp/qb_grid

overall=$(head -1 /tmp/qb_grid)
row1=$(sed -n '2p' /tmp/qb_grid)
row2=$(sed -n '3p' /tmp/qb_grid)
row3=$(sed -n '4p' /tmp/qb_grid)
row4=$(sed -n '5p' /tmp/qb_grid)

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

pct_color() {
  if [ "$1" -ge 90 ]; then echo "#f38ba8"
  elif [ "$1" -ge 70 ]; then echo "#f9e2af"
  elif [ "$1" -ge 40 ]; then echo "#b4befe"
  else echo "#45475a"; fi
}
temp_color() {
  if [ "$1" -ge 90 ]; then echo "#f38ba8"
  elif [ "$1" -ge 80 ]; then echo "#fab387"
  elif [ "$1" -ge 70 ]; then echo "#f9e2af"
  else echo "#a6e3a1"; fi
}

pc=$(pct_color "$overall"); tc=$(temp_color "$cpu_temp")

summary=$(printf "<span fgcolor='%s'><b>%s%%</b></span>  <span fgcolor='%s'><b>%s°C</b></span>" \
  "$pc" "$overall" "$tc" "$cpu_temp")

text=$(printf "%s\n%s\n%s\n%s\n%s" "$summary" "$row1" "$row2" "$row3" "$row4")

jq -nc --arg text "$text" --arg cls "info" '{text:$text,class:$cls}'
