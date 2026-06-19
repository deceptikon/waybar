---
name: waybar-box-sizing-compact
description: Shrink icon+info box sizes for tight vertical bar; icon 18px, info 110px, bar width 200
source: auto-skill
extracted_at: '2026-06-20T08:10:00.000Z'
tested_at: '2026-06-20'
---

## Summary

When Waybar's right (vertical) bar is too wide — content occupies ~160px of a 250px bar — shrink icon tiles, info-card widths, and the bar's own `width` property in `config-vertical` so the bar hugs its content tightly.

Applied and verified on: `reliable` branch, `style-new.css` + `config-vertical` (2026-06-20).

## Sizing Table (Verified)

| Selector                    | Property        | Before     | After      |
|-----------------------------|-----------------|------------|------------|
| `*/*/*-icon`, `#network-qwi` | `min-width`     | 28px       | **18px**   |
| same                        | `padding`       | 2px 6px    | **2px 2px**|
| same                        | `margin`        | 0 4px 0 6px| **0 2px 0 4px** |
| `*/*/*-info`, `#custom-*`   | `min-width`     | 126px      | **110px**  |
| same                        | `padding`       | 2px 6px    | **2px 4px**|
| `#group/*`                  | `padding`       | 2px 4px 2px 6px | **2px 4px 2px 4px** |
| `config-vertical`           | `width`         | 250        | **200**    |

## Files to Edit

1. **`style-new.css`** — icon/info/group rules (all monitor + network groups)
2. **`config-vertical`** — top-level `width: 200`

## CSS Rules

```css
/* Icon tiles — single-glyph width */
#custom-qwen-gpu-icon, #custom-qwen-cpu-icon, #custom-qwen-ram-icon,
#custom-qwen-ssd-icon, #custom-qwen-temp-icon, #custom-qwen-asus-icon,
#network-qwi {
  font-size: 16px;
  min-width: 18px;
  padding: 2px 2px;
  margin: 0 2px 0 4px;
}

/* Info cards — same width, tight padding */
#custom-qwen-gpu, #custom-qwen-cpu, #custom-qwen-ram,
#custom-qwen-ssd, #custom-qwen-temp, #custom-qwen-asus,
#custom-qwen-wifi-info {
  font-weight: 500;
  border-radius: 6px;
  padding: 2px 4px;
  min-width: 110px;
  background: rgba(30, 30, 42, 0.85);
}

/* Group wrappers — symmetric padding */
#group-qwen-gpu, #group-qwen-cpu, #group-qwen-ram,
#group-qwen-ssd, #group-qwen-temp, #group-qwen-asus,
#group-qwen-network {
  padding: 2px 4px 2px 4px;
  margin: 2px 4px;
}
```

## config-vertical

```json
{
  "name": "bar-vert",
  "width": 200,
  ...
}
```

## Critical Warning

**Never add `text-align: left` to any CSS rule in Waybar.**
GTK's CSS subset does not accept this property, and Waybar exits with code 1 on first parse:

```
[error] style-new.css:121:12'text-align' is not a valid property name
```

GTK handles horizontal alignment via natural left alignment, so no override is needed.

## Reload

```sh
pkill waybar && sleep 1 && ~/.config/waybar/scripts/waybar-start.sh
```

## Verification

- Bar width shrinks to ~200px, hugging content
- Icon column and info column form a straight vertical edge
- All 7 monitor groups match in width
- `way-bar --log-level=error` shows no CSS errors
