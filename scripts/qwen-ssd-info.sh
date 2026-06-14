#!/bin/bash

# SSD info tile — label + visual usage bar + live I/O speeds

DEVICE=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${DEVICE#/dev/}"

# Disk usage
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')
total_human=$(df --output=size -h / | tail -1 | tr -d ' ')
used_human=$(df --output=used -h / | tail -1 | tr -d ' ')

# Label
label=$(lsblk -no LABEL "$DEVICE" 2>/dev/null | head -1)
if [ -z "$label" ]; then
  label=$(lsblk -dno MODEL "/dev/$parent" 2>/dev/null | head -1 | awk '{print $1}')
fi
[ -z "$label" ] && label="$parent"
[ ${#label} -gt 12 ] && label="${label:0:9}…"

# Visual usage bar — 12 segments using Pango fgcolor so even identical
# glyphs look different when colored (accent vs dim grey)
# Filled glyph: ▓ (U+2593, dark shade)
# Empty glyph:  ▒ (U+2592, medium shade)
# We color filled in #a6e3a1 (green) and empty in #555 (dim)
segments=12
filled=$((usage_pct * segments / 100))
[ "$filled" -gt "$segments" ] && filled="$segments"
[ "$filled" -lt 0 ] && filled=0
empty=$((segments - filled))

filled_str=$(printf '▓%.0s' $(seq 1 $filled))
empty_str=$(printf '▒%.0s' $(seq 1 $empty))

# Color class by usage
if   [ "$usage_pct" -ge 95 ]; then cls="critical"
elif [ "$usage_pct" -ge 85 ]; then cls="warning"
elif [ "$usage_pct" -ge 70 ]; then cls="medium"
else cls="good"; fi

# I/O sampling — 1s delta on sectors (512 bytes each) from sysfs stat
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

read_secs=$((read2 - read1))
[ "$read_secs" -lt 0 ] && read_secs=0
write_secs=$((write2 - write1))
[ "$write_secs" -lt 0 ] && write_secs=0

read_bytes=$((read_secs * 512))
write_bytes=$((write_secs * 512))

fmt_bytes() {
  local b=$1
  if   [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"
  elif [ "$b" -ge 1048576   ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"
  elif [ "$b" -ge 1024      ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"
  else printf "%dB" "$b"; fi
}

read_fmt=$(fmt_bytes "$read_bytes")
write_fmt=$(fmt_bytes "$write_bytes")

# I/O activity class (worst of usage% and I/O rate)
io_total=$((read_bytes + write_bytes))
io_cls="$cls"
if   [ "$io_total" -gt 104857600  ]; then io_cls="critical"
elif [ "$io_total" -gt 10485760   ]; then io_cls="warning"
elif [ "$io_total" -gt 1048576    ]; then io_cls="medium"
fi

# Two-row Pango layout:
#   Row 1: label + colored bar + pct
#   Row 2: used/total + I/O speeds
text=$(printf "<b>%s</b> <span fgcolor='#a6e3a1'>%s</span><span fgcolor='#555'>%s</span> <b>%d%%</b>\n<span size='small'>%s/%s  \u2193%s \u2191%s</span>" \
  "$label" "$filled_str" "$empty_str" "$usage_pct" \
  "$used_human" "$total_human" "$read_fmt/s" "$write_fmt/s")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$io_cls" \
  '{text: $text, class: $cls}'
