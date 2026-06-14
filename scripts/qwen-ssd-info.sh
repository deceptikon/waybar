#!/bin/bash

# SSD info tile — compact visual usage bar + live I/O speeds
# Layout: [bar 19%] / [↑read ↓write]

DEVICE=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${DEVICE#/dev/}"

# Disk usage
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')

# Visual usage bar — 4 segments (compact)
# Filled uses ▓ (U+2593), empty uses ▒ (U+2592)
segments=4
filled=$((usage_pct * segments / 100))
[ "$filled" -gt "$segments" ] && filled="$segments"
[ "$filled" -lt 0 ] && filled=0
empty=$((segments - filled))

filled_str=$(printf '▓%.0s' $(seq 1 $filled 2>/dev/null) || true)
empty_str=$(printf '▒%.0s' $(seq 1 $empty 2>/dev/null) || true)

# I/O sampling — 0.5s delta on sectors (512 bytes each)
stat_file="/sys/block/$parent/stat"
read1=0; write1=0
if [ -r "$stat_file" ]; then
  read1=$(awk '{print $3}' "$stat_file" 2>/dev/null || echo 0)
  write1=$(awk '{print $7}' "$stat_file" 2>/dev/null || echo 0)
fi

sleep 0.5

read2=0; write2=0
if [ -r "$stat_file" ]; then
  read2=$(awk '{print $3}' "$stat_file" 2>/dev/null || echo 0)
  write2=$(awk '{print $7}' "$stat_file" 2>/dev/null || echo 0)
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

# Class driven by worst of usage% vs I/O rate
if   [ "$usage_pct" -ge 95 ]; then pct_cls="critical"
elif [ "$usage_pct" -ge 85 ]; then pct_cls="warning"
elif [ "$usage_pct" -ge 70 ]; then pct_cls="medium"
else pct_cls="good"; fi

io_total=$((read_bytes + write_bytes))
io_cls="$pct_cls"
if   [ "$io_total" -gt 104857600  ]; then io_cls="critical"
elif [ "$io_total" -gt 10485760   ]; then io_cls="warning"
elif [ "$io_total" -gt 1048576    ]; then io_cls="medium"; fi

# Arrows: ↑ = U+2191 (e2 86 91), ↓ = U+2193 (e2 86 93)
# ↑ for read (data flowing up from disk), ↓ for write (data flowing down to disk)
arr_up=$(printf '\xe2\x86\x91')
arr_down=$(printf '\xe2\x86\x93')

# Single-row: [bar] [pct%]  ↑read ↓write
text=$(printf "<b><span fgcolor='#a6e3a1'>%s</span><span fgcolor='#555'>%s</span></b> <b>%d%%</b>\n<span size='small' fgcolor='#94e2d5'>%s%s  %s%s</span>" \
  "$filled_str" "$empty_str" "$usage_pct" \
  "$arr_up" "$read_fmt/s" "$arr_down" "$write_fmt/s")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$io_cls" \
  '{text: $text, class: $cls}'
