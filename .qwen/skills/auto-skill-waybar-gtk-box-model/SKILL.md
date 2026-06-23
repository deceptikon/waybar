# Waybar GTK Box Model Workaround

## Overview
GTK's CSS engine used by Waybar enforces computed box dimensions over the requested bar height/width. Adding padding/margin to module containers causes the bar to grow beyond the configured height. This skill provides safe patterns for adding spacing without breaking bar dimensions.

## The Problem

**Expected behavior (browser CSS):**
```css
.bar-top .modules-right {
    padding: 6px 12px;
    margin: 2px 4px;
}
/* Result: bar height increases by 2×padding + 2×margin = 16px */
```

**GTK Waybar reality:**
- Vertical padding on containers **forces** bar height to increase
- `min-height` on container propagates to bar
- Result: 33px config → 50px rendered height (or more)
- User wants horizontal spacing only, not vertical growth

## When to Apply

Use these patterns when you need spacing but must maintain slim bar height:

1. **User asks for "more breathing room"** between modules on top bar
2. **Adding colored backgrounds** to groups that grow the height
3. **Horizontal margin increases** that push height beyond target
4. **Any padding changes** to `.modules-*` containers

## Safe Spacing Patterns

### ✅ Pattern: Horizontal margin only (no vertical padding)
```css
.bar-top .modules-right {
    padding: 0px 12px;    /* ← Zero V, max H */
    margin: 2px 3px;      /* ← 2px top/bottom, 3px left/right */
    min-height: 0;        /* ← Force 0 to counteract GTK */
    background: rgba(30,30,46,0.85);
    border: 1px solid rgba(255,255,255,0.06);
}

.bar-top #battery,
.bar-top #custom-keylight {
    margin: 0 12px 0 0;   /* ← Inter-module horizontal space */
    padding: 0 6px;       /* ← Optional horizontal breathing */
    min-height: 0;        /* ← Critical */
}
```

**Why it works:**
- `padding: 0px 12px` sets H only, V stays 0
- `margin: 2px 3px` adds small top/bottom buffer without forcing height
- `min-height: 0` tells GTK container not to enforce its own min-height
- Inter-module `margin: 0 12px 0 0` gives spacing between buttons

**Result:**
- Container grows slightly (margin: 2px up + 2px down = 4px)
- But individual modules stay tight (padding: 0, min-height: 0)
- Total bar height: 33px → ~36px (acceptable)

### ✅ Pattern: Colored group with zero vertical growth
```css
window#waybar #group-titlebox-row {
    padding: 1px 14px;    /* ← Minimal V, generous H */
    margin: 2px 4px;
    border-radius: 10px;
    background: rgba(0, 128, 128, 0.12);
    border: 1px solid rgba(148, 226, 213, 0.2);
    min-height: 0;        /* ← Must */
}

window#waybar #group-titlebox-row #scratchpad,
window#waybar #group-titlebox-row #privacy {
    margin-left: 8px;     /* ← Horizontal spacing only */
}
```

**Testing:**
```bash
waybar -c config-top -s style/top.css -l debug > logs/test.log 2>&1 &
sleep 2
grep "Bar configured" logs/test.log
# Should show "height: 36" or similar (not "height: 50")
```

### ❌ Don't: Vertical padding on containers
```css
/* ❌ BAD: This forces bar height up */
.bar-top .modules-right {
    padding: 6px 12px;    /* ← 6px top + 6px bottom = 12px */
    min-height: auto;     /* ← GTK ignores this, uses computed */
}
```

**Result:**
- Bar grows to 50+ px
- All modules stretch to fill
- User has "sacred desire" for slim bar

## GTK Waybox Gotchas

### Gotcha #1: `min-height: 0` is required on containers
```css
.bar-top .modules-right {
    /* Without this, GTK uses container's internal min-height */
    min-height: 0;  /* ← Tells GTK "use my requested height" */
}
```

### Gotcha #2: Individual modules also need `min-height: 0`
```css
.bar-top #battery,
.bar-top #custom-keylight {
    min-height: 0;  /* ← Modules inherit container height */
}
```

### Gotcha #3: `opacity: 0` doesn't collapse height in mode group
```css
/* ❌ OLD: titlebox-row hides during resize mode */
window#waybar:not(.mode-default) #group-titlebox-row {
    opacity: 0;  /* ← Still takes space */
}

/* ✅ NEW: Collapse it completely */
window#waybar:not(.mode-default) #group-titlebox-row {
    min-height: 0px;
    min-width: 0px;
    padding: 0px;
    margin: 0px;
    opacity: 0;
}
```

## Testing After Spacing Changes

```bash
# Clean test
pkill -x waybar 2>/dev/null
sleep 0.5

# Test top bar (most sensitive to padding)
waybar -c config-top -s style/top.css -l debug > logs/waybar-top.log 2>&1 &
sleep 2
tail -5 logs/waybar-top.log | grep -iE "error|Bar configured"
# Expected: height: 33-36px (not 48+ px)

# Test bottom bar
waybar -c config-bottom -s style/bottom.css -l debug > logs/waybar-bottom.log 2>&1 &
sleep 2
tail -5 logs/waybar-bottom.log | grep -iE "error|Bar configured"
# Expected: height: 11px (ultra-slim)

# Test vertical bar
waybar -c config-vertical -s style/vertical.css -l debug > logs/waybar-vertical.log 2>&1 &
sleep 2
tail -5 logs/waybar-vertical.log | grep -iE "error|Bar configured"
# Expected: height: ~1160px (vertical mode, less sensitive)
```

## Decision Matrix

**Want horizontal space between modules?**
→ Use `margin: 0 Xpx 0 0` on modules, `padding: 0px H` on container

**Want vertical space within container?**
→ ❌ Don't try, GTK will force bar height up anyway
→ ✅ Instead: reduce module font-size or icon size

**Want colored background for group?**
→ Add `background: rgba(...)` to group, but use `padding: 1px H` not `pad: 6px H`

**Want modules to "breathe"?**
→ Increase horizontal spacing with `margin-left: Xpx` on subsequent modules
→ Keep `min-height: 0` everywhere

## CSS Pattern Template

**Before (crowded, no spacing):**
```css
.bar-top .modules-right {
    padding: 0px 10px;
    margin: 0px 3px;
}
.bar-top #battery {
    margin: 0 6px 0 0;
    padding: 1px 4px;
}
/* Result: packed tight, hard to click */
```

**After (breathing room, no height bloat):**
```css
.bar-top .modules-right {
    padding: 0px 12px;      /* ← H only */
    margin: 2px 3px;        /* ← Small V buffer */
    min-height: 0;          /* ← Force */
}
.bar-top #group-bright,
.bar-top #battery {
    margin: 0 12px 0 0;     /* ← Generous H space */
    padding: 0 8px;         /* ← H only */
    min-height: 0;          /* ← Force */
}
/* Result: 33px → 36px height, modules have breathing room */
```

## Related Skills
- `auto-skill-css-cleanup` — Cross-references modules with CSS selectors
- `auto-skill-waybar-module-override-guard` — Prevents module stub conflicts
- `auto-skill-waybar-module-reorganization` — Module position changes

## When to Ask User
If user wants "more spacing" but bar height must stay slim, ask:

> **"Do you want horizontal breathing room between modules (spacing increases horizontally within 33px height), or are you okay with bar growing to ~50px?"**

This clarifies whether to:
- Use horizontal margin patterns (no height growth)
- Increase container vertical padding (accept 50px height)
