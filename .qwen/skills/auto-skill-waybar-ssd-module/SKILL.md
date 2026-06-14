---
name: waybar-ssd-module
description: Building a composite SSD module with icon+temp tile + usage bar + live I/O
source: auto-skill
extracted_at: '2026-06-14T18:14:00.000Z'
---

# SSD Module Pattern for Waybar

This skill covers creating a composite SSD indicator module with two tiles:
1. **Icon tile**: main disk icon (SSD/HDD) + secondary badge (temperature with color class)
2. **Info tile**: visual usage bar (block characters) + live I/O read/write speeds

## When to Use

Use this pattern when:
- You need to show disk type (SSD vs HDD) with a status indicator
- You want to monitor drive temperature (especially NVMe)
- You want a visual representation of used/free space (not just %)
- You need live I/O read/write speeds sampled from `/sys/block`
- You want per-state coloring based on temperature or I/O load

## Module Structure

### 1. Two-Script Approach

**Icon script** (`qwen-ssd-icon.sh`):
- Outputs main disk icon (SSD or HDD) concatenated with temperature badge icon
- Reads rotational flag and hwmon temperature sensors
- Produces JSON: `{"text": "ICON1 + ICON2", "class": "icon [temp-class]"}`

**Info script** (`qwen-ssd-info.sh`):
- Parses disk usage % and formats into 10-character block bar
- Samples `/sys/block/<dev>/stat` twice (1s delta) to get read/write sectors
- Converts sectors × 512 bytes → B/s → formatted string
- Produces JSON: `{"text": "<b>bar %</b>\n<span>I/O</span>", "class": "usage/io-class"}`

```bash
# qwen-ssd-icon.sh
device=$(df / | tail -1 | awk '{print $1}')
parent=$(lsblk -no PKNAME "$device" 2>/dev/null | head -1)

# Detect SSD/HDD
rotational=$(cat "/sys/block/$parent/queue/rotational" 2>/dev/null || echo "1")
main_icon="[SSD or HDD icon]"

# Read temperature
temp_raw=$(cat "/sys/block/$parent/device/hwmon"*/temp*_input 2>/dev/null | head -1)
temp_c=$((temp_raw / 1000))

# Temperature class
[ "$temp_c" -ge 80 ] && cls="critical"

jq -n '{"text": ($main + $badge), "class": ("icon " + $cls)}'
```

```bash
# qwen-ssd-info.sh
usage_pct=$(df --output=pcent / | tail -1 | tr -d ' %')
blocks=$((usage_pct / 10)); [ "$blocks" -gt 10 ] && blocks=10
filled=$(printf '%*s' "$blocks" '' | tr ' ' '█')
empty=$((10 - blocks))
empty_chars=$(printf '%*s' "$empty" '' | tr ' ' '░')
bar="${filled}${empty_chars}"

# I/O sampling
stat_file="/sys/block/$parent/stat"
read1=$(awk '{print $3}' "$stat_file")
sleep 1
read2=$(awk '{print $3}' "$stat_file")
read_secs=$((read2 - read1)); [ "$read_secs" -lt 0 ] && read_secs=0
read_bytes=$((read_secs * 512))
read_fmt=$(fmt_bytes "$read_bytes")

text=$(printf "<b>%s %d%%</b>\n<span>↓%s/s</span>" "$bar" "$usage_pct" "$read_fmt")
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
    "interval": 60,
    "format": "{}",
    "return-type": "json"
  },
  "custom/qwen-ssd-info": {
    "exec": "~/.config/waybar/scripts/qwen-ssd-info.sh",
    "interval": 60,
    "format": "{}",
    "return-type": "json"
  }
}
```

## CSS Pattern

### Outer Box (Same as nested-box pattern)

```css
#group-qwen-ssd {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(166, 227, 161, 0.4);  /* Green accent */
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}
```

### Icon Tile (Two Icons)

Wider `min-width` to fit both main + badge icons:

```css
#custom-qwen-ssd-icon {
  font-size: 16px;               /* Smaller than main, room for 2 */
  min-width: 42px;               /* Enough for two icons */
  padding: 2px 4px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: #a6e3a1;                /* Green accent */
  margin-right: 2px;
}

/* Temperature-based colors */
#custom-qwen-ssd-icon.critical { color: #f38ba8; }
#custom-qwen-ssd-icon.warning  { color: #fab387; }
#custom-qwen-ssd-icon.medium   { color: #f9e2af; }
```

### Info Tile (Block bar + I/O)

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
  icon=""  # SSD icon
else
  icon=""  # HDD icon
fi
```

### 2. NVMe Temperature Reading

```bash
# Search for hwmon temp files
for hwmon_path in "/sys/block/$parent/device/hwmon"*/temp*_input; do
  if [ -r "$hwmon_path" ]; then
    temp_raw=$(cat "$hwmon_path")
    temp_c=$((temp_raw / 1000))
    break
  fi
done
```

Note: NVMe drives typically expose temps in **millidegrees Celsius**.

### 3. I/O Sector → Bytes Conversion

```bash
stat_file="/sys/block/$parent/stat"
# /sys/block/<dev>/stat format:
#  read_completed  read_merged  read_sectors  read_ticks
#  write_completed write_merged write_sectors write_ticks
read_sectors=$(awk '{print $3}' "$stat_file")
write_sectors=$(awk '{print $7}' "$stat_file")
read_bytes=$((read_sectors * 512))
write_bytes=$((write_sectors * 512))
```

Sectors are 512 bytes each (standard block size).

### 4. Visual Bar Formatting

```bash
blocks=$((usage_pct / 10))      # 19% → 1 filled block
filled=$(printf '%*s' "$blocks" '' | tr ' ' '█')
empty=$((10 - blocks))
empty_chars=$(printf '%*s' "$empty" '' | tr ' ' '░')
bar="${filled}${empty_chars}"  # "█████░░░░░"
```

### 5. Color Class Logic

Combine multiple signals (temperature, usage, I/O):

```bash
# Take worst (highest risk) of all signals
rank=$(rank_cls "$temp_cls")
usage_rank=$(rank_cls "$usage_cls")
io_rank=$(rank_cls "$io_cls")
final_rank=$((temp > usage ? temp : usage)); final_rank=$((final_rank > io ? final_rank : io))
cls=$(unrank_cls "$final_rank")
```

## Common Issues

### Unicode Block Characters Don't Render

- Ensure you're using **JetBrainsMono Nerd Font**, **Monaspace**, or similar
- Block chars (`█░`) require full Unicode coverage
- If it shows as `?` or `□`, try adjusting font size or switch fonts

### Temperature Returns `0` or Missing

- Not all drives expose hwmon temps (especially SATA HDDs)
- NVMe drives usually do (`/sys/block/nvme0n1/device/hwmon*/temp*_input`)
- HDDs may not have temps at all (expected behavior)

### I/O Counter Divergence

- `/sys/block/<dev>/stat` resets on reboot
- Sampling too quickly (less than 0.5s) may give zero delta
- Use 1s sleep for smooth updates without UI flicker

### Icon Tile Overflows

- `min-width` too narrow for two icons
- Start with `42px`, adjust up/down based on icon sizes
- Icon font size `16px` (not `18px`) fits two icons comfortably

## Iteration Checklist

- [ ] Main disk icon (SSD/HDD) renders correctly
- [ ] Temperature badge appears and changes color
- [ ] Block bar fills proportionally to usage %
- [ ] I/O speeds update every 1s (no flicker)
- [ ] Outer box reads on both light/dark wallpapers
- [ ] All Unicode chars render in Waybar (test with fallback)
- [ ] Temperature class colors (good/warning/critical) work
- [ ] State coloring on info tile doesn't flash outer box

## Example Output

**Icon tile**: `SSD + temp-badge`
- Good (42°C): `󰋋` (teal)
- Warning (72°C): `󰋋󱈁` (orange)
- Critical (85°C): `󰋋󰀗` (pink)

**Info tile**:
```
█████░░░░░ 19%
↓0M/s  ↑0M/s
```

**State coloring**:
- Medium: gold tint
- Warning: orange tint
- Critical: pink tint

## Related Skills

- `auto-skill-waybar-nested-box`: The nested box CSS pattern used for group
- `auto-skill-waybar-script-debug`: Debugging silent script failures
- `auto-skill-waybar-module-sandbox`: Testing in dev bar before production

## Resources

- `/sys/block/<dev>/queue/rotational` — HDD vs SSD flag
- `/sys/block/<dev>/device/hwmon*/temp*_input` — NVMe temps (millidegrees C)
- `/sys/block/<dev>/stat` — I/O counters (sectors × 512 bytes)
- `df --output=size,used,avail,pcent /` — Disk usage
