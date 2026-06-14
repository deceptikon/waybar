---
name: waybar-system-module
description: Building CPU+RAM unified module with icon + two-row stats bar
source: auto-skill
extracted_at: '2026-06-14T17:45:00.000Z'
---

# Waybar CPU+RAM Unified Module Pattern

This skill covers creating a composite CPU/ RAM module with a single chip icon tile and a two-row stats tile containing Pango-colored bars, temperature, and memory usage. The module follows the same nested-box pattern as the SSD and WiFi modules.

## When to Use

Use this pattern when:
- You want to show CPU% + RAM% in a compact unified layout
- You need per-unit colored bars (blue for CPU, purple for RAM)
- You want to include CPU temperature with state-aware coloring
- You want a single icon tile to represent "system" or "CPU+RAM"
- You're building a module that needs live sampling (0.5s CPU delta, 5s RAM)
- The screenshot shows two-row formatting: "CPU bar+pct+temp" / "RAM bar+pct+used/total"

## The Structure

### 1. Define Group Wrapper

In your module JSON file (or `default-modules.json`):

```json
{
  "group/qwen-system": {
    "orientation": "horizontal",
    "modules": [
      "custom/qwen-system-icon",
      "custom/qwen-system-info"
    ]
  },
  "custom/qwen-system-icon": {
    "exec": "~/.config/waybar/scripts/qwen-system-icon.sh",
    "interval": 5,
    "format": "{}",
    "return-type": "json"
  },
  "custom/qwen-system-info": {
    "exec": "~/.config/waybar/scripts/qwen-system-info.sh",
    "interval": 5,
    "format": "{}",
    "return-type": "json",
    "on-click": "htop",
    "on-right-click": "gnome-system-monitor"
  }
}
```

Key choices:
- **Same interval (5s)** for both icon and info (CPU benefits from live updates, icon changes rarely but benefits from consistency)
- **on-click: htop** for quick stats, **on-right-click: gnome-system-monitor** for deep diagnostics
- **interval: 5** for info (CPU sampling needs frequent refresh), icon can be slower but matched for simplicity

### 2. Icon Tile Script — Single Unicode Glyph

Use `printf` with literal UTF-8 bytes for Nerd Font icon stability:

```bash
#!/bin/bash

# System icon tile — single chip icon (CPU+RAM unified)
# Uses printf with exact UTF-8 bytes (Monaspace Nerd Font glyphs)

DEVICE=$(df / | tail -1 | awk '{print $1}')

# nf-mdi-chip = U+F0145 bytes: f3 b0 85 85  (system/processor chip)
icon=$(printf '\xf3\xb0\x85\x85')

jq -n --compact-output \
  --arg txt "$icon" \
  '{text: $txt, class: "icon"}'
```

Key principles:
- **Literal UTF-8 bytes**: `printf '\xf3\xb0\x85\x85'` ensures the icon survives shell parsing and Waybar rendering
- **No variable interpolation**: Keep the script simple, just output the glyph
- **Single line text**: Waybar won't split this into rows
- **Class: "icon"**: Simple placeholder for CSS styling

### 3. Info Tile Script — Two-Row Pango

This is where the heavy lifting happens:

```bash
#!/bin/bash

# System info tile — CPU% + RAM% with colored bars

# === CPU usage — 2-s sampling of /proc/stat (field 5 = idle) ===
read_cpu_sample() {
  awk '/^cpu / {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; print tot, idle}' /proc/stat
}
total1=0; idle1=0; total2=0; idle2=0
{ read total1 idle1; } < <(read_cpu_sample)
sleep 0.5
{ read total2 idle2; } < <(read_cpu_sample)
dt=$((total2 - total1))
[ "$dt" -le 0 ] && dt=1
cpu_pct=$(( (dt - (idle2 - idle1)) * 100 / dt ))
[ "$cpu_pct" -lt 0 ] && cpu_pct=0
[ "$cpu_pct" -gt 100 ] && cpu_pct=100

# === RAM usage ===
mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))
mem_pct=$((mem_used * 100 / mem_total))
mem_used_g=$(awk "BEGIN{printf \"%.1f\", $mem_used/1024/1024}")
mem_total_g=$(awk "BEGIN{printf \"%.1f\", $mem_total/1024/1024}")

# === CPU temperature (thermal zone) ===
cpu_temp=0
if [ -d /sys/class/thermal ]; then
  for tz in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$tz" ] || continue
    t=$(cat "$tz" 2>/dev/null || echo "0")
    t=$((t / 1000))
    [ "$t" -gt 99 ] && continue   # ignore outliers
    cpu_temp=$t; break
  done
fi

# Fallback: try hwmon if thermal zone didn't yield a sensible value
if [ "$cpu_temp" -eq 0 ]; then
  for hw in /sys/class/hwmon/hwmon*/temp1_input; do
    [ -r "$hw" ] || continue
    t=$(cat "$hw" 2>/dev/null || echo "0")
    t=$((t / 1000))
    [ "$t" -gt 0 ] && [ "$t" -lt 99 ] && { cpu_temp=$t; break; }
  done
fi
```

Key principles:
- **CPU**: Sample `/proc/stat` twice with `sleep 0.5`, compute delta for real CPU%
- **RAM**: Static read from `/proc/meminfo` (no sampling needed)
- **Temp**: First thermal zone under 100°C, fall back to hwmon if needed
- **Guard against edge cases**: `[ "$dt" -le 0 ] && dt=1` prevents division by zero
- **Unit conversion**: `awk` for GB formatting with one decimal

#### Build Pango-Colored Bars

Use Pango `<span fgcolor=''>` so even identical glyphs (▓/▒) have different colors:

```bash
# === Build mini bar (8 segments) ===
make_bar() {
  local pct=$1 fg=$2
  local filled=$((pct * 8 / 100))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  local empty=$((8 - filled))
  local f e
  [ "$filled" -gt 0 ] && f=$(printf '▓%.0s' $(seq 1 $filled)) || f=""
  [ "$empty" -gt 0 ]  && e=$(printf '░%.0s' $(seq 1 $empty))  || e=""
  echo "<span fgcolor='$fg'>$f</span><span fgcolor='#444'>$e</span>"
}

cpu_bar=$(make_bar $cpu_pct '#89b4fa')   # blue for CPU
ram_bar=$(make_bar $mem_pct '#cba7f7')   # purple for RAM

# Temp-color helper
temp_cls() {
  local t=$1
  if   [ "$t" -ge 90 ]; then echo "critical"
  elif [ "$t" -ge 80 ]; then echo "warning"
  elif [ "$t" -ge 70 ]; then echo "medium"
  else echo "good"; fi
}
temp_color() {
  local t=$1
  if   [ "$t" -ge 90 ]; then echo "#f38ba8"
  elif [ "$t" -ge 80 ]; then echo "#fab387"
  elif [ "$t" -ge 70 ]; then echo "#f9e2af"
  else echo "#a6e3a1"; fi
}
```

Key principles:
- **8 segments**: Compact bar that fits in 17px bar height
- **Pango colors**: #89b4fa (blue) for CPU, #cba7f7 (purple) for RAM, #a6e3a1/#fab387/#f38ba8 for temp
- **Dark filler**: #444 for empty segments
- **temp_cls**: Returns state class for CSS state variants

#### Calculate Overall Class and Output

Combine worst of CPU%, RAM%, and temperature:

```bash
# Overall class: worst of cpu% / ram% / temp
rank_cls() { case "$1" in good)echo 0;; medium)echo 1;; warning)echo 2;; critical)echo 3;; *)echo 0;; esac; }
unrank() { case "$1" in 0)echo good;; 1)echo medium;; 2)echo warning;; 3)echo critical;; esac; }
pct_rank() {
  local p=$1
  if   [ "$p" -ge 90 ]; then echo 3
  elif [ "$p" -ge 75 ]; then echo 2
  elif [ "$p" -ge 50 ]; then echo 1
  else echo 0; fi
}
r_cpu=$(pct_rank $cpu_pct); r_ram=$(pct_rank $mem_pct); r_tmp=$(rank_cls "$temp_cls")
maxr=$r_cpu; [ "$r_ram" -gt "$maxr" ] && maxr=$r_ram; [ "$r_tmp" -gt "$maxr" ] && maxr=$r_tmp
overall=$(unrank $maxr)

# Two-row Pango layout:
#   Row 1: CPU  bar  pct%  temp
#   Row 2: RAM  bar  pct%  used/total
text=$(printf "<span size='small'>CPU</span> %s <b>%d%%</b>  <span fgcolor='%s'>%d°C</span>\n<span size='small'>RAM</span> %s <b>%d%%</b>  <span>%s/%sG</span>" \
  "$cpu_bar" "$cpu_pct" "$t_color" "$cpu_temp" \
  "$ram_bar" "$mem_pct" "$mem_used_g" "$mem_total_g")

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$overall" \
  '{text: $text, class: $cls}'
```

Key principles:
- **Two-row format**: `\n` in Pango text creates paragraph break
- **size='small'**: Reduces font for labels ("CPU", "RAM")
- **<b>**: Bold for percentage values
- **Overall class**: Worst of CPU%, RAM%, temp drives the info tile style
- **Final output**: Single JSON with `text` (Pango markup) and `class`

## The CSS Pattern

### Outer Box (Group)

Use the nested-box pattern from `auto-skill-waybar-nested-box`:

```css
/* --- System group — CPU+RAM unified, blue accent --- */
#group-qwen-system {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(137, 180, 250, 0.4);
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}
```

### Icon Tile (Transparent)

Match the SSD icon size for consistency across modules:

```css
#custom-qwen-system-icon {
  font-size: 20px;
  min-width: 32px;
  padding: 2px 4px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: #89b4fa;   /* Blue to match CPU bar */
  margin-right: 2px;
}
```

### Info Tile (Nested Box)

This is the two-row stats tile with inner border:

```css
#custom-qwen-system-info {
  font-size: 11px;    /* Smaller font for two rows */
  font-weight: 500;
  min-width: 0;
  padding: 2px 8px;
  border-radius: 6px;
  border: 1px solid rgba(137, 180, 250, 0.4);
  background: rgba(30, 30, 42, 0.85);
  color: #89b4fa;
  line-height: 1.1;   /* Tight leading for two rows */
}

#custom-qwen-system-info.medium  { background: rgba(249, 226, 175, 0.12); border-color: rgba(249, 226, 175, 0.4); }
#custom-qwen-system-info.warning { background: rgba(250, 179, 135, 0.15); border-color: rgba(250, 179, 135, 0.5); }
#custom-qwen-system-info.critical { background: rgba(243, 139, 168, 0.18); border-color: rgba(243, 139, 168, 0.55); }
```

Key properties:
- **font-size: 11px**: Smaller than SSD/WiFi (12px) to fit two rows
- **line-height: 1.1**: Tight leading prevents row separation
- **color: #89b4fa**: Blue to match CPU bar, distinct from RAM (#cba7f7)
- **Per-state variants**: medium/warning/critical override bg/border only (not color)

## Why This Works

- **Single icon tile**: 20px icon represents "system" (CPU+RAM unified)
- **Two-row stats**: Pango `\n` creates two lines in one module
- **Pango-colored bars**: CPU and RAM bars use distinct colors (#89b4fa, #cba7f7)
- **Temperature**: Shows alongside CPU%, colored by temp state
- **Overall class**: Drives info tile style (border/bg) to warn when any stat is high
- **line-height: 1.1**: Keeps rows tight so the module stays compact (fits in 33px dev bar)

## Script Debugging Tips

### CPU % calculation fails

Common error: `arithmetic syntax error in expression (error token is "52163488 50769583")`

**Cause**: `mapfile` or array subscript fails; awk output isn't parsed correctly.

**Fix**: Use inline assignment with `read`:

```bash
{ read total1 idle1; } < <(read_cpu_sample)
```

### Division by zero

Common error: `division by 0 (error token is "dt ")`

**Cause**: `total2 - total1` is 0 (CPU idle for 0.5s).

**Fix**: Guard with `[ "$dt" -le 0 ] && dt=1`

### Temperature doesn't show

Common cause: Thermal zone returns value > 100°C, filtered out.

**Fix**: Add hwmon fallback or lower the threshold

## Iteration Checklist

- [ ] Icon renders at correct size (start with 18-20px)
- [ ] Two rows render without spacing (line-height: 1.1)
- [ ] CPU bar in blue, RAM bar in purple
- [ ] Temperature color matches state (green/amber/orange/red)
- [ ] Overall class triggers state variants
- [ ] Module stays compact (doesn't force bar > 33px)
- [ ] Scripts output valid JSON
- [ ] Tested with low and high CPU/RAM loads

## Common Pitfalls

- **Don't** use `mapfile` for single-line output — use `read` with process substitution
- **Don't** forget `line-height: 1.1` or tighter — two rows will look like they're falling apart
- **Don't** use different font sizes for the two rows — Pango inherits font-size from parent
- **Don't** make the icon too small (14px) — Nerd Font icons need 18-20px to render correctly
- **Don't** let the bar exceed target height — reduce segments from 12→8→6 if needed

## Example: Layout Comparison

| Module | Icon Size | Font | Segments | Rows |
|---|---|---|---|---|
| WiFi | 18px | 12px | 4 | 1 |
| SSD | 20px | 11px | 4 | 1 |
| System | 20px | 11px | 8 | 2 |

System uses more segments because there's more data to show, but stays compact by using smaller font and tight line-height.

## Related Skills

- `auto-skill-waybar-nested-box`: Outer + inner border pattern
- `auto-skill-waybar-script-debug`: Script failure patterns
- `auto-skill-waybar-ssd-module`: Composite module with icon + bar + I/O
- `AGENTS.md`: Waybar conventions
- `STRUCT.md`: Module documentation

## Resources

- `scripts/qwen-system-icon.sh`: Single glyph icon
- `scripts/qwen-system-info.sh`: Two-row Pango stats
- `qwen-modules.json`: Group + child module definitions
- `style.css`: Outer box + icon + nested info tile styling
- `/proc/stat`, `/proc/meminfo`, `/sys/class/thermal`, `/sys/class/hwmon`: Data sources
