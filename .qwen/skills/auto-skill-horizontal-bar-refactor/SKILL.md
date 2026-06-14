---
name: horizontal-bar-refactor
description: Pattern for flattening group-based modules into individual horizontal bar layout with consistent spacing and cleanup of obsolete CSS
source: auto-skill
extracted_at: '2026-06-14T14:28:00.000Z'
---

# Horizontal Bar Flattening Pattern

This skill covers refactoring a Waybar horizontal bar (`bar-horiz`) layout from group-based wrappers to individual flat modules, while maintaining consistent visual styling and spacing.

## When to Use

Use this pattern when:
- You want to simplify a grouped layout (e.g., `group/temp-fan-group`, `group/cpu-ram-group`) into individual modules
- You need consistent spacing between modules (e.g., `margin: 0 4px`)
- You want to reduce CSS complexity by removing obsolete group selectors
- You're adding new inline modules (e.g., sliders, custom indicators) that were previously in groups

## The Approach

### 1. Analyze Current Layout

Identify which groups in `modules-left`/`modules-right` should become flat:

```json
// Before (grouped)
"modules-left": [
  "group/temp-fan-group",
  "group/cpu-ram-group",
  "group/io-network-group",
  "group/network-combined"
]
```

Document each group's children:
- `group/temp-fan-group` → `custom/temp-fan`
- `group/cpu-ram-group` → `custom/cpu-indicator-vertical`, `custom/ram-indicator-vertical`
- `group/io-network-group` → `custom/io-speed`
- `group/network-combined` → `custom/wifi-big-icon`, `custom/net-combined-info`

### 2. Flatten in config

Replace the group references with individual module names in `bar-horiz.modules-left`:

```json
// After (flat)
"modules-left": [
  "custom/temp-fan",
  "custom/cpu-indicator-vertical",
  "custom/ram-indicator-vertical",
  "custom/io-speed",
  "group/network-combined"  // Keep groups that need unified styling (note: correct naming)
]
```

Key decisions:
- Keep groups that require unified styling (e.g., `#group-network-combined` with shared border)
- Flatten modules that can have individual styling and spacing
- **Verify module definitions**: Ensure the module name in config actually exists in `default-modules.json`. Common mistake: `group/net-combined` vs `group/network-combined` — if you reference a non-existent group, modules disappear from the bar.

### 3. Verify Script Output for Custom Modules

Before adding new custom modules, test that their scripts produce valid JSON:

```bash
# Test script manually
~/.config/waybar/scripts/<script>.sh

# Validate JSON
~/.config/waybar/scripts/<script>.sh | jq .

# Check exit code
/home/lexx/.config/waybar/scripts/<script>.sh; echo "EXIT: $?"
```

Scripts that fail silently (exit without producing JSON) will show invisible modules in the bar. See `auto-skill-waybar-script-debug` for debugging patterns.

### 4. Add Consistent Margin to CSS

Add `margin: 0 4px` to all flat modules to ensure consistent spacing:

```css
#custom-cpu-indicator-vertical,
#custom-ram-indicator-vertical,
#custom-io-speed,
#custom-wifi-big-icon,
#custom-temp-fan {
  margin: 0 4px;
  /* ... other styles ... */
}
```

For power buttons and similar:

```css
#custom-powerbtn {
  margin: 0 4px;
  /* ... existing styles ... */
}
```

### 4. Simplify CSS Structure

Remove obsolete group selectors that no longer apply:

```css
/* BEFORE - Remove these */
#cpu-ram-group,
#io-network-group,
#temp-fan-group {
  background: transparent;
  border: none;
  border-radius: 0;
  padding: 0;
  margin: 0 4px;
}

#cpu-ram-group > *,
#io-network-group > *,
#temp-fan-group > * {
  margin: 0;
}

/* AFTER - Keep only what's used */
#audio,
#bright {
  background: transparent;
  border: none;
  border-radius: 0;
  padding: 0;
  margin: 0 2px;
}

#audio > *,
#bright > * {
  margin: 0;
}

#group-net-combined {
  /* Keep groups that still need unified styling */
}
```

### 5. Consolidate Duplicate CSS

If the same selector appears multiple times (e.g., `#custom-bt-indicator`), deduplicate:

```css
/* BEFORE - Duplicated */
#custom-bt-indicator {
  min-width: 32px;
  min-height: 20px;
  /* ... */
}
#custom-bt-indicator.enabled,
#custom-bt-indicator.connected {
  /* ... */
}

/* Keep these blocks... */

#custom-bt-indicator {
  min-width: 32px;
  min-height: 20px;
  /* ... */
}
#custom-bt-indicator.enabled,
#custom-bt-indicator.connected {
  /* ... */
}

/* AFTER - Single consolidated block */
#custom-bt-indicator {
  margin: 0 4px;
  min-width: 36px;
  min-height: 20px;
  padding: 2px 6px;
  border-radius: 6px;
  font-size: 18px;
  font-weight: bold;
  color: #94e2d5;
  background: rgba(0, 128, 128, 0.15);
  border: 1px solid rgba(148, 226, 213, 0.4);
}
#custom-bt-indicator.enabled,
#custom-bt-indicator.connected {
  color: #94e2d5;
  background: rgba(0, 128, 128, 0.3);
  border: 1px solid rgba(148, 226, 213, 0.8);
}
```

### 6. Strengthen Visibility (if needed)

For modules that need to be more visible, adjust sizing and styling:

```css
#custom-bt-indicator {
  min-width: 36px;  /* Wider than default */
  font-size: 18px;  /* Larger than default */
  padding: 2px 6px; /* More generous padding */
  /* ... stronger colors/borders ... */
}
```

Similarly for sliders:

```css
#pulseaudio-slider trough,
#backlight-slider trough {
  min-height: 6px;  /* Increased from 3px for better visibility */
  min-width: 60px;
}
```

### 7. Add Any New Inline Modules

If you want to add modules directly to the bar (like sliders), define them in `config` at the bar level:

```json
"bar-horiz": {
  "modules-left": [...],
  "modules-right": [
    "group/audio",
    "group/bright",
    "custom/bt-indicator"
  ],
  "pulseaudio/slider": {
    "min": 0,
    "max": 90,
    "orientation": "horizontal",
    "format": "SUSU {}"
  },
  "backlight/slider": {
    "min": 9,
    "max": 100,
    "orientation": "horizontal",
    "device": "intel_backlight"
  }
}
```

### 8. Validate and Test

```bash
# JSON validation
jq . config
jq . default-modules.json

# Bash syntax check
bash -n ~/.config/waybar/scripts/<script>.sh

# Commit if ready
git add -A && git commit -m "Refactor bar-horiz layout and styling

- Reduce bar height and flatten left modules
- Add consistent margin spacing to all modules
- Increase slider thickness for visibility
- Strengthen and deduplicate indicator CSS
- Clean up obsolete group selectors"

# Reload
pkill -SIGUSR2 waybar
```

## Common Pitfalls

- **Don't** remove grouping when unified styling is required (e.g., `#group-network-combined` with shared border)
- **Don't** forget to add `margin: 0 4px` when flattening modules — individual modules won't have spacing without it
- **Don't** leave unused group selectors in CSS — they add maintenance burden and visual noise
- **Don't** duplicate CSS rules — if a selector appears twice, merge them
- **Don't** use inconsistent margins — keep spacing uniform across similar modules
- **Don't** forget to validate JSON after editing `config` — invalid JSON prevents Waybar from loading
- **Don't** set slider trough too thin (< 3px is hard to see, 6px is recommended)
- **Don't** reference non-existent modules in config — `group/net-combined` vs `group/network-combined`: if you reference a module/group that doesn't exist in `default-modules.json`, that module disappears from the bar silently
- **Don't** assume scripts produce output — always test custom module scripts manually before assuming they work. Silent failures (exit code 0 but no JSON output) cause invisible modules
- **Don't** use `set -euo pipefail` with `grep` pipelines without handling non-zero exit codes — `grep` returns exit 1 when no match, which kills the script with `pipefail`. Use `wc -l` pipeline or `|| true` fallback

## File Locations

| File | Section | Pattern |
|---|---|---|
| `config` | `bar-horiz.modules-left` | Flat array of individual modules |
| `config` | `bar-horiz.modules-right` | Flat array with groups for unified styling |
| `style.css` | `.left-module` selectors | Individual styling with `margin: 0 4px` |
| `style.css` | `#group-*.css` | Keep only groups that need shared border/background |
| `default-modules.json` | `group/*` | May keep definitions even if unused in bar-horiz |

## Example Before/After

### Before (grouped layout)
```json
"modules-left": [
  "group/temp-fan-group",
  "group/cpu-ram-group",
  "group/io-network-group",
  "group/network-combined"
]
```

```css
#temp-fan-group, #cpu-ram-group, #io-network-group {
  /* styling */
}
#temp-fan-group > *, #cpu-ram-group > * {
  margin: 0;
}
```

### After (flat layout)
```json
"modules-left": [
  "custom/temp-fan",
  "custom/cpu-indicator-vertical",
  "custom/ram-indicator-vertical",
  "custom/io-speed",
  "group/net-combined"
]
```

```css
#custom-cpu-indicator-vertical,
#custom-ram-indicator-vertical,
#custom-io-speed,
#custom-temp-fan {
  margin: 0 4px;
  /* individual styling */
}
#group/net-combined {
  /* only keep the one that needs unified styling */
}
```

## Related Skills

- `waybar-toggle-button`: Pattern for adding toggle-style buttons to the vertical bar
- AGENTS.md: Waybar configuration guidelines and signal conventions
