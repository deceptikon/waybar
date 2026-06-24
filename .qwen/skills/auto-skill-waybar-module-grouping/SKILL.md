---
name: waybar-module-grouping
description: Restructure flat button lists into functional paired groups
source: auto-skill
extracted_at: '2026-06-24T04:00:00.000Z'
---

# Waybar Module Grouping: From Flat List to Functional Pairs

## Overview
When users complain "buttons became unusable" or "need to restructure groups", the solution is to replace flat module lists with semantic functional groups (power, ai, capture, sys). This skill provides the pattern for reorganizing 8+ thin toggle buttons into 4 logical paired groups with dividers and state highlights.

## The Problem

**Before (flat list — unusable):**
```json
"modules-right": [
  "custom/dunst",
  "custom/fnlock",
  "custom/recorder",
  "custom/checkupdates",
  "custom/ollama",
  "custom/llama",
  "idle_inhibitor",
  "custom/ext-display"
]
```

- Each module renders as a separate 24×26px button
- No logical grouping → users can't find what they need
- State highlights apply to flat labels, not semantic groups
- No visual separation between unrelated functions

**After (grouped — usable):**
```json
"modules-right": [
  "group/vr-power",      // idle_inhibitor | ext-display
  "group/vr-ai",         // ollama | llama
  "group/vr-capture",    // recorder | dunst
  "group/vr-sys"         // fnlock | checkupdates
]
```

- Each group is a single 72×24px clickable unit with inner divider
- Semantic labeling → "power" vs "AI" vs "capture"
- State highlights work on inner modules with clean CSS

## Group Definition Pattern

### Step 1: Define groups in modules-*.json
```json
{
  "group/vr-power": {
    "orientation": "horizontal",
    "modules": ["idle_inhibitor", "custom/ext-display"]
  },
  "group/vr-ai": {
    "orientation": "horizontal",
    "modules": ["custom/ollama", "custom/llama"]
  },
  "group/vr-capture": {
    "orientation": "horizontal",
    "modules": ["custom/recorder", "custom/dunst"]
  },
  "group/vr-sys": {
    "orientation": "horizontal",
    "modules": ["custom/fnlock", "custom/checkupdates"]
  }
}
```

**Key details:**
- `orientation: "horizontal"` — side-by-side placement
- Module order matters — left half (1st) vs right half (2nd)
- Groups are defined in the included JSON file, not directly in config

### Step 2: Update bar config to use groups
```json
{
  "config-vertical": {
    "modules-right": [
      "group/vr-power",
      "group/vr-ai",
      "group/vr-capture",
      "group/vr-sys"
    ]
  }
}
```

**Don't add individual modules** — GTK Waybar will render both the group AND its children.

## CSS Pattern for Grouped Controls

### Group container styling
```css
#group-vr-power,
#group-vr-ai,
#group-vr-capture,
#group-vr-sys {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  margin: 4px 4px;
  padding: 2px 8px;
  min-width: 72px;  /* ← One button width (36px) + padding (16px) + divider (1px) */
}

/* Inner spacer reset */
#group-vr-power > widget,
#group-vr-ai > widget,
#group-vr-capture > widget,
#group-vr-sys > widget {
  margin: 0;
  padding: 0;
}

/* Inner module styling */
#group-vr-power > widget > label,
#group-vr-ai > widget > label,
#group-vr-capture > widget > label,
#group-vr-sys > widget > label {
  background: transparent;
  border: none;
  border-radius: 0;
  margin: 0;
  padding: 6px 5px;
  font-size: 14px;
  color: #a6adc8;
  min-height: 20px;
}
```

### Inner divider between paired halves
```css
/* Left child gets right border */
#group-vr-power   #idle_inhibitor,
#group-vr-ai      #custom-ollama,
#group-vr-capture #custom-recorder,
#group-vr-sys     #custom-fnlock {
  padding-right: 8px;
  border-right: 1px solid rgba(255, 255, 255, 0.06);
}
```

**Why this works:**
- GTK doesn't support grid/flexbox — we simulate it with CSS borders
- `border-right` on first child creates the visual divider
- `padding-right: 8px` gives breathing room before divider

### State highlights (GTK CSS quirk: use ID, not label#ID)
```css
/* ❌ WRONG: label#idle_inhibitor.activated (GTK can't parse) */
/* ✅ CORRECT: #idle_inhibitor.activated */

#idle_inhibitor.activated,
#custom-ext-display.on,
#custom-ollama.on,
#custom-llama.on,
#custom-dunst.paused {
  color: #94e2d5;
}

#custom-recorder.recording {
  color: #f38ba8;
}

#custom-checkupdates.active {
  color: #a6e3a1;
}

#custom-ollama.off,
#custom-llama.off,
#custom-ext-display.off {
  color: #585b70;
}
```

**Critical GTK quirk:**
- GTK CSS engine doesn't recognize `label#id.class` selectors
- Must use bare ID selectors: `#id.class` (no `label#` prefix)
- State classes are applied to the module, not child labels

## Functional Group Categories

### Power group
**Modules:** `idle_inhibitor` | `custom/ext-display`  
**Use case:** Screen-related controls — prevents sleep, toggles external display

### AI group
**Modules:** `custom/ollama` | `custom/llama`  
**Use case:** Runtime status indicators — both show UP/DOWN classes from JSON exec

### Capture group
**Modules:** `custom/recorder` | `custom/dunst`  
**Use case:** Recording + notifications — recorder records, dunst pauses notifications

### System group
**Modules:** `custom/fnlock` | `custom/checkupdates`  
**Use case:** System toggles — fn key lock, update count

## Common Issues & Fixes

### Issue 1: Buttons still appear as separate flat buttons
**Symptom:** Group doesn't render as a single unit  
**Fix:** Check group is defined in included JSON file, and bar config uses `group/name`

```bash
# Verify group definition exists
grep -n '"group/vr-' modules-controls.json

# Verify config uses the group (NOT individual modules)
grep -n "group/vr-" config-vertical
```

### Issue 2: Dividers not showing
**Symptom:** Two modules side-by-side with no separator  
**Fix:** Ensure left child selectors have correct parent group prefix

```css
/* ❌ WRONG: #idle_inhibitor { border-right: ... } */
/* ✅ CORRECT: #group-vr-power #idle_inhibitor { border-right: ... } */
```

### Issue 3: State highlights don't apply
**Symptom:** #idle_inhibitor.activated doesn't colorize  
**Fix:** Remove `label#` prefix from selectors

```bash
# Check current CSS
grep "label#" style/vertical.css  # Should be empty after fix

# Check state classes are defined
grep -A2 "idle_inhibitor:" modules-controls.json
```

## Testing After Grouping

```bash
# Clean test
pkill -x waybar 2>/dev/null; sleep 0.3

# Test vertical (grouped) bar
waybar -c config-vertical -s style/vertical.css -l debug > logs/waybar-vertical.log 2>&1 &
sleep 2

# Check no errors
grep -E "error|config for 'group" logs/waybar-vertical.log | tail -5
# Should be empty (no "no configuration for group/vr-*" warnings)

# Check module tree
grep "box#group-vr-" logs/waybar-vertical.log
# Should show 4 group boxes: #group-vr-power, #group-vr-ai, #group-vr-capture, #group-vr-sys
```

## When to Use Groups

**Use functional groups when:**
- User says "buttons became unusable" or "restructure groups"
- You have 6+ toggle buttons on a single axis (VR in vertical bar)
- Modules naturally pair (status + control, left + right halves)
- You want to add visual dividers between related functions

**Don't use groups when:**
- Modules are already semantic (monitor groups like #group/qwen-gpu)
- Only 2-3 modules total (just use spacing, not groups)
- Modules don't logically pair (e.g., mixing unrelated functions)

## Alternative: Group in VL (monitor groups)

For the vertical left zone, groups follow a different pattern (card + icon):

```json
{
  "group/qwen-gpu": {
    "orientation": "horizontal",
    "modules": ["custom/qwen-gpu-icon", "custom/qwen-gpu"]
  }
}
```

```css
#group-qwen-gpu {
  border-left: 3px solid #fab387;  /* Accent color */
  margin: 8px 4px;                  /* Breathing room */
}
```

But for VR controls, use the **powered-by-gaps** divider pattern instead.

## Related Skills
- `auto-skill-waybar-module-reorganization` — Moving modules between bars
- `auto-skill-waybar-gtk-quirks` — label# vs # selector fix
- `auto-skill-waybar-module-override-guard` — Avoiding orphaned module def conflicts

## Commit Template

```
Reorg: restructure VR buttons into 4 functional groups

**Changes:**
- Define 4 groups in modules-controls.json: vr-power, vr-ai, vr-capture, vr-sys
- Update config-vertical.modules-right to use groups (NOT individual modules)
- Add group container CSS: 72px min-width, bg, border, rounded corners
- Add inner divider pattern: left-child { border-right: 1px rgba(...) }
- Fix state selectors: remove label# prefix, use #id.class instead
- Test: verify groups render as 4 units, not 8 flat buttons

**Notes:**
- State classes: .activated, .on, .recording, .active, .off
- Color palette: #94e2d5 (highlight), #f38ba8 (recording), #a6e3a1 (updates)
- Inner modules keep transparent backgrounds (group bg shows through)
```
