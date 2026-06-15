---
name: waybar-ram-module
description: RAM indicator with compact 8-segment bar + 2-row used/totalG layout
source: auto-skill
extracted_at: '2026-06-14T12:55:00.000Z'
---

# RAM Module — Inline Capacity Bar Pattern

**Use case**: Memory monitoring with inline capacity bar showing used/total, plus compact swap statistics.

## Visual Format

```
Row 1: ▓▓▓▓▓20.2G···30G   ← filled blocks + used label + empty blocks + total label
Row 2: swap:0.8G           ← swap used only, no total (xx-small, dim)
Icon:  󰍛                  ← RAM stick glyph (U+F035B)
```

**Key design:**
- ✅ **Inline capacity bar**: 8 segments with used label at boundary, total label at end
- ✅ **No percentages**: Absolute GB values only
- ✅ **Row 2 minimal**: Swap used G only, no total (total shown on bar end)
- ✅ **Compact spacing**: Tight padding (1px) and margin-right:0 for icon
- ✅ **Icon**: nf-md-memory (U+F035B `󰍛`) — distinct from SSD's disk icon
- ✅ **State colors**: Blue (#89b4fa) for medium, yellow/orange for warning, red for critical

## Script Pattern

```bash
#!/bin/bash
# RAM indicator — inline capacity bar + swap

# Parse /proc/meminfo (use kB for math, GiB only for display)
read -r mem_total_kb mem_available_kb < \
  <(awk '/MemTotal|MemAvailable/{print $2}' /proc/meminfo)

# Calculate usage percentage
used=$((mem_total_kb - mem_available_kb))
pct=$((used * 100 / mem_total_kb))

# Swap (handle missing swap gracefully)
swap_total_kb=$(awk '/SwapTotal/{t=$2} END{print t+0}' /proc/meminfo)
swap_free_kb=$(awk '/SwapFree/{f=$2} END{print f+0}' /proc/meminfo)
swap_used_kb=$((swap_total_kb - swap_free_kb))

# GiB 1 decimal (display only)
to_gib() { awk "BEGIN{printf \"%.1f\", $1/1024/1024}"; }
ug=$(to_gib "$used")
sw=$(to_gib "$swap_used_kb")
total_gb=$((mem_total_kb / 1048576))  # Total GB (integer, no decimal)

# 8-segment inline capacity bar with used label at boundary
seg_total=8
seg_used=$((pct * seg_total / 100))
bar=""

for ((i=0; i<seg_total; i++)); do
  # Inject used label at boundary between filled and empty
  if [ "$i" -eq "$seg_used" ]; then
    bar+=$(printf "<span fgcolor='#89b4fa'><b>%sG</b></span>" "$ug")
  fi
  
  if [ "$i" -lt "$seg_used" ]; then
    # Filled segment (color by state: blue for medium, then warm for warning/critical)
    bar+=$(printf "<span fgcolor='%s'>▓</span>" "$bc")
  else
    # Empty segment (dim)
    bar+=$(printf "<span fgcolor='#383838'>·</span>")
  fi
done

# 100% full boundary fix: inject label at end if never hit during loop
[ "$pct" -ge 100 ] && bar+=$(printf "<span fgcolor='%s'><b>%sG</b></span>" "$bc" "$ug")

# Total label at end (integer GB, dim)
bar+=$(printf "<span fgcolor='#383838' size='xx-small'>%dG</span>" "$total_gb")

# State class + color
if   [ "$pct" -ge 90 ]; then bc="#f38ba8"; cls="critical"
elif [ "$pct" -ge 75 ]; then bc="#f9e2af"; cls="warning"
elif [ "$pct" -ge 50 ]; then bc="#89b4fa"; cls="medium"
else bc="#a6e3a1"; cls="good"; fi

# Two-row Pango output
line1="$bar"
line2=$(printf "<span fgcolor='#585b70' size='xx-small'>swap: %sG</span>" "$sw")
text=$(printf "%s\n%s" "$line1" "$line2")

jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
```

**Critical: Real newlines**
Must use `$(printf "...")` to generate real newline bytes (0x0A). Bash double-quotes DON'T interpret `\n` as newline — it stays as literal backslash-n. Using `\n` directly in the script (e.g., `text="...\n..."`) will result in visible `\\n` text in the bar.

## Module Definition (qwen-modules.json)

```json
"group/qwen-ram": {
  "orientation": "horizontal",
  "modules": ["custom/qwen-ram-icon", "custom/qwen-ram-info"]
},
"custom/qwen-ram-icon": {
  "exec": "~/.config/waybar/scripts/qwen-ram-icon.sh",
  "interval": 5,
  "format": "{}",
  "return-type": "json"
},
"custom/qwen-ram-info": {
  "exec": "~/.config/waybar/scripts/qwen-ram-info.sh",
  "interval": 5,
  "format": "{}",
  "return-type": "json",
  "on-click": "gnome-system-monitor",
  "on-right-click": "free -h"
}
```

## Icon Pattern

Use `nf-md-memory` (U+F035B `󰍛`) — rectangular RAM stick with pins, distinct from SSD disk icon.

```bash
#!/bin/bash
# RAM icon — nf-md-memory (U+F035B) RAM stick
icon=$(printf '\xf3\xb0\x8d\x9b')
jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
```

**Byte sequence:** `f3 b0 8d 9b` (U+F035B `󰍛`)

**Important:** Never use literal UTF-8 characters in the script file. Always use `printf '\xXX\xXX...'` hex sequences. If `write_file` mangles the script, use heredoc instead to preserve literal characters.

**Important:** Never use literal UTF-8 characters in the script file. Always use `printf '\xXX\xXX...'` hex sequences.

## CSS Pattern

```css
/* Group wrapper — outer border/bg */
#group-qwen-ram {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(137, 180, 250, 0.4);
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}

/* Icon tile — transparent, no border */
#custom-qwen-ram-icon {
  font-size: 20px;
  min-width: 32px;
  padding: 2px 4px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: #89b4fa;
  margin-right: 2px;
}

/* Info tile — nested inner box */
#custom-qwen-ram-info {
  font-size: 11px;
  font-weight: 500;
  min-width: 0;
  padding: 2px 8px;
  border-radius: 6px;
  border: 1px solid rgba(137, 180, 250, 0.4);
  background: rgba(30, 30, 42, 0.85);
  color: #89b4fa;
}

/* State colors on info tile */
#custom-qwen-ram-info.medium  { background: rgba(249, 226, 175, 0.12); border-color: rgba(249, 226, 175, 0.4); }
#custom-qwen-ram-info.warning { background: rgba(250, 179, 135, 0.15); border-color: rgba(250, 179, 135, 0.5); }
#custom-qwen-ram-info.critical { background: rgba(243, 139, 168, 0.18); border-color: rgba(243, 139, 168, 0.55); }
```

**Class thresholds:** `good < 50%`, `medium 50-74%`, `warning 75-89%`, `critical ≥ 90%`.

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| Bar stretches tile too wide | Use 6-8 segments, not 12+ |
| Row 2 too verbose | Remove "RAM:" labels, show "used/totalG  swap:G" |
| Icon doesn't render | Use `printf '\xF3...` hex bytes, not literal UTF-8 |
| Swap not shown (no SwapTotal line) | Use `${m[st]:-0}` default to avoid unset error |
| Bar glyphs look identical | Use Pango `fgcolor` on both filled and empty glyphs |
| Bar height exceeds target | Use xx-small for row 2 labels, reduce group padding |

## Validation

```bash
# Test script output
bash scripts/qwen-ram-info.sh | jq -r '.text'

# Check CSS syntax
gtk-launch waybar 2>&1 | grep -i error

# Reload and verify
pkill -SIGUSR2 waybar
# Send screenshot to verify visual matches
```

## Why This Pattern?

1. **Compact vs verbose**: Row 2 shows what users actually need ("15G used") not redundant data ("RAM: 15G/30G")
2. **8-segment bar**: Gives good visual granularity without stretching the tile horizontally
3. **Color contrast**: Use colored glyphs (▓) + dim glyphs (▒) + Pango fgcolor so contrast is visible even if font fallback maps both to same glyph
4. **Row hierarchy**: Row 1 is the primary metric (bar + %), row 2 is secondary (absolute GB values)
5. **Height reality**: 2-row layout on 17px target bar expands to ~33px total — plan accordingly
