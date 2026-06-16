---
name: waybar-grouped-icon-info-module
description: Creating grouped icon/info modules in Waybar with nested-box CSS styling
source: auto-skill
extracted_at: '2026-06-16T00:00:00.000Z'
---

## Overview

Pattern for creating grouped icon/info modules in Waybar with nested-box CSS styling. Each group has:
- **Icon tile**: transparent background, no border, sits inside dark wrapper
- **Info tile**: colored border/background, lives inside wrapper, displays data

Example: `group/qwen-cpu` with `custom/qwen-cpu-icon` + `custom/qwen-cpu-info`

## Implementation Steps

### 1. Define Modules in JSON config

**icon module** — plain polling, no toggle logic:
```json
"custom/<name>-icon": {
  "exec": "~/.config/waybar/scripts/<name>-icon.sh",
  "interval": 5,
  "format": "{}",
  "return-type": "json"
}
```

**info module** — complex data + click handler:
```json
"custom/<name>-info": {
  "exec": "~/.config/waybar/scripts/<name>-info.sh refresh",
  "interval": 5,
  "format": "{}",
  "return-type": "json",
  "on-click": "launcher-for-data",
  "on-right-click": "launcher-for-raw"
}
```

**group definition**:
```json
"group/<group-name>": {
  "orientation": "horizontal",
  "modules": ["custom/<name>-icon", "custom/<name>-info"]
}
```

### 2. Write Icon Script

**Keep it simple** — just output icon char + class:
```bash
#!/bin/bash
# Icon — <description>
icon=$(printf '\xf3\xb0\x8d\x9b')  # UTF-8 bytes for character
jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
```

**Alternative for single char** (no escape sequence mangling):
```bash
#!/bin/bash
icon="󰍛"  # literal Unicode char
jq -nc --arg t "$icon" '{text:$t,class:"icon"}'
```

**Never use** `write_file` for scripts with `\n` escapes — use heredoc or literal chars!

### 3. Write Info Script

**Output format**:
- Line 1: Visual representation (blocks, bars, per-core grid)
- Line 2: Summary text on right (avg%, temp, etc.)

**Use heredoc to avoid mangling**:
```bash
#!/bin/bash
# Info — <description>
# Output: line1 of visual, line2 of summary

# ... data processing ...

line1=$(sed -n '1p' /tmp/qb_output)
line2=$(sed -n '2p' /tmp/qb_output)

cls="good"
[ "$avg" -ge 50 ] && cls="medium"
[ "$avg" -ge 75 ] && cls="warning"

jq -nc --arg l1 "$line1" --arg l2 "$line2" --arg cls "$cls" '{text: ($l1 + "\n" + $l2), class: $cls}'
```

### 4. Add to Module Includes

**Add `qwen-modules.json` (or your modules file) BEFORE default-modules**:
```json
"include": [
  "/home/lexx/.config/waybar/qwen-modules.json",
  "/home/lexx/.config/waybar/default-modules-v2.json",
  "/home/lexx/.config/waybar/default-modules.json"
]
```

**Modules order** matters — later definitions override earlier ones.

### 5. CSS Styling (Nested-Box Pattern)

**Outer wrapper** (group):
```css
#group/<group-name> {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(<accent-r,g,b>, 0.4);
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}
```

**Icon tile** (transparent inside wrapper):
```css
#custom/<name>-icon {
  font-size: 20px;
  min-width: 32px;
  padding: 2px 4px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: <accent-color>;
  margin-right: 2px;
}
```

**Info tile** (inner box):
```css
#custom/<name>-info {
  font-size: 9px;
  font-weight: 500;
  min-width: 0;
  padding: 1px 4px 1px 4px;
  border-radius: 6px;
  border: 1px solid rgba(<accent-r,g,b>, 0.4);
  background: rgba(30, 30, 42, 0.85);
  color: <accent-color>;
}

#custom/<name>-info.medium  { background: rgba(249, 226, 175, 0.12); border-color: rgba(249, 226, 175, 0.4); }
#custom/<name>-info.warning { background: rgba(250, 179, 135, 0.15); border-color: rgba(250, 179, 135, 0.5); }
#custom/<name>-info.critical { background: rgba(243, 139, 168, 0.18); border-color: rgba(243, 139, 168, 0.55); }
```

**Color scheme**:
- Green accent: `rgba(166, 227, 161, ...)` for CPU
- Blue accent: `rgba(137, 180, 250, ...)` for RAM
- Teal accent: `rgba(148, 226, 213, ...)` for WiFi

## Common Pitfalls

**Icon Unicode mangled by `write_file`**:
- `write_file` writes literal `\n` characters, not real newlines
- Use heredoc (`cat > file << 'EOF'`) with embedded Unicode
- Or use `printf '\xf3\xb0\x8d\x9b'` for UTF-8 bytes

**Bar height exceeds config**:
- CSS `min-height: 20px` + padding inflates box size
- Reduce padding to `0 2px` or `1px 2px`
- Use `min-width: 0` instead of auto (GTK CSS doesn't support auto)

**Script output broken**:
- `write_file` mangles `\n` in bash strings → visible as `\\n`
- Use heredoc to preserve real newlines
- Never use `printf '\n'` in `write_file`-written scripts

**Module blank or showing wrong data**:
- Icon script uses wrong Unicode codepoint for your font
- Test script output with `jq -r '.text' | od -c`
- Compare bytes against working reference

## File Structure

```
scripts/
  qwen-<name>-icon.sh      # Icon output
  qwen-<name>-info.sh      # Info tile output
config
  qwen-modules.json        # Module definitions
  config                   # Bar wiring
style.css                  # Nested-box styling
```

## Example Outputs

**CPU tile**:
```
Row 1: [8 colored blocks]
Row 2: [8 colored blocks][avg:23%]
```

**RAM tile**:
```
Row 1: [▓▓▓▓▓▓▓18G······ 30G]
Row 2: [swap: 1.1G]
```