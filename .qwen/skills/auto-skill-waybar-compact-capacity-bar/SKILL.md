---
name: waybar-compact-capacity-bar
description: Inline capacity bar with superscript labels, compact padding, and symbol continuation
source: auto-skill
---

# Waybar Compact Capacity Bar Pattern

Create inline-capacity bars for memory/disk modules with superscript labels and tight spacing.

## Visual Pattern

```
▓▓▓▓▓32G (superscript)
swap: 8.0G (normal row)
```

Key traits:
- Symbol: `▓` (filled), `·` (empty)
- Used label inline at boundary: `▓▓32G··· 64G`
- Total label at end: `▓▓32G··· 64G`
- Total as superscript: `<span size='smaller' rise='4000'>64G</span>`
- Compact padding: group `0 2px 0 4px`, info `0 4px 0`

## Script Structure

```bash
#!/bin/bash
# Compact inline capacity bar  usedG symbol totalG + swap row

read_meminfo() { ... }        # parse /proc/meminfo or similar
mt=${m[mt]}; ma=${m[ma]}      # mem total/available kB
used=$((mt - ma)); pct=$((used * 100 / mt))

# GiB conversion
total_gb=$((mt / 1048576))
ug=$((used / 1048576))

# 12-segment bar (adjust seg_total for density)
seg_total=12; seg_used=$((pct * seg_total / 100))
bar=""

# Hex for ▓ = e2 96 93, avoid write_file mangling
block=$(printf '\xe2\x96\x93')

if [ "$pct" -eq 100 ]; then
  # All filled: bar + superscript used label
  for ((i=0; i<seg_total; i++)); do
    bar+=$(printf "<span fgcolor='#<accent>'>%s</span>" "$block")
  done
  bar+=$(printf "<span fgcolor='#<accent>'><span size='smaller' rise='4000'>%dG</span></span>" "$ug")
else
  # Partial: used ▓ + used label + empty · + total superscript
  for ((i=0; i<seg_total; i++)); do
    if [ "$i" -eq "$seg_used" ]; then
      bar+=$(printf "<span fgcolor='#<accent>'><span size='smaller' rise='4000'>%dG</span></span>" "$ug")
    fi
    if [ "$i" -lt "$seg_used" ]; then
      bar+=$(printf "<span fgcolor='#<accent>'></span>")
    else
      bar+=$(printf "<span fgcolor='#383838'>·</span>")
    fi
  done
  bar+=$(printf "<span fgcolor='#383838' size='xx-small'> %dG</span>" "$total_gb")
fi

# Two-row output
line1="$bar"
line2=$(printf "<span fgcolor='#6c7086' size='small'>swap: %sG</span>" "$(awk ...)")
text=$(printf "%s\n%s" "$line1" "$line2")

jq -nc --arg text "$text" --arg cls "$cls" '{text:$text,class:$cls}'
```

## CSS Conventions

```css
/* Outer borderless box */
#group-<name> {
  background: transparent;
  border: none;
  padding: 0 2px 0 4px;
  margin: 0 4px;
}

/* Info tile: compact, blue accent */
#custom-<name>-info {
  font-size: 9px;
  padding: 0 4px 0 4px;
  border-radius: 6px;
  border: 1px solid rgba(137, 180, 250, 0.4);
  background: rgba(30, 30, 42, 0.85);
  color: #89b4fa;
}

/* No gap between bar and label */
#custom-<name>-info span[size='smaller'] {
  /* rise='4000' already in script */
}
```

## Key Gotchas

1. **Block char encoding**: Always use `\xe2\x96\x93` for `▓`, NOT literal character (write_file strips UTF-8)
2. **Superscript**: `<span size='smaller' rise='4000'>` not `<sup>x</sup>` (not supported by GTK Pango)
3. **No gap**: Don't add space before superscript label: `labelG</span>` directly after last block
4. **Total GB**: For 100% full, omit total label (redundant with used)

## Swap Row Styling

- Font size: `small` (not `xx-small`)
- Color: `#6c7086` (dim gray)
- Format: `swap: X.XG` (no total, just used)

## Integration Steps

1. Write script via heredoc (`cat > file << 'EOF'`), preserve hex escapes
2. Wire into `config` → bar's `modules-left/center/right`
3. Add CSS selector `#custom-<name>-info` with compact padding
4. Test with `jq . <script>` to verify Pango markup
5. Reload: `pkill -SIGUSR2 waybar`
