---
name: waybar-ssd-module-v4
description: Simplified SSD module with single icon, 4-segment bar, live I/O
source: auto-skill
extracted_at: '2026-06-14T18:30:00.000Z'
---

# SSD Module Pattern for Waybar (v4)

**Updated 2026-06-14**: Simplified SSD module with single-icon tile, 4-segment bar, and live I/O.

This skill covers creating a composite SSD indicator module with two tiles:
1. **Icon tile**: single disk icon (SSD or HDD) — no secondary badge
2. **Info tile**: compact 4-segment usage bar + live I/O read/write speeds

## When to Use

Use this pattern when:
- You need to show disk type (SSD vs HDD) in a compact space
- You want a visual representation of used/free space (not just % label)
- You need live I/O read/write speeds that feel responsive
- You want per-state coloring based on usage or I/O load (temperature removed for simplicity)

## Module Structure

### 1. Two-Script Approach

**Icon script** (`qwen-ssd-icon.sh`):
- Outputs only the main disk icon (SSD or HDD)
- Reads rotational flag to determine type
- Produces JSON: `{"text": "SSD/HDD icon", "class": "icon"}`

**Info script** (`qwen-ssd-info.sh`):
- Parses disk usage % and formats into **4-segment** block bar
- Uses Pango `fgcolor` to color filled segment vs empty for contrast
- Samples `/sys/block/<dev>/stat` twice (0.5s delta) to get read/write sectors
- Converts sectors × 512 bytes → B/s → formatted string
- Produces JSON: `{"text": "<b>[bar]</b> <b>%d%%</b>\n<span>↓read ↑write</span>", "class": "io-class"}`

```bash
# qwen-ssd-icon.sh
device=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

# Detect SSD/HDD via /sys/block/<dev>/queue/rotational (0=SSD, 1=HDD)
rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")

# Use printf with exact UTF-8 bytes for Nerd Font glyphs
# nf-mdi-ssd: U+F0CCA → bytes: f3 b0 b3 8a
# nf-mdi-harddisk: U+F0CC9 → bytes: f3 b0 b3 89
if [ "$rotational" = "0" ]; then
  icon=$(printf '\xf3\xb0\xb3\x8a')
else
  icon=$(printf '\xf3\xb0\xb3\x89')
fi

jq -n --arg txt "$icon" '{text: $txt, class: "icon"}'
```

```bash
# qwen-ssd-info.sh
device=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)
[ -z "$parent" ] && parent="${device#/dev/}"

# Usage percent
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')

# 4-segment bar: filled=[▓], empty=[▒]
segments=4
filled=$((usage_pct * segments / 100))
[ "$filled" -gt "$segments" ] && filled="$segments"
[ "$filled" -lt 0 ] && filled=0
empty=$((segments - filled))

filled_str=$(printf '▓%.0s' $(seq 1 $filled))
empty_str=$(printf '▒%.0s' $(seq 1 $empty))

# I/O sampling: 0.5s delta
stat_file="/sys/block/$parent/stat"
read1=$(awk '{print $3}' "$stat_file" 2>/dev/null || echo 0)
write1=$(awk '{print $7}' "$stat_file" 2>/dev/null || echo 0)

sleep 0.5

read2=$(awk '{print $3}' "$stat_file" 2>/dev/null || echo 0)
write2=$(awk '{print $7}' "$stat_file" 2>/dev/null || echo 0)

read_secs=$((read2 - read1)); [ "$read_secs" -lt 0 ] && read_secs=0
write_secs=$((write2 - write1)); [ "$write_secs" -lt 0 ] && write_secs=0

read_bytes=$((read_secs * 512))
write_bytes=$((write_secs * 512))

# Format bytes/sec as B/K/M/G
fmt_bytes() {
  local b=$1
  if   [ "$b" -ge 1073741824 ]; then awk "BEGIN{printf\"%.1fG\",$b/1073741824}"
  elif [ "$b" -ge 1048576   ]; then awk "BEGIN{printf\"%.0fM\",$b/1048576}"
  elif [ "$b" -ge 1024      ]; then awk "BEGIN{printf\"%.0fK\",$b/1024}"
  else printf "%dB" "$b"; fi
}

read_fmt=$(fmt_bytes "$read_bytes")
write_fmt=$(fmt_bytes "$write_bytes")

# Arrow chars via literal bytes: ↓=U+2193 (e2 86 93), ↑=U+2191 (e2 86 91)
arr_down=$(printf '\xe2\x86\x93')
arr_up=$(printf '\xe2\x86\x91')

# Pango markup: colored bar + pct in row1, ↓read ↑write in row2 (teal)
text=$(printf "<b><span fgcolor='#a6e3a1'>%s</span><span fgcolor='#555'>%s</span></b> <b>%d%%</b>\n<span size='small' fgcolor='#94e2d5'>%s%s  %s%s</span>" \
  "$filled_str" "$empty_str" "$usage_pct" \
  "$arr_down" "$read_fmt/s" "$arr_up" "$write_fmt/s")

# Color class driven by worst of usage% or I/O rate
io_total=$((read_bytes + write_bytes))
if   [ "$usage_pct" -ge 95 ] || [ "$io_total"      -gt 104857600 ]; then cls="critical"
elif [ "$usage_pct" -ge 85 ] || [ "$io_total"      -gt 10485760  ]; then cls="warning"
elif [ "$usage_pct" -ge 70 ] || [ "$io_total"      -gt 1048576   ]; then cls="medium"
else cls="good"; fi

jq -n --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
```

### 2. Group Definition

```json
{
  "group/qwen-ssd": {
    "orientation": "horizontal",
    "modules": [
      "custom/qwen-ssd-icon",
      "custom/qwen-ssd-info"
    ]
  },
  "custom/qwen-ssd-icon": {
    "exec": "~/.config/waybar/scripts/qwen-ssd-icon.sh",
    "interval": 30,
    "format": "{}",
    "return-type": "json"
  },
  "custom/qwen-ssd-info": {
    "exec": "~/.config/waybar/scripts/qwen-ssd-info.sh",
    "interval": 5,
    "format": "{}",
    "return-type": "json",
    "on-click": "gnome-disks",
    "on-right-click": "lsblk"
  }
}
```

## CSS Pattern

### Outer Box (Same as nested-box pattern used for wifi)

```css
#group-qwen-ssd {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(166, 227, 161, 0.4);  /* Green accent (Catppuccin #a6e3a1) */
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}
```

### Icon Tile (Single Icon)

Single icon fits in `28px` min-width:

```css
#custom-qwen-ssd-icon {
  font-size: 18px;
  min-width: 28px;
  padding: 2px 4px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: #a6e3a1;                /* Green accent */
  margin-right: 2px;
}
```

### Info Tile (4-Char Bar + I/O)

```css
#custom-qwen-ssd-info {
  font-size: 12px;
  font-weight: 500;
  min-width: 0;
  padding: 2px 8px;
  border-radius: 6px;
  border: 1px solid rgba(166, 227, 161, 0.4);
  background: rgba(30, 30, 42, 0.85);
  color: #a6e3a1;
}

#custom-qwen-ssd-info.medium  { background: rgba(249, 226, 175, 0.15); border-color: rgba(249, 226, 175, 0.45); color: #f9e2af; }
#custom-qwen-ssd-info.warning { background: rgba(250, 179, 135, 0.2);   border-color: rgba(250, 179, 135, 0.55); color: #fab387; }
#custom-qwen-ssd-info.critical { background: rgba(243, 139, 168, 0.2);  border-color: rgba(243, 139, 168, 0.55); color: #f38ba8; }
```

## Key Techniques

### 1. Disk Type Detection

```bash
rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
if [ "$rotational" = "0" ]; then
  icon=$(printf '\xf3\xb0\xb3\x8a')  # SSD (U+F0CCA)
else
  icon=$(printf '\xf3\xb0\xb3\x89')  # HDD (U+F0CC9)
fi
```

### 2. Compact 4-Segment Bar

```bash
segments=4
filled=$((usage_pct * segments / 100))
[ "$filled" -gt "$segments" ] && filled="$segments"

filled_str=$(printf '▓%.0s' $(seq 1 $filled))
empty_str=$(printf '▒%.0s' $(seq 1 $((segments - filled))))

# Color via Pango fgcolor for contrast: #a6e3a1 (green) vs #555 (dim)
printf "<b><span fgcolor='#a6e3a1'>%s</span><span fgcolor='#555'>%s</span></b>" "$filled_str" "$empty_str"
```

### 3. I/O Sector → Bytes Conversion (0.5s sampling)

```bash
stat_file="/sys/block/$parent/stat"
read1=$(awk '{print $3}' "$stat_file")   # read_sectors field 3
write1=$(awk '{print $7}' "$stat_file")  # write_sectors field 7

sleep 0.5

read2=$(awk '{print $3}' "$stat_file")
write2=$(awk '{print $7}' "$stat_file")

read_secs=$((read2 - read1)); [ "$read_secs" -lt 0 ] && read_secs=0
write_secs=$((write2 - write1)); [ "$write_secs" -lt 0 ] && write_secs=0

read_bytes=$((read_secs * 512))  # 512 bytes per sector
write_bytes=$((write_secs * 512))
```

### 4. Arrow Glyphs via Literal Bytes

```bash
arr_down=$(printf '\xe2\x86\x93')  # ↓ (U+2193)
arr_up=$(printf '\xe2\x86\x91')    # ↑ (U+2191)

# Pango: "$arr_down%s  $arr_up%s" → "↓0B/s  ↑0B/s"
```

### 5. State Class Logic

```bash
# Usage percent class
if   [ "$usage_pct" -ge 95 ]; then pct_cls="critical"
elif [ "$usage_pct" -ge 85 ]; then pct_cls="warning"
elif [ "$usage_pct" -ge 70 ]; then pct_cls="medium"
else pct_cls="good"; fi

# I/O rate class (same thresholds scaled)
io_total=$((read_bytes + write_bytes))
if   [ "$io_total" -gt 104857600 ]; then io_cls="critical"
elif [ "$io_total" -gt 10485760  ]; then io_cls="warning"
elif [ "$io_total" -gt 1048576   ]; then io_cls="medium"
else io_cls="good"; fi

# Final class = worst of usage vs I/O
cls="$pct_cls"
[ "$io_cls" = "critical" ] && cls="critical"
[ "$io_cls" = "warning" ] && [ "$cls" != "critical" ] && cls="warning"
[ "$io_cls" = "medium" ] && [ "$cls" = "good" ] && cls="medium"
```

## Common Issues

### Unicode Icons Don't Render (Empty Strings)

- **Cause**: Shell heredocs or `write_file` may strip multi-byte UTF-8 sequences
- **Fix**: Use `printf '\xf3\xb0\xb3\x8a'` with explicit hex bytes in the script
- **Never**: Store icons as literal Unicode in the script text; always inject via printf

### Block Characters Render as Squares or Identical

- **Cause**: Font missing full Unicode coverage, or glyphs render identically
- **Fix**: Use **colored Pango fgcolor** (#a6e3a1 vs #555) so even identical glyphs contrast visually
- **Alternative**: Use different glyphs (■/□, ◼/◻) or reduce segment count

### I/O Values Stay at 0B/s

- **Cause**: Script interval too long (60s) → stale snapshot, or sampling interval too fast (<0.5s)
- **Fix**: Use `interval: 5` in JSON + `sleep 0.5` in script to feel live
- **Verify**: `cat /sys/block/<dev>/stat` shows changing counters under load

### Icon Missing in Preview

- **Cause**: Icon script outputs empty string (failed printf or no bytes)
- **Fix**: Check script with `/home/lexx/.config/waybar/scripts/qwen-ssd-icon.sh` and verify JSON output

## Iteration Checklist

- [ ] Single disk icon (SSD/HDD) renders correctly (not empty)
- [ ] Bar is 4 segments (not 12 or 10)
- [ ] Bar has visual contrast (green vs dim via fgcolor)
- [ ] No label text (ORICO, used/total) — just bar + percent
- [ ] I/O speeds update every 5s (not 60s), feel live with 0.5s sampling
- [ ] Arrows ↓↑ appear correctly (via literal bytes)
- [ ] Outer box reads on light/dark backgrounds
- [ ] State colors (good/medium/warning/critical) work on info tile

## Example Output

**Icon tile**: `󰳊` (SSD icon)

**Info tile**:
```
▓▒▒▒ 19%
↓0B/s  ↑0B/s
```

**Under I/O load** (after 0.5s sampling):
```
▓▒▒▒ 19%
↓2.4M/s  ↑0.8M/s
```

**State coloring** (critical example):
```
▓▓▓▓ 96%
↓100M/s  ↑200M/s
```

## Related Skills

- `auto-skill-waybar-nested-box`: The nested box CSS pattern used for group
- `auto-skill-waybar-script-debug`: Debugging silent script failures
- `auto-skill-waybar-module-sandbox`: Testing in dev bar before production
- `auto-skill-waybar-toggle-button`: Pattern for exec+on-click toggle modules

## Resources

- `/sys/block/<dev>/queue/rotational` — HDD vs SSD flag (0=SSD, 1=HDD)
- `/sys/block/<dev>/stat` — I/O counters (field 3=read_sectors, field 7=write_sectors, each sector=512 bytes)
- `df --output=pcent /` — Disk usage percentage
- Nerd Font codepoints:
  - SSD: 🟧 `U+F0CCA` → bytes `f3 b0 b3 8a` (nf-mdi-ssd)
  - HDD: 💾 `U+F0CC9` → bytes `f3 b0 b3 89` (nf-mdi-harddisk)
  - Down arrow: ↓ `U+2193` → bytes `e2 86 93`
  - Up arrow: ↑ `U+2191` → bytes `e2 86 91`
  - Block dark: ▓ `U+2593`
  - Block medium: ▒ `U+2592`
