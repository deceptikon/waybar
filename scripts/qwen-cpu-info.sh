#!/bin/bash
# CPU info — 2×8 per-core blocks, avg% on the right, no temperature

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

read_samples > /tmp/qb_r1
sleep 0.3
read_samples > /tmp/qb_r2

awk '
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
  # Row 1: cores 0-7
  for (c=0; c<8; c++) {
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
  printf "\n";
  # Row 2: cores 8-15 + avg%
  for (c=8; c<16; c++) {
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
  printf "<span size=\"medium\"><b><span fgcolor=\"#89b4fa\"> %d%%</span></b></span>", avg;
}
' /tmp/qb_r1 /tmp/qb_r2 > /tmp/qb_cpu_raw

# Build the text field line by line
line1=$(sed -n '1p' /tmp/qb_cpu_raw)
line2=$(sed -n '2p' /tmp/qb_cpu_raw)

# Extract avg for class
avg=$(awk '/AVG/{print $2}' /tmp/qb_r1 | head -1) || avg=$(echo "$line2" | grep -oP '>\K\d+(?=%)' || echo 0)
# Re-read from file for awk approach
AWKOUT=$(cat /tmp/qb_r1)
# Actually, let me just extract from the raw output differently
awk '
FNR==NR { tot1[$1]=$2; idle1[$1]=$3; next }
{
  n=$1; dt=$2-tot1[n]; di=$3-idle1[n];
  if (dt<=0) dt=1;
  p=int((dt-di)*100/dt);
  if (p<0) p=0; if (p>100) p=100;
  loads[n]=p;
  sum+=p; cnt++;
}
END { avg=int(sum/cnt); printf "%d", avg }
' /tmp/qb_r1 /tmp/qb_r2 > /tmp/qb_cpu_avg
avg=$(cat /tmp/qb_cpu_avg)

cls="good"
[ "$avg" -ge 50 ] && cls="medium"
[ "$avg" -ge 75 ] && cls="warning"
[ "$avg" -ge 90 ] && cls="critical"

jq -nc --arg l1 "$line1" --arg l2 "$line2" --arg cls "$cls" '{text: ($l1 + "\n" + $l2), class: $cls}'
