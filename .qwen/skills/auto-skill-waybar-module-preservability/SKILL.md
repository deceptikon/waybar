---
name: waybar-module-preservability
description: Never remove Waybar modules without explicit user approval and source verification
source: auto-skill
extracted_at: '2026-06-24T05:00:00.000Z'
---

# Waybar Module Preservability

## Overview
**Never delete or comment out a module from a config file without explicit user approval.** Modules that appear "dead" or "unused" may serve critical functions, and their removal breaks functionality. This skill prevents the catastrophic failure pattern where models removed modules based on assumptions rather than evidence.

## When to Apply
- Before any `edit`, `write_file`, or `read_file` that would remove/alter a config module
- When a model claims a module "has no function" or "wasn't used"
- When encountering DBus errors, CSS warnings, or missing services
- When asked to "cleanup" or "reorganize"

## Core Principles

### 1. **Modules are Never Dead Without Investigation**
Every module in `modules-*.json` files exists for a purpose. Even if:
- A service isn't running (ppd, ollama, llama)
- A module shows DBus errors
- CSS selectors don't match
- A module appears unused in current config

**Action:** Verify first. Don't delete.

### 2. **Understand the Module Type Before Acting**
Categorize modules by their behavior:
- **Monitors** (GPU, CPU, RAM, SSD): Read-only data display
- **Hybrids** (ASUS, Network): Show data + click triggers action
- **Toggles** (ppd, ext-display, idle_inhibitor): State switches
- **Status** (ollama, llama, lang): Passive indicators
- **Interactive** (audio, backlight): Sliders with click actions

**Action:** Document module types before proposing placement changes.

### 3. **DBus Errors Don't Mean Module Removal**
Example from recent failure: `power-profiles-daemon` showed "ServiceUnknown" error.
- **Reality:** ppd service may be running; error may be GTK CSS parser rejecting unrelated property (`line-height`)
- **Never action:** Remove `custom/powerbtn` or `power-profiles-daemon` from config
- **Correct action:** Fix CSS parser issue (remove `line-height`), restart, verify ppd still exists in config

### 4. **CSS Warnings Don't Mean Config Changes**
- `waybar -l debug` may show "GTK widget tree" errors
- `domain: gtk-css-provider-error-quark` often indicates CSS syntax issues, not missing modules
- **Action:** Fix CSS syntax, not config. Verify `modules-*.json` definitions match CSS selectors.

## Procedure

### Step 1: Inventory All Modules
```bash
# List all modules from source files
grep -r '"exec":' modules-sysmon.json modules-controls.json modules-peripherals.json modules-top-shared.json | sort -u

# List all module includes in each config
grep '"include"' config-*.json

# Cross-check unused modules
for module in $(grep -l 'custom/\|group/' modules-*.json); do
  echo "=== $module ==="
  grep -l "$module" config-*.json || echo "NOT USED IN ANY CONFIG"
done
```

### Step 2: Verify Module Existance
Before removing any module:
1. Check `modules-*.json` for its definition
2. Check if it's included in any config file via `"include"` or `"modules-*"` arrays
3. Check if it has a corresponding CSS selector
4. Ask user explicitly: "Module X appears unused. Do you want to remove it?"

### Step 3: Document Module Purpose
For each module you're considering removing, document:
- Source file and line number
- What it does (exec command, format, click action)
- Why it might appear unused
- User's stated preference (high/medium/low frequency? daily? rarely?)

### Step 4: Preserve in Commented Form
If user wants to remove a module but you're unsure:
```json
// TEMPORARY: User requested removal pending verification
// Source: modules-controls.json line 15
// "custom/powerbtn": { ... },
```

This allows one-click restoration if needed.

### Step 5: Test Before Committing
Always run before finalizing:
```bash
# Reload waybar and check logs
tail -30 logs/waybar-*.log | grep -E "error|warning|configured"

# Check specific modules
grep "custom/.*" logs/waybar-vertical.log | grep "will be hidden" || echo "All modules loaded"
```

## Common Failure Patterns (Avoid These)

### Pattern 1: "Module has no function"
**Failure:** Model sees `power-profiles-daemon` DBus error → assumes ppd isn't needed → removes it
**Reality:** ppd is high-frequency control user clicks daily. DBus error may be CSS parser issue.
**Fix:** Document ppd as "HIGH frequency" control. Keep in config.

### Pattern 2: "CSS warns about module"
**Failure:** Model sees `vertical.css:108:13 'line-height' is not valid` → assumes module is broken → removes module
**Reality:** `line-height` is unsupported in GTK CSS. Module is fine; CSS property is broken.
**Fix:** Fix CSS syntax, not config.

### Pattern 3: "Unused module cleanup"
**Failure:** Model finds `custom/ollama` in `modules-controls.json` but not in `config-vertical` → removes from JSON
**Reality:** Module may be in another config or user may add it later.
**Fix:** Document as "currently unused in vertical bar, present in controls source".

### Pattern 4: "Grouped modules collapse"
**Failure:** Model groups 6 buttons into 2-element pairs → buttons shrink from 36px to 26px → unusable
**Reality:** User needs recognizable buttons, not "groups".
**Fix:** Preserve individual button selectors. Don't group unless user explicitly asks.

## Verification Checklist

Before removing any module, confirm:
- [ ] Module is documented in `docs/STRUCTURE.md` (create if missing)
- [ ] Module frequency (high/medium/low) is stated by user
- [ ] Module purpose is understood (click vs toggle vs indicator)
- [ ] DBus/CSS errors are diagnosed (not blindly blamed on module)
- [ ] User explicitly approves removal (verbatim: "remove X")
- [ ] Removal is reverted and tested in new config file first

## Recovery: Restoring Removed Modules

If you accidentally removed a module:
```bash
# Restore from git
git checkout <commit> config-vertical

# Or restore from backup
cp modules-controls.json.bak modules-controls.json

# Verify with waybar logs
tail -30 logs/waybar-vertical.log | grep "custom/.*will be hidden" || echo "No hiding errors"
```

## Communication Template

When proposing to remove a module:

```
**Proposed deletion:** Remove `custom/ollama` from config-vertical

**Rationale:**
- Module not referenced in modules-right or modules-center arrays
- Service may not be running (ollama not installed)
- User mentioned LLM toggle frequency is "low"

**Risk assessment:**
- Low: Module is indicator-only, click toggles service
- Medium: If user installs ollama later, module needs to be re-added

**Alternative:**
- Comment out in config vertical instead of delete
- Keep in modules-controls.json source
- Add to bottom bar if user wants LLM controls there

**Action requested:** Please confirm if you want me to:
1. Remove from config-vertical (delete)
2. Comment out with fallback option
3. Keep as is (no change)
```

## Related Skills
- `waybar-module-reorganization` - Moving modules between zones
- `waybar-module-grouping` - Grouping modules into functional clusters
- `waybar-gtk-quirks` - GTK CSS limitations (no `line-height`, `width` not supported)
- `waybar-css-cleanup` - Removing dead CSS, not modules

## Lessons from Recent Failure
**Commit `d641550`** (last known working state) had:
- `modules-right`: 6 modules (ppd, dunst, recorder, fnlock, checkupdates, ext-display)
- `modules-center`: 3 modules (lang, ollama, llama)
- `modules-left`: 6 monitor groups (GPU, CPU, RAM, SSD, ASUS, Network)

**Breaking changes I caused:**
- Added 4 groups that collapsed buttons
- Removed ppd, ollama, llama at various points
- Changed width 138 → 200 → broke layout
- Never asked user where things should go before moving them

**Lesson:** Ask first. Propose in MD file. Let user approve before touching code.
