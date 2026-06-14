---
name: waybar-nested-box
description: Pattern for nesting modules inside a unified wrapper with individual inner borders
source: auto-skill
extracted_at: '2026-06-14T17:09:00.000Z'
---

# Nested Box Pattern for Waybar Groups

This skill covers creating a "box-in-a-box" layout where multiple modules are wrapped in a single outer border/background, while one or more child modules have their own inner border to create visual depth and separation.

## When to Use

Use this pattern when:
- You want multiple modules to appear as a unified unit (single outer border)
- One or more child modules need to stand out with their own inner border
- You need the icon/label to float freely inside the outer container
- You're creating a composite widget (e.g., wifi icon + SSID + speeds)
- The screenshot shows a nested box look (outer frame with inner tile)

## The Structure

### 1. Define a Group Wrapper Module

In your module JSON file (or `default-modules.json`), create a group that holds the child modules:

```json
{
  "group/qwen-network": {
    "orientation": "horizontal",
    "modules": [
      "custom/qwen-wifi-icon",
      "custom/qwen-wifi-info"
    ]
  }
}
```

### 2. Add Child Modules

```json
{
  "custom/qwen-wifi-icon": {
    "exec": "~/.config/waybar/scripts/wifi-big-icon.sh",
    "interval": 8,
    "format": "{}",
    "return-type": "json"
  },
  "custom/qwen-wifi-info": {
    "exec": "~/.config/waybar/scripts/qwen-wifi-info.sh",
    "interval": 10,
    "format": "{}",
    "return-type": "json"
  }
}
```

### 3. Include in Bar Config

```json
{
  "modules-left": [
    "group/qwen-network"
  ]
}
```

## The CSS Pattern

### Outer Box (Group)

The group container carries the outer border and background:

```css
/* Outer box: solid dark background so it reads on any wallpaper */
#group-qwen-network {
  background: rgba(20, 20, 28, 0.92);  /* Opaque-ish dark */
  border: 1px solid rgba(148, 226, 213, 0.4);
  border-radius: 8px;                   /* Rounded outer */
  padding: 2px 4px 2px 6px;             /* Tight padding */
  margin: 0 4px;
}
```

Key properties:
- **`background`**: High opacity (`0.92`) for visibility on light/dark wallpapers
- **`border-radius`**: Larger value (8px) for smooth outer curve
- **`padding`**: Asymmetric (`2px 4px 2px 6px`) to fine-tune alignment
- **`margin`**: Uniform spacing from other modules

### Inner Tile 1 (Icon — Transparent)

This module should have **no border/background**, so it "floats" inside the outer box:

```css
/* Icon tile: transparent inside the dark outer box */
#custom-qwen-wifi-icon {
  font-size: 18px;                      /* Large icon */
  min-width: 28px;
  padding: 2px 4px;
  border: none;                         /* No border */
  background: transparent;              /* No background */
  border-radius: 0;                     /* Reset radius */
  color: #94e2d5;                       /* Teal accent */
  margin-right: 2px;                    /* Gap to next tile */
}
```

Key properties:
- **`border: none`** and **`background: transparent`** — removes all internal styling
- **`border-radius: 0`** — ensures no inner rounding
- **`margin-right`** — adds breathing room before the next module

### Inner Tile 2 (Info — Nested Box)

This module keeps its own inner border to create the "box inside a box" effect:

```css
/* Info tile: nested box — slightly lighter to pop inside the outer box */
#custom-qwen-wifi-info {
  font-size: 12px;
  font-weight: 500;
  min-width: 0;
  padding: 2px 8px;
  border-radius: 6px;                   /* Slightly smaller than outer */
  border: 1px solid rgba(148, 226, 213, 0.4);
  background: rgba(30, 30, 42, 0.85);   /* Lighter than outer */
  color: #94e2d5;
}
```

Key properties:
- **`border-radius`**: Slightly smaller than outer (6px vs 8px) for depth
- **`background`**: Lighter than outer (`0.85` vs `0.92`) to pop
- **`border`**: Same color as outer, but inner tile's border is visible
- **`min-width: 0`** — lets content drive the width

### Per-State Coloring on Inner Tile

Add state-specific overrides for the inner tile (not the outer):

```css
#custom-qwen-wifi-info.medium  { background: rgba(249, 226, 175, 0.15); border-color: rgba(249, 226, 175, 0.45); color: #f9e2af; }
#custom-qwen-wifi-info.warning { background: rgba(250, 179, 135, 0.2);   border-color: rgba(250, 179, 135, 0.55); color: #fab387; }
#custom-qwen-wifi-info.critical { background: rgba(243, 139, 168, 0.2);  border-color: rgba(243, 139, 168, 0.55); color: #f38ba8; }
#custom-qwen-wifi-info.disconnected { background: rgba(100, 100, 100, 0.2); border-color: rgba(120, 120, 120, 0.4); color: #aaa; }
```

## Why This Works

- **Outer box** sets the visual frame and background — everything inside inherits its context
- **Transparent inner tile** doesn't compete — just sits inside the outer frame
- **Nested inner tile** creates depth — its own border and slightly lighter background make it readable against the outer bg
- **State coloring** only on the inner tile prevents flashing the outer frame

## Common Pitfalls

- **Don't** add `border` and `background` to both tiles — they'll stack visually and look messy
- **Don't** make the outer bg too transparent (`0.1`) — it won't read on light backgrounds
- **Don't** use `min-height` or `min-width` on the group — the children will expand it
- **Don't** forget `border-radius: 0` on the transparent tile — it'll inherit the group's radius and look wrong
- **Don't** use asymmetric `padding` on the group without testing — it can misalign the icon vertically

## Iteration Tips

1. **Adjust outer bg opacity**: Start with `0.92` for dark theme, lower to `0.8` if you want transparency
2. **Tune inner bg**: Make it lighter (higher alpha) to pop more, darker to blend more
3. **Icon size**: Start with `18px` for Nerd Font icons, increase if too small, decrease if too large
4. **Alignment**: If icon is vertically off-center, tune group `padding: top bottom left right`
5. **Spacing**: Group `padding: 2px 4px 2px 6px` + icon `margin-right: 2px` is a good starting point

## Example Before/After

### Before (No nesting)

Two separate bordered boxes side by side — looks disconnected.

```css
#custom-qwen-wifi-icon { border: 1px solid rgba(...); background: rgba(...); }
#custom-qwen-wifi-info { border: 1px solid rgba(...); background: rgba(...); }
```

### After (Nested boxes)

Single outer frame contains both — icon floats, info tile stands out.

```css
#group-qwen-network {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(148, 226, 213, 0.4);
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
}

#custom-qwen-wifi-icon {
  border: none;
  background: transparent;
}

#custom-qwen-wifi-info {
  background: rgba(30, 30, 42, 0.85);
  border: 1px solid rgba(148, 226, 213, 0.4);
  border-radius: 6px;
}
```

## Verification Checklist

- [ ] Group selector has outer border + high-opacity background
- [ ] Transparent tile has `border: none`, `background: transparent`, `border-radius: 0`
- [ ] Nested tile has lighter background than outer, smaller border-radius
- [ ] State variants only apply to the nested tile
- [ ] Group padding is asymmetric if icon needs fine alignment
- [ ] No `min-height` or `min-width` forcing the group to expand
- [ ] Tested on both light and dark wallpapers

## Related Skills

- `auto-skill-horizontal-bar-refactor`: Flattening groups and consistent spacing
- `auto-skill-waybar-module-sandbox`: Testing new modules in a dev bar
- `auto-skill-waybar-script-debug`: Debugging scripts that produce silent failures
- `auto-skill-waybar-ssd-module`: Composite SSD module (icon+temp + bar + I/O)

## Resources

- `qwen-modules.json` (or similar): Group and child module definitions
- `style.css`: Outer group + inner tile styling
- `scripts/<module>.sh`: Module output logic
