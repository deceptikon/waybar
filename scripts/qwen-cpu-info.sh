#!/bin/bash
set -euo pipefail
# CPU info — 2×8 per-core blocks, avg% on the right, no temperature

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT

read_samples > "$work/s1"
sleep 0.3
read_samples > "$work/s2"

# Single awk pass: generate Pango markup (two lines) and compute avg
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
  for (c=0; c<16; c++) {
    name = "cpu"c;
    p = (name in loads) ? loads[name] : -1;
    if      (p >= 90)  col = "#f38ba8";
    else if (p >= 70)  col = "#fab387";
    else if (p >= 40)  col = "#f9e2af";
    else if (p >= 15)  col = "#89b4fa";
    else if (p >= 0)   col = "#383838";
    else               col = "#2a2a2a";
    bar = bar sprintf("<span fgcolor=\"%s\">\342\226\223</span>", col);
    if (c == 7) bar = bar "\n";
  }
  bar = bar sprintf("<span size=\"medium\"><b><span fgcolor=\"#89b4fa\"> %d%%</span></b></span>", avg);
  printf "%s\nAVG:%d", bar, avg;
}
' "$work/s1" "$work/s2" > "$work/out"

line1=$(sed -n '1p' "$work/out")
line2=$(sed -n '2p' "$work/out")
avg=$(sed -n '/^AVG:/s/^AVG://p' "$work/out")

cls="good"
[ "$avg" -ge 50 ] && cls="medium"
[ "$avg" -ge 75 ] && cls="warning"
[ "$avg" -ge 90 ] && cls="critical"

jq -nc --arg l1 "$line1" --arg l2 "$line2" --arg cls "$cls" '{text: ($l1 + "\n" + $l2), class: $cls}'
