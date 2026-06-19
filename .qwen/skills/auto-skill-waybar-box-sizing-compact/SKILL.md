---
name: waybar-box-sizing-compact
description: Tighten vertical bar to 150px; icon 11px, info 108px, bars 6-seg GPU bar on row 1, MHz+temp on row 2
source: auto-skill
extracted_at: '2026-06-20T11:00:00.000Z'
tested_at: '2026-06-20'
---

## Summary

Waybar right bar starts too wide (~250px config for ~160px content). Apply progressive tightening. Result: bar hugs content at ~150px with 7 compact monitor groups.

Applied and verified on: `reliable-qwen` branch, `style-new.css` + `config-vertical` + `frame.sh` (2026-06-20).

## Sizing Table (Final)

| Selector                              | Property  | v1     | v2 (final) |
|---------------------------------------|-----------|--------|------------|
| `#custom/*-icon`, `#network-qwi`      | min-width | 28px→18px | **11px**   |
| same                                  | padding   | 2px 6px→2px 2px | **0 2px** |
| same                                  | margin    | 0 4px 0 6px→0 2px 0 4px | **0 1px 0 2px** |
| `#custom/*`, `#custom/*-info`         | min-width | 126px→110px | **108px** |
| same                                  | padding   | 2px 4px | **2px 3px** |
| `#group/*`                            | padding   | 2px 4px 2px 4px | **2px 3px 2px 3px** |
| `config-vertical`                     | width     | 250→200 | **150**  |

## Files to Edit

1. **`scripts/sysmon/frame.sh`** — GPU section: split bar+pct onto row 1, MHz+temp onto row 2
2. **`style-new.css`** — icon/info/group rules (all monitor + network groups)
3. **`config-vertical`** — top-level `width: 150`

## frame.sh GPU Section

```bash
# Row1 = bar+pct (compact), Row2 = MHz+temp
draw_module "" "${bar} ${pct}%" "${freq}MHz  ${temp}°C" "$ACCENT" "$cls"
```

This makes GPU content fit in ~105px max (instead of 130px), so all info cards share the `min-width: 115px` floor.

## CSS Rules

```css
/* Icon tiles — single-glyph width */
#custom-qwen-gpu-icon, #custom-qwen-cpu-icon, #custom-qwen-ram-icon,
#custom-qwen-ssd-icon, #custom-qwen-temp-icon, #custom-qwen-asus-icon,
#network-qwi {
  font-size: 16px;
  min-width: 11px;
  padding: 0 1px;
  margin: 0 0 0 1px;
}

/* Info cards — uniform 115px floor, content stretches wider when needed */
#custom-qwen-gpu, #custom-qwen-cpu, #custom-qwen-ram,
#custom-qwen-ssd, #custom-qwen-temp, #custom-qwen-asus,
#custom-qwen-wifi-info {
  font-weight: 500;
  border-radius: 6px;
  padding: 2px 2px;
  min-width: 108px;
  background: rgba(30, 30, 42, 0.85);
}

/* Group wrappers — symmetric tight padding */
#group-qwen-gpu, #group-qwen-cpu, #group-qwen-ram,
#group-qwen-ssd, #group-qwen-temp, #group-qwen-asus,
#group-qwen-network {
  padding: 2px 2px 2px 2px;
  margin: 2px 4px;
}
```

## config-vertical

```json
{ "name": "bar-vert", "width": 150, ... }
```

## Layout Math

- GPU bar+pct = 9 chars × 7px ≈ 55px (row 1)
- GPU MHz+temp = 15 chars × 7px ≈ 97px (row 2) → widest content
- Info card = max(115px min-width, 105px content) + 6px padding = **114px**
- Icon box = 14 + 0+2 + 1+2 = **16px**
- Full module = group-margin(8) + group-padding(6) + group-border(2) + icon(19) + icon-gap(1) + info(121) = **142px**
- Bar width 150 → **~6px total margin** (3px each side)

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

- Bar fits at ~150px, hugs all content
- All 7 info cards uniform at ~121px
- GPU split onto 2 compact rows
- No waybar CSS parse errors

## Git Commit Message

```
style: compact bar v2 — split GPU 2 rows, icon 11/info 108/bar 150
```
