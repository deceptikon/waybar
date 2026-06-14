#!/bin/bash

# SSD info tile — visual usage bar + live I/O speeds

device=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

# Disk usage
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')
total_human=$(df --output=size -h / | tail -1 | tr -d ' ')
used_human=$(df --output=used -h / | tail -1 | tr -d ' ')
avail_human=$(df --output=avail -h / | tail -1 | tr -d ' ')

# Label
label=$(lsblk -no LABEL "$device" 2>/dev/null | head -1)
if [ -z "$label" ]; then
  label=$(lsblk -dno MODEL "/dev/$parent" 2>/dev/null | head -1 | awk '{print $1}')
fi
[ -z "$label" ] && label="$parent"
[ ${#label} -gt 12 ] && label="${label:0:9}…"

# Visual usage bar (10 chars: █ used, ░ free)
blocks=$((usage_pct / 10))
[ "$blocks" -gt 10 ] && blocks=10
[ "$blocks" -lt 0 ] && blocks=0
filled=$(printf '%*s' "$blocks" '' | tr ' ' '█')
empty=$((10 - blocks))
empty_chars=$(printf '%*s' "$empty" '' | tr ' ' '░')
bar="${filled}${empty_chars}"

# Color class by usage
if   [ "$usage_pct" -ge 95 ]; then cls="critical"
elif [ "$usage_pct" -ge 85 ]; then cls="warning"
elif [ "$usage_pct" -ge 70 ]; then cls="medium"
else cls="good"; fi

# I/O sampling — 1s delta on sectors (512 bytes each)
stat_file="/sys/block/$parent/stat"
read1=0; write1=0
if [ -r "$stat_file" ]; then
  stat_line=$(head -1 "$stat_file")
  read1=$(echo "$stat_line" | awk '{print $3}')
  write1=$(echo "$stat_line" | awk '{print $7}')
fi

sleep 1

read2=0; write2=0
if [ -r "$stat_file" ]; then
  stat_line=$(head -1 "$stat_file")
  read2=$(echo "$stat_line" | awk '{print $3}')
  write2=$(echo "$stat_line" | awk '{print $7}')
fi

read_secs=$((read2 - read1)); [ "$read_secs" -lt 0 ] && read_secs=0
write_secs=$((write2 - write1)); [ "$write_secs" -lt 0 ] && write_secs=0

read_bytes=$((read_secs * 512))
write_bytes=$((write_secs * 512))

fmt_bytes() {
  local b=$1
  if   [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"
  elif [ "$b" -ge 1048576 ];     then awk "BEGIN{printf\"%.0fM\",$b/1048576}"
  elif [ "$b" -ge 1024 ];        then awk "BEGIN{printf\"%.0fK\",$b/1024}"
  else echo "${b}B"; fi
}

read_fmt=$(fmt_bytes "$read_bytes")
write_fmt=$(fmt_bytes "$write_bytes")

# I/O activity class
io_total=$((read_bytes + write_bytes))
io_cls="$cls"
if   [ "$io_total" -gt 104857600 ]; then io_cls="critical"
elif [ "$io_total" -gt 10485760  ]; then io_cls="warning"
elif [ "$io_total" -gt 1048576   ]; then io_cls="medium"
fi

# Two-row Pango markup:
#   Row 1: visual bar
#   Row 2: I/O speeds with arrows
text=$(printf "<b>%s</b>\n<span size='small'>↓%s  ↑%s</span>" \
  "${bar} ${usage_pct}%" "$read_fmt/s" "$write_fmt/s")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$io_cls" \
  '{text: $text, class: $cls}'
