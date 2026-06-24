---
name: waybar-gtk-quirks
description: Waybar GTK CSS engine quirks: selector stripping, text-align crashers, color visibility traps
source: auto-skill
extracted_at: '2026-06-24T02:45:00.000Z'
---

# Waybar GTK CSS Engine Quirks

## Overview
Waybar uses GTK's CSS engine, which has significant differences from standard web CSS. These quirks can cause silent failures, invisible modules, or crashes if not handled correctly.

## Critical Quirk #1: `group/` Prefix is Stripped

### The Problem
When you define a group module in config like `"group/titlebox-row"`, the GTK widget ID becomes `#titlebox-row`, NOT `#group-titlebox-row`.

**Wrong (matches nothing):**
```css
window#waybar #group-titlebox-row {
    padding: 5px;
    background: rgba(0,128,128,0.12);
}
```

**Correct (matches actual widget):**
```css
#titlebox-row {
    padding: 5px;
    background: rgba(0,128,128,0.12);
}
```

### How to Verify
Run `waybar -l debug` and check the GTK widget tree:
```bash
waybar -c config-top -s style/top.css -l debug > logs/test.log 2>&1 &
sleep 2
grep "titlebox" logs/test.log
# Should show: box#titlebox-row.horizontal:dir(ltr)
# NOT: box#group-titlebox-row
```

### Pattern to Remember
| Config Definition | GTK Widget ID | CSS Selector |
|------------------|---------------|--------------|
| `group/titlebox-row` | `#titlebox-row` | `#titlebox-row` |
| `group/top-center` | `#top-center` | `#top-center` |
| `group/audio` | `#audio` | `#audio` |
| `group/bright` | `#bright` | `#bright` |
| `group/tray` | `#tray` | `#tray` |

**Rule**: Always check the debug log to see actual widget IDs before writing CSS.

## Critical Quirk #2: `text-align` Crashes GTK

### The Problem
GTK's CSS parser rejects `text-align` entirely, causing Waybar to exit with code 1 immediately.

**This crashes Waybar:**
```css
#power-profiles-daemon,
#custom-ext-display,
#idle_inhibitor {
    text-align: center;  /* ← Causes exit code 1 */
}
```

**Error in logs:**
```
[error] style-new.css:XXX:XX'text-align' is not a valid property name
unhandled exception (type Glib::Error) in signal handler
```

**Safe alternative:**
```css
#power-profiles-daemon,
#custom-ext-display,
#idle_inhibitor {
    /* No alignment needed - GTK aligns text left by default */
    /* If you need centered text, adjust padding/margins instead */
    text-align: inherit;  /* ← Never works, just omit */
}
```

**Note**: `text-align` is simply not supported in GTK CSS. If you encounter it in old configs, remove it.

## Critical Quirk #3: Color Visibility on Dark Backgrounds

### The Problem
Dark gray colors like `#6c7086` on dark backgrounds like `rgba(20,20,28,0.92)` are nearly invisible due to low contrast.

**Invisible pairing:**
```css
#custom-llama {
    color: #6c7086;  /* ← Almost invisible on dark bg */
    background: rgba(20, 20, 28, 0.92);
}
```

**Visible fix:**
```css
#custom-llama {
    color: #a6adc8;  /* ← Lighter, 250→280 in gray scale */
    background: rgba(20, 20, 28, 0.92);
}

#custom-llama.off {
    color: #89b4fa;  /* ← Use accent blue for "off" state */
}
```

### Safe Color Palette for Dark Backgrounds

**Never use on `rgba(20,20,28)` or similar:**
- ❌ `#6c7086` (too dark)
- ❌ `#45475a` (barely visible)
- ❌ `#313244` (invisible)

**Safe dark-on-dark colors:**
- ✅ `#cba6f7` (accent mauve)
- ✅ `#a6adc8` (light gray)
- ✅ `#89b4fa` (accent blue)
- ✅ `#f9e2af` (accent yellow)
- ✅ `#fab387` (accent peach)

**For "off" state, always use:**
- ✅ Accent colors (blue, peach, mauve)
- ✅ Bright whites (#cdd6f4)
- ❌ Never #6c7086 or darker

### Testing Color Visibility

```bash
# Check what colors you're using
grep -n "color: #" style/vertical.css | grep -E "6c7|454|313"

# If found, brighten them:
sed -i 's/#6c7086/#a6adc8/g' style/vertical.css
sed -i 's/#45475a/#6c7086/g' style/vertical.css
```

## Critical Quirk #4: Container Backgrounds and Dark Voids

### The Problem
Giving `.modules-center` a solid dark background OR transparent background both cause visual artifacts.

**Problem A: Solid bg causes dark void**
```css
.bar-vert .modules-center {
  background: rgba(25, 25, 38, 0.9);  /* ← GTK stretches this to full height */
}
```
**Result:** Massive dark void with barely visible modules at bottom.

**Problem B: Transparent also fails (GTK adds its own default bg)**
```css
.bar-vert .modules-center {
  background: transparent;  /* ← GTK internally adds default dark bg! */
  border: none;
  margin: 0;
  padding: 0;
}
```
**Result:** Dark void still appears - GTK's renderer adds its own background on top of `transparent`.

### The Final Solution: Consistent Explicit Backgrounds

**Always use explicit backgrounds for ALL zones:**
```css
/* ✅ Working pattern for ALL zones */
.bar-vert .modules-left,
.bar-vert .modules-center,
.bar-vert .modules-right {
  background: rgba(30, 30, 46, 0.85);  /* ← Explicit bg, no void */
  margin: 0px 2px;                      /* ← Tight margins */
  padding: 8px 4px;                     /* ← Small padding */
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.06);
}
```

### Why This Happens

**Key insight from June 24, 2026:**
- GTK's CSS renderer automatically adds a default dark background to `.modules-*` containers
- Setting `background: transparent` doesn't override this (GTK ignores it)
- Setting solid `background: rgba(...)` also gets stretched to fill space
- **Solution:** Give all zones the same explicit background (`rgba(30,30,46,0.85)`) so GTK doesn't add anything extra

### Testing the Fix

```bash
# Before fix - dark void visible
bar-vert .modules-center {
  background: transparent;  /* ← Dark void appears */
}

# After fix - consistent appearance
.bar-vert .modules-center {
  background: rgba(30, 30, 46, 0.85);  /* ← Dark void gone */
}
```

### Container Pattern (Updated June 24, 2026)

**All zones get the same treatment:**
```css
.bar-vert .modules-left,
.bar-vert .modules-center,
.bar-vert .modules-right {
  background: rgba(30, 30, 46, 0.85);  /* ← Explicit for all zones */
  margin: 0px 2px;
  padding: 8px 4px;
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.06);
}
```

**Individual module styling (inside containers):**
```css
/* Each module gets its own bg/border inside the container */
#custom-lang {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(137, 220, 235, 0.3);
  padding: 6px 10px;
}

#custom-ollama,
#custom-llama {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(255, 255, 255, 0.08);
  padding: 5px 6px;
}
```

**Result:** Clean visual separation between zones, no dark voids, modules clearly visible.

## Critical Quirk #5: Bar Height Bloat from Padding

### The Problem
GTK enforces computed box dimensions over requested bar height. Adding vertical padding to containers forces the bar to grow.

**Expected (browser CSS):**
```css
.bar-top .modules-right {
    padding: 6px 12px;
    margin: 2px 4px;
}
/* Expected: bar grows 16px */
```

**Reality (GTK Waybar):**
- 33px config → 50px+ rendered
- Every 2px of vertical padding = 4px height increase (2px top + 2px bottom)
- Users want horizontal spacing only

### Safe Pattern: Horizontal + Buffer Only

```css
/* ✅ CORRECT: minimal vertical padding */
.bar-top .modules-right {
    padding: 0px 12px;      /* ← 0px vertical, 12px horizontal */
    margin: 2px 3px;        /* ← Small vertical buffer */
    min-height: 0;          /* ← Force GTK to ignore */
    background: rgba(30,30,46,0.85);
}

.bar-top #battery {
    margin: 0 12px 0 0;     /* ← Horizontal spacing */
    padding: 0 8px;         /* ← Horizontal only */
    min-height: 0;          /* ← Force */
}
```

### Testing After Padding Changes

```bash
pkill -x waybar 2>/dev/null
sleep 0.5
waybar -c config-top -s style/top.css -l debug > logs/test.log 2>&1 &
sleep 2

tail logs/test.log | grep "Bar configured"
# Should show: "height: 33" or "height: 36" (acceptable)
# NOT: "height: 50" or higher
```

## Decision Matrix

| Symptom | Cause | Fix |
|---------|-------|-----|
| Colored bg not visible | Wrong selector (`#group-titlebox-row`) | Use `#titlebox-row` |
| Waybar crashes at startup | `text-align` in CSS | Remove all text-align |
| Module invisible | Color `#6c7086` on dark bg | Brighten to `#a6adc8` |
| Huge dark void in VC | `background: transparent` on center | **Use explicit `rgba(30,30,46,0.85)` for ALL zones** |
| Bar grows from 33→50px | Vertical padding | Use `min-height: 0` + horizontal padding |
| Modules disappear | Module stub override | Remove `exec: "echo ''"` blocks |

## Testing Checklist

Before any CSS changes:

- [ ] `waybar -l debug` shows correct widget tree (check for `group/` stripped IDs)
- [ ] No `text-align` in any CSS rule
- [ ] All text colors visible against their backgrounds
- [ ] **All zones use explicit backgrounds** - never `transparent`
- [ ] Container backgrounds match across all zones (`rgba(30,30,46,0.85)`)
- [ ] `min-height: 0` on all .modules-* containers

After changes:

- [ ] Top bar height: 33-36px (not 50px+)
- [ ] Bottom bar height: 11-15px
- [ ] **Vertical bar: all zones have consistent backgrounds, no dark voids**
- [ ] `.modules-center` shows modules clearly (no empty dark space)
- [ ] No GTK errors in logs
- [ ] All modules visible at their intended colors

## Related Quirks to Remember

- `sway/workspaces#bottom` → GTK ID is `#workspaces.bottom`, not `#bottom`
- `#group-audio` → GTK ID is `#group-audio`, `#group-bright` similarly
- Group wrappers preserve hyphens in IDs (`#titlebox-row` not `#titleboxrow`)
- Always verify with `grep "bar-" logs/waybar-*.log` for actual widget names

## Related Skills
- `auto-skill-waybar-gtk-box-model` — Padding vs bar height
- `auto-skill-waybar-module-override-guard` — Module stub conflicts
- `auto-skill-waybar-module-reorganization` — Config changes
