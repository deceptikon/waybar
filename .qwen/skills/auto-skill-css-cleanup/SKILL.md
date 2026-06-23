# Waybar CSS Cleanup Methodology

## Overview
Systematic approach to identify and remove dead CSS, consolidate bar-specific styles, and maintain a clean separation of concerns across multiple Waybar bars.

## When to Apply
- After reorganizing configuration files
- When CSS files become bloated (>1000 lines)
- Before merging configuration changes
- Periodic maintenance (quarterly)

## Procedure

### 1. **Analyze Current State**
```bash
# Review all config files first
head -50 config-top config-top-base.jsonc config-bottom config-vertical modules-*.json

# Count CSS lines per file
wc -l style/base.css style/*.css

# Check for bar-specific selectors
grep -r "bar-top\|bar-vert\|bar-bottom" style/*.css
```

### 2. **Identify Dead Code**
For each CSS file, identify:

**A. Unused bar classes**
- Look for `.bar-horiz`, `.bar-vertical` when no config uses those names
- Check `waybar -c <config> -s <css>` logs for undefined selectors

**B. Orphaned module styles**
- Cross-reference `modules-*.json` `include` lists vs CSS selectors
- Example: if `config-top` includes `modules-controls.json`, rules like `#idle_inhibitor` without matching module should be removed

**C. Duplicate selectors across files**
- Run: `grep -h "#workspaces\|#battery\|#custom-" style/*.css | cut -d'{' -f1 | sort | uniq -d`
- These indicate potential consolidation opportunities

**D. Bar-specific styles in shared files**
- `.bar-top .modules-*` rules don't belong in base.css
- Bottom bar workspace lines should only be in bottom.css

### 3. **Test Incrementally**
Never rewrite entire CSS at once:

```bash
# Step 1: Remove dead code from base.css
# Step 2: Rebuild only top bar
waybar -c config-top -s style/top.css -l debug
tail logs/waybar-top.log | grep -E "error|Configured"

# Step 3: If clean, move to bottom
waybar -c config-bottom -s style/bottom.css -l debug
tail logs/waybar-bottom.log | grep -E "error|Configured"

# Step 4: Verify vertical
waybar -c config-vertical -s style/vertical.css -l debug
tail logs/waybar-vertical.log | grep -E "error|Configured"
```

### 4. **Consolidate Per-Bar Chrome**
Move bar-specific containers into bar CSS files:

```
# ❌ base.css (shared)
.bar-top .modules-left { ... }
.window.bar-bottom { ... }

# ✅ base.css (clean)
* { min-height: 0; }
#workspaces button { ... }

# ✅ style/top.css
.bar-top .modules-left,
.bar-top .modules-center,
.bar-top .modules-right { ... }

# ✅ style/bottom.css
window#bar-bottom { ... }
#bottom button { ... }
```

### 5. **Fix Common Gotchas**

**Selector specificity pitfalls:**
```css
/* ❌ Won't work - base.css rules have higher specificity */
#workspaces button { min-height: 20px; }  /* in base.css */
#bottom button { min-height: 2px; }       /* in bottom.css - ignored */

/* ✅ Fix: Use ID selector for bottom bar */
#bottom button { 
    min-height: 2px; 
    opacity: 0.25;
}
```

**GTK Waybar quirk:**
- `sway/workspaces#bottom` → GTK CSS ID is `#bottom`, not `#workspaces.bottom`
- Test with `waybar -l debug` to see actual widget tree

### 6. **Verify No Regressions**
After cleanup:
- All 3 bars load without errors
- Heights match config (no warnings like "Requested height X is less than minimum Y")
- No duplicate module definitions
- No orphaned color variables

## Cleanup Summary Template

When committing, document with:

**Before:**
- base.css: XXX lines with {.bar-horiz, .solo, #window, sysmon groups}
- top.css: {window.solo, redundant overrides}
- bottom.css: orphaned rules from base.css

**After:**
- base.css: {universal only, minimal shared}
- top.css: bar-top specific
- bottom.css: standalone, fixed `#bottom` selector

**Net change:** -XXX lines, +XX lines

## Common Patterns Removed

| Pattern | Reason |
|---------|--------|
| `.bar-horiz` | No bar uses this class |
| `window#waybar.solo/.floating/.tiled` | Sway states not in config |
| `#window` with `.solo` styles | Waybar doesn't generate `#window` |
| Sysmon groups in base.css | Vertical.css has own implementation |
| `@keyframes wait` | Never used |
| Bottom bar styles in base.css | Belong in bottom.css |

## Testing Checklist

- [ ] Top bar: height 33px, no errors
- [ ] Bottom bar: minimal height (~11px), colorful line workspaces
- [ ] Vertical bar: height ~1150px, sysmon groups styled
- [ ] All modules load (no "module not found" errors)
- [ ] No GTK warnings about minimum height/width
- [ ] Config reload works via `waybar-start.sh reload`

## Related Tools
- `waybar -l debug` - shows widget tree, confirms selector mapping
- `tail logs/waybar-<name>.log` - check for errors
- `grep "bar-" style/*.css` - verify bar-specific selectors
