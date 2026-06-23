---
name: waybar-module-override-guard
description: Prevents module definition stubs from overwriting included module configs
source: auto-skill
extracted_at: '2026-06-24T00:20:00.000Z'
---

# Waybar Module Override Guard

## Overview
Common mistake: defining a module stub in `config-top-base.jsonc` with `exec: "echo ''"` and `format: "{}"` will **overwrite** (not merge with) the proper configuration in included `modules-*.json` files, causing the module to disappear or render empty.

## The Bug Pattern

```jsonc
// config-top-base.jsonc  ❌ WRONG
{
  "custom/powerbtn": {
    "exec": "echo ''",
    "interval": 43200,
    "on-click": "~/.config/waybar/scripts/utils/shutdown-dmenu.sh",
    "format": "{}"
  }
}
```

This **completely replaces** the definition in `modules-peripherals.json` which has:
```jsonc
{
  "custom/powerbtn": {
    "format": "⏻ ",
    "tooltip": false,
    "menu": "on-click",
    "menu-file": "~/.config/waybar/feeds/powermenu.xml",
    "menu-actions": { ... }
  }
}
```

Result: The menu-based `⏻` button disappears because `format: "{}"` renders the empty output of `echo ''`.

## How to Fix

### Step 1: Identify Conflicting Definitions
```bash
# Check which modules are defined in base config vs included files
grep -n "^  \"custom/[^}]*\": {" config-top-base.jsonc
grep -n "^  \"custom/[^}]*\": {" modules-*.json
# Look for overlaps

# Also check for generic overrides
grep -n 'exec.*echo' config-top-base.jsonc
grep -n '"format": "{}"' config-top-base.jsonc
```

### Step 2: Remove the Conflicting Stub
In `config-top-base.jsonc`, delete the entire block for any module that's already defined in an included file:

```jsonc
{
  "group/top-center": { ... },
  // ❌ REMOVE THIS ENTIRE BLOCK
  // "custom/powerbtn": {
  //   "exec": "echo ''",
  //   "interval": 43200,
  //   "format": "{}"
  // },
  "sway/scratchpad": { ... }
}
```

### Step 3: Verify Inheritance Order
Check the `include` order in `config-top-base.jsonc`:
```jsonc
{
  "include": [
    "modules-top-shared.json",      // Loaded first
    "modules-peripherals.json",     // Loaded second  
    "modules-controls.json"         // Loaded third
  ]
}
```

Waybar merges configs: last-defined wins. So if a module is in `config-top-base.jsonc`, it will **override** everything in the included files.

**Rule**: Only define modules in `config-top-base.jsonc` that are **not** in the included files.

## Common Module Conflicts

| Module | Defined In | Conflict Pattern |
|--------|------------|------------------|
| `custom/powerbtn` | `modules-peripherals.json` | Stub with `exec: "echo ''"` |
| `sway/mode` | `modules-top-shared.json` | Stub that overrides full definition |
| `sway/scratchpad` | `modules-top-shared.json` | Partial override that breaks icon formatting |
| `clock#date` | `modules-top-shared.json` | Reduced format `{:%a %d}` instead of full date-time |

## Recovery Procedure

If modules disappear after config changes:

1. Check for conflicting definitions:
   ```bash
   grep -n "exec.*echo" config-top-base.jsonc
   ```

2. Restore from git:
   ```bash
   git show HEAD:config-top-base.jsonc
   git checkout HEAD -- modules-top-shared.json
   ```

3. Re-apply only necessary changes:
   - Module reordering is fine (e.g., moving powerbtn from TR to TL)
   - Don't redefine modules unless necessary
   - When reorganizing, always check `git diff` before committing

## Testing Checklist

- [ ] All modules in `modules-left/center/right` arrays have working configs
- [ ] No `exec: "echo ''"` overrides in base config
- [ ] Menu-based modules (powerbtn) show their icons
- [ ] `waybar -l debug` shows all expected modules with correct IDs
- [ ] JSON validation passes: `python3 -c "import json; json.load(open('config-top-base.jsonc'))"`

## Related Skills
- `auto-skill-css-cleanup` — Cross-references module names with CSS selectors
- `waybar-config-validation` — Validates JSON structure
