---
name: waybar-vr-flat-buttons
description: VR zone uses flat buttons, not grouped — explicit sizing & frequency ordering
source: auto-skill
extracted_at: '2026-06-24T10:25:00.000Z'
---

# VR Zone Action Buttons — Flat List Pattern

## Overview
**Critical lesson from 2026-06-24:** Functional paired groups (`group/vr-*`) for action buttons **failed visually** — they compressed 9 modules into 4 tiny unusable blobs. The correct pattern is **flat standalone buttons** with explicit sizing, spacing, and frequency ordering.

This skill provides the pattern for VR (right zone) action buttons.

## The Problem: Grouped VR Modules

### What we tried (DRAFT plan rejected after implementation):
```json
"modules-right": [
  "group/vr-power",      // idle_inhibitor | ext-display
  "group/vr-ai",         // ollama | llama
  "group/vr-capture",    // recorder | dunst
  "group/vr-sys"         // fnlock | checkupdates
]
```

**CSS for grouped containers:**
```css
#group-vr-power,
#group-vr-ai,
#group-vr-capture,
#group-vr-sys {
  min-width: 72px;
  padding: 2px 8px;
  /* ... */
}
```

**Result:** Each group appeared as a 72×24px blob — users couldn't distinguish individual buttons:

> "7 tiny icons crammed into a small dark box. Icons are indistinguishable, unclickable, useless for daily controls."

### Why groups failed:
1. **Vertical constraint:** 24px height was explicitly rejected as "unusable"; 30px was the compromise
2. **Horizontal compression:** 72px width only allows 2 items per group
3. **Visual density:** No breathing room between items, no semantic separation

## The Solution: Flat Standalone Buttons

### Configuration pattern
```json
"modules-right": [
  "custom/ollama",
  "custom/llama",
  "custom/checkupdates",
  "custom/dunst",
  "custom/recorder",
  "custom/fnlock"
]
```

**Key changes:**
1. **No `group/vr-*` definitions** — delete all 5 (vr-power, vr-ai, vr-capture, vr-sys, qwen-profile)
2. **Individual module placement** — 6 flat buttons, not grouped
3. **Frequency ordering** — HIGH-freq top, MEDIUM middle, LOW bottom

### CSS pattern
```css
/* VR — secondary actions */
.bar-vert .modules-right #custom-ollama,
.bar-vert .modules-right #custom-llama,
.bar-vert .modules-right #custom-checkupdates,
.bar-vert .modules-right #custom-dunst,
.bar-vert .modules-right #custom-recorder,
.bar-vert .modules-right #custom-fnlock {
  font-size: 15px;
  min-width: 36px;
  min-height: 24px;
  padding: 4px 8px;
  margin: 2px 4px;
  border-radius: 6px;
  color: #a6adc8;
  background: rgba(20, 20, 28, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.06);
  transition: color 0.2s ease;
}

/* Per-module width overrides */
.bar-vert .modules-right #custom-ollama,
.bar-vert .modules-right #custom-llama { min-width: 80px; }  /* text labels */
.bar-vert .modules-right #power-profiles-daemon { min-width: 90px; }  /* profile text */
```

### Dimensions reference

| Property | VC daily actions | VR secondary actions |
|----------|------------------|----------------------|
| `min-width` | 36px | 36px (icons) / 80px (ollama/llama) / 90px (ppd) |
| `min-height` | 28px | 24px |
| `font-size` | 16px | 15px |
| `padding` | `6px 8px` | `4px 8px` |
| `margin` | `4px 4px` | `2px 4px` |
| `border-radius` | 8px | 6px |

### Section spacing (optional)
```css
/* First element of MEDIUM tier */
.bar-vert .modules-right #custom-checkupdates {
  margin-top: 10px;
}

/* First element of LOW tier */
.bar-vert .modules-right #custom-dunst {
  margin-top: 10px;
}
```

## VC (Center) — Daily Actions

For high-frequency daily actions, use **larger** button sizes:

```css
/* VC — daily-use action buttons */
.bar-vert .modules-center #power-profiles-daemon,
.bar-vert .modules-center #custom-ext-display,
.bar-vert .modules-center #idle_inhibitor {
  font-size: 16px;
  font-weight: 600;
  min-width: 36px;
  min-height: 28px;
  padding: 6px 8px;
  margin: 4px 4px;
  border-radius: 8px;
}
```

## State Selectors

**Always use flat selectors** (no group nesting):

```css
/* State highlights */
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

/* Disabled state */
#custom-ext-display.disconnected {
  opacity: 0.5;
}

/* PPD profile states */
#power-profiles-daemon.balanced    { color: #94e2d5; }
#power-profiles-daemon.performance { color: #fab387; }
#power-profiles-daemon.power-saver { color: #89b4fa; }
```

**Critical:** Never use `label#module-id.class` — GTK can't parse this. Use `#module-id.class`.

## Migration Guide

### Step 1: Delete group definitions
```bash
# From modules-controls.json, remove:
# group/vr-power, group/vr-ai, group/vr-capture, group/vr-sys, group/qwen-profile
```

### Step 2: Update config to flat list
```json
// config-vertical:
"modules-right": [
  "custom/ollama",
  "custom/llama",
  "custom/checkupdates",
  "custom/dunst",
  "custom/recorder",
  "custom/fnlock"
]
```

### Step 3: Remove group CSS selectors
```bash
# Delete all #group-vr-* selectors from vertical.css
# grep -n "#group-vr-" style/vertical.css && delete those lines
```

### Step 4: Add flat button CSS
```css
/* Add per-zone button rules as shown above */
```

## When to Use Groups (Rare Cases)

**Use groups only for:**
- Monitor/Hybrid groups that need **icon + info-card pairing** (e.g., `group/qwen-gpu`)
- Horizontal sliders that need **icon + slider pairing** (e.g., `group/audio`, `group/bright`)

**Never use groups for:**
- Action/toggle buttons on a single axis
- Any module list that exceeds 3-4 items per zone
- VR-style control zones where visibility/clarity is critical

## Related Skills
- `auto-skill-waybar-module-reorganization` — Module placement between bars
- `auto-skill-waybar-gtk-quirks` — Flat CSS selectors (no `group/` prefix)
- `auto-skill-waybar-module-preservability` — Don't delete modules without approval

## Commit Template

```
refactor: vertical bar — flat VR buttons, daily actions in VC

- Dissolve all 5 group/vr-* definitions (they compressed buttons into blobs)
- Flatten VR to 6 standalone modules with explicit min-width/min-height
- Move ppd, ext-display, idle_inhibitor to VC (28px height, 16px font)
- Add flat state selectors (#id.class, no group nesting)
- Remove #group-vr-* CSS (deleted, dead code)
```