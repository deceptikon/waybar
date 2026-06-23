---
name: waybar-module-reorganization
description: Safely reorganize module positions between bars using TL/VC/BR notation
source: auto-skill
extracted_at: '2026-06-24T00:32:00.000Z'
---

# Waybar Module Reorganization with TL/VC/BR Notation

## Overview
Systematic approach to reorganize Waybar modules between different bars using zone-based notation (TL=Top-Left, VC=Vertical-Center, BR=Bottom-Right, etc.) while avoiding config corruption and module override conflicts.

## When to Apply
- User wants to rebalance module distribution across bars
- Modules are "crowded" or "visually unbalanced"
- Need to move LLM switches, tray icons, privacy module between bars
- After CSS cleanup, verify module positions match intended layout

## Zone Notation

Use these zone descriptors to describe module positions:

| Zone | Meaning | Config Location |
|------|---------|-----------------|
| **TL** | Top bar, left zone (`modules-left`) | `config-top-base.jsonc.modules-left` |
| **TC** | Top bar, center zone (`modules-center`) | `config-top-base.jsonc.modules-center` |
| **TR** | Top bar, right zone (`modules-right`) | `config-top-base.jsonc.modules-right` |
| **VC** | Vertical bar, center zone | `config-vertical.modules-center` |
| **VR** | Vertical bar, right zone | `config-vertical.modules-right` |
| **BR** | Bottom bar, right zone | `config-bottom.modules-right` |

## Module Movement Pattern

### Rule: Always verify module definitions exist
Before moving a module between bars, check it's defined in an included `modules-*.json`:

```bash
# Find where module is defined
grep -r '"custom/ollama"' config-*.json modules-*.json
# Should find: modules-controls.json defines custom/llama
# Should find: config-bottom has custom/ollama exec definition
# If module not found in any JSON → don't add to config
```

### Pattern 1: Remove module from source bar
**Step 1:** Verify which bar currently has it
```bash
grep -n "modules-" config-top config-vertical config-bottom
```

**Step 2:** Edit only the modules array (NOT the module definition)
```bash
# In bottom config: remove from modules-right array
b["modules-right"] = [m for m in b["modules-right"] if m != "custom/llama"]
```

**Step 3:** Remove module definition from that bar (if it's only used there)
```bash
# Remove from bottom config if llama not used elsewhere
b.pop("custom/llama", None)
```

### Pattern 2: Add module to destination bar
**Step 1:** Check destination doesn't already have conflicting def
```bash
grep "custom/llama" config-vertical  # Should NOT exist before adding
```

**Step 2:** Add to modules array
```bash
v["modules-center"].extend(["custom/ollama", "custom/llama"])
```

**Step 3:** Add definition ONLY if not already in included modules files
```bash
# If modules-controls.json already defines llama, don't add it
# If custom/ollama only in bottom config, copy its definition
v["custom/ollama"] = bottom_config["custom/ollama"]
```

## Common Reorganization Tasks

### Task: Move privacy from VC to TC (near scratchpad)
```bash
# From config-vertical: remove privacy from center
v["modules-center"] = [m for m in v["modules-center"] if m != "privacy"]

# From config-top-base.jsonc: add clock#date, mode → privacy → titlebox-row
cfg["group/top-center"]["modules"] = ["clock#date", "sway/mode", "privacy", "group/titlebox-row"]

# Add privacy definition to top (or keep in modules-top-shared.json)
cfg["privacy"] = { ... }  # from original config
```

### Task: Move tray from VC to BR (with small icons)
```bash
# From config-vertical: remove tray
v["modules-center"] = [m for m in v["modules-center"] if m != "tray" and m != "group/tray"]

# From config-bottom: add tray to right
b["modules-right"].append("tray")

# Set small icon size (15px like vertical had, not default 20px)
b["tray"] = {"icon-size": 15, "spacing": 10}
```

### Task: Move LLM switches to VC (style as pair)
```bash
# From config-bottom: remove ollama+llama from right
b["modules-right"] = [m for m in b["modules-right"] if m not in ("custom/ollama", "custom/llama")]

# Keep ollama exec definition (it's complex, not in modules JSONs)
b.pop("custom/llama", None)  # llama is in modules-controls.json

# To config-vertical: add to center
v["modules-center"] = ["custom/lang", "custom/ollama", "custom/llama"]

# Don't add definitions if modules-controls.json already has them
# Just add CSS styling in vertical.css:
# "#custom-ollama, #custom-llama { ... }"
```

## Validation Checklist

Before committing changes:

- [ ] All config files valid JSON: `python3 -m json.tool config-*.json > /dev/null`
- [ ] No orphaned module defs (module in array but no definition)
- [ ] No conflicting stubs (`exec: "echo ''"`, `format: "{}"`)
- [ ] Module moved from correct bar (not left in both)
- [ ] Tray icon size consistent with user preference (15px for vertical, 20px for bottom)
- [ ] LLM switches have proper `interval: 5`, `return-type: "json"` if needed
- [ ] Bottom bar doesn't have undefined `custom/llama` (only ollama in bottom, llama in modules-controls.json)

## Testing After Reorganization

```bash
# Clean test
pkill -x waybar
sleep 0.5

# Test each bar individually
waybar -c config-top -s style/top.css -l debug > logs/test.log 2>&1 &
sleep 2
tail logs/test.log | grep -iE "error|Bar configured"

waybar -c config-vertical -s style/vertical.css -l debug > logs/test.log 2>&1 &
sleep 2
tail logs/test.log | grep -iE "error|Bar configured"

waybar -c config-bottom -s style/bottom.css -l debug > logs/test.log 2>&1 &
sleep 2
tail logs/test.log | grep -iE "error|Bar configured"
```

## Module Distribution Logic

### Top Bar Rules
- **Left**: Quick access (powerbtn, bluetooth, audio volume)
- **Center**: System info (clock, mode, privacy, window title)
- **Right**: Status indicators (brightness, idle, keylight, battery)

### Vertical Bar Rules
- **Left**: Sysmon groups (qwen-gpu, qwen-cpu, qwen-ram, etc.)
- **Center**: User-facing toggles (lang, LLM switches)
- **Right**: Status buttons (dunst, recorder, checkupdates, etc.)

### Bottom Bar Rules
- **Left**: Workspace switches (colorful lines for bottom)
- **Center**: Quick uptime
- **Right**: Runtime status (ollama UP, tray icons)

## Common Pitfalls

### 1. Leaving module in both bars
```bash
# ❌ BAD: ollama in bottom.modules-right AND vertical.modules-center
# ✅ GOOD: ollama only in bottom (if it's a status indicator) OR only in vertical (if it's a toggle)
```

### 2. Copying complex exec strings
```bash
# ❌ DON'T: manually copy ollama exec from bottom config
# ✅ DO: check if modules-controls.json already defines it
# If not, use the original exec string from HEAD:
git show HEAD:config-bottom | grep -A5 "custom/ollama"
```

### 3. Removing module def that's needed by multiple bars
```bash
# ❌ BAD: b.pop("custom/ollama") when vertical also needs it
# ✅ GOOD: only pop from bar that won't use it anymore
# Check usage: grep "custom/ollama" config-*.json
```

## Commit Template

When committing module reorganization:

```
Reorg: reorganize modules using TL/VC/BR notation

**Changes:**
- TL: Remove workspaces, add powerbtn+bluetooth+audio
- TC: Move privacy from VC to TC (near scratchpad in titlebox-row)
- VC: Remove tray, add ollama+llama as toggle pair
- BR: Remove LLM switches, add tray@15px icons
- Bottom: ollama UP indicator stays in right zone

**Validation:**
- All configs valid JSON
- All 3 bars start without errors
- No orphaned module definitions
- No conflicting stub overrides

**Notes:**
- LLM switches styled as unified pair in vertical.css
- Tray icons 15px (consistent with vertical)
- Privacy only in top bar, not vertical
```

## Related Skills
- `auto-skill-waybar-module-override-guard` — Prevents module stub conflicts
- `auto-skill-css-cleanup` — Cross-references modules with CSS selectors
- `auto-skill-waybar-zone-visual-consistency` — Ensures consistent spacing/padding across TL/VC/VR zones

## Added Patterns (2026-06-24)

### Pattern 3: Move frequently-used controls from TR to VC
**Use case:** `idle_inhibitor`, `power-profiles-daemon`, `ext-display` were in top bar TR, but user switches them frequently → move to vertical bar VC (action zone)

```bash
# Step 1: Remove from top bar
data["modules-right"] = [m for m in data["modules-right"] if m != "idle_inhibitor"]

# Step 2: Add to vertical center (with lang and LLM switches)
v["modules-center"] = ["custom/lang", "power-profiles-daemon", "custom/ext-display", "idle_inhibitor", "custom/ollama", "custom/llama"]

# Step 3: Reduce right zone to tools & alerts only
v["modules-right"] = ["custom/checkupdates", "custom/dunst", "custom/recorder", "custom/fnlock"]
```

### Pattern 4: Style zones with distinct visual treatment
**Rule:** Visual hierarchy matches interaction frequency — VC = primary actions (larger cards), VR = tools (compact uniform)

```css
/* Zone containers — consistent bg, margin, padding */
.bar-vert .modules-left, .bar-vert .modules-center, .bar-vert .modules-right {
  background: rgba(30, 30, 46, 0.85);
  margin: 6px 2px;
  padding: 6px 4px;
  border-radius: 10px;
}

/* VC action zone — slightly darker, distinct border */
.bar-vert .modules-center {
  background: rgba(25, 25, 38, 0.9);
  border-color: rgba(148, 226, 213, 0.12);
}

/* Primary action cards (ppd, ext-display, idle) — larger, centered */
#power-profiles-daemon, #custom-ext-display, #idle_inhibitor {
  padding: 8px 8px;
  min-height: 32px;
  font-size: 13px;
  text-align: center;
}

/* LLM pair — compact duo */
#custom-ollama, #custom-llama {
  padding: 5px 6px;
  margin: 3px 4px;
}

/* VR tools — uniform compact buttons */
#custom-dunst, #custom-recorder, #custom-checkupdates, #custom-fnlock {
  padding: 8px 6px;
  min-height: 32px;
  min-width: 36px;
  margin: 4px 4px;
}
```

### Pattern 5: Add accent borders to monitor groups
**Rule:** Each category (GPU, CPU, RAM, etc.) gets a colored left-border to visually separate sections

```css
#group-qwen-gpu, #group-qwen-cpu, #group-qwen-ram, #group-qwen-ssd, #group-qwen-asus {
  padding: 3px 0;
  margin: 4px 2px;
  border-left: 3px solid rgba(255, 255, 255, 0.06);
  border-radius: 8px;
}

/* Color-coded left borders */
#group-qwen-gpu { border-left-color: #fab387; }
#group-qwen-cpu { border-left-color: #a6e3a1; }
#group-qwen-ram { border-left-color: #89b4fa; }
#group-qwen-ssd { border-left-color: #a6e3a1; }
#group-qwen-asus { border-left-color: #94e2d5; }
#group-qwen-network { border-left-color: #94e2d5; }
```

## Validation Checklist (Updated)

Before committing changes:

- [ ] All config files valid JSON
- [ ] No orphaned module defs
- [ ] No conflicting stubs
- [ ] Module moved from correct bar (not left in both)
- [ ] Visual treatment matches frequency: VC = prominent, VR = compact
- [ ] Zone containers have consistent margin/padding
- [ ] Monitor groups have accent left-borders
- [ ] No text-align in vertical.css (GTK crasher)

## Commit Template (Updated)

```
Reorg: reorganize modules using TL/VC/VR notation, add zone styling

**Changes:**
- Remove idle_inhibitor from top bar TR → move to vertical VC
- VC: [lang, ppd, ext-display, idle_inhibitor, ollama, llama]
- VR: [checkupdates, dunst, recorder, fnlock]
- VL: monitor groups with accent borders
- VC zone: darker bg, larger cards for primary actions
- VR zone: compact uniform buttons, 8px padding
- All zones: 6px margin, consistent bg, border-radius

**Validation:**
- All configs valid JSON
- No text-align in CSS (GTK crasher)
- All 3 bars start without errors
```
