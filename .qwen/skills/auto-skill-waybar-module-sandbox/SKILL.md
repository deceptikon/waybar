---
name: waybar-module-sandbox
description: Creating a minimal dev bar for rapid single-module iteration in Waybar
source: auto-skill
extracted_at: '2026-06-14T16:00:00.000Z'
---

# Waybar Module Sandbox Pattern

This skill covers creating a minimal “sandbox” bar (`bar-horiz-dev`) with a single module for rapid iteration on module layout, styling, and sizing without the noise of the full bar.

## When to Use

Use this pattern when:
- You need to test a new module's appearance before integrating it into the production bar
- You're debugging why the production bar exceeds its target height (is it the module or other factors?)
- You want to iterate on CSS/styling without constantly breaking/reloading the full bar
- You're building a new module from scratch (e.g., `custom/qwen-network`) and want to validate the output format and visual impact

## The Approach

### 1. Create the Script

Write your unified module script in `scripts/`. Key principles:
- Output **single inline string** (no two-row formatting)
- Use `jq -n --compact-output` for JSON
- Return `text`, `class`, and `tooltip` fields
- Include signal strength → icon mapping
- Include speed sampling (0.5s delta for network stats)
- Pick worst class (signal vs. speed) for final styling
- Make executable: `chmod +x scripts/<script>.sh`

Example skeleton:

```bash
#!/bin/bash

# Output a single inline string: icon  SSID  ↓rx ↑tx

get_wifi_info() {
  nmcli -t -f active,ssid,signal,device dev wifi 2>/dev/null \
    | grep '^yes' | head -1
}

format_speed() {
  local kb="$1"
  if [ "$kb" -ge 1024 ]; then
    awk "BEGIN {printf \"%.0fM\", $kb/1024}"
  else
    printf "%dK" "$kb"
  fi
}

# Returns numeric rank: higher is worse
rank_class() {
  case "$1" in
    good)        echo 0 ;;
    medium)      echo 1 ;;
    warning)     echo 2 ;;
    critical)    echo 3 ;;
    disconnected) echo 5 ;;
    *)           echo 0 ;;
  esac
}

# --- Main logic ---

wifi_info=$(get_wifi_info || true)

if [ -z "$wifi_info" ]; then
  jq -n --compact-output \
    --arg text " OFF" \
    '{text: $text, class: "disconnected", tooltip: "WiFi disconnected"}'
  exit 0
fi

ssid=$(printf  '%s' "$wifi_info" | cut -d: -f2)
signal_raw=$(printf '%s' "$wifi_info" | cut -d: -f3)
iface=$(printf '%s' "$wifi_info" | cut -d: -f4)

# ... (icon mapping, speed sampling, class determination)

text="$icon ${ssid^^} ↓$rx_fmt ↑$tx_fmt"

jq -n --compact-output \
  --arg text "$text" \
  --arg cls "$final_class" \
  --arg tip "$tooltip" \
  '{text: $text, class: $cls, tooltip: $tip}'
```

### 2. Create Dedicated Module JSON File

Put the module definition in its own `qwen-modules.json` (or `<topic>-modules.json`) file. This keeps the bar config clean and the module isolated:

```json
{
  "custom/qwen-network": {
    "exec": "~/.config/waybar/scripts/qwen-network.sh",
    "interval": 10,
    "format": "{}",
    "return-type": "json",
    "on-click": "nm-connection-editor",
    "on-right-click": "nm-applet --indicator"
  }
}
```

Note: Don't put this in `default-modules.json` since it's dev-only.

### 3. Add Dev Bar to config

Insert `bar-horiz-dev` into the `config` array **before** `bar-horiz` so it renders first. Make it truly minimal:

```json
{
  "name": "bar-horiz-dev",
  "layer": "top",
  "position": "top",
  "height": 17,
  "modules-left": ["custom/qwen-network"],
  "modules-center": [],
  "modules-right": [],
  "include": ["/home/lexx/.config/waybar/qwen-modules.json"]
}
```

Key choices:
- **Only `modules-left`**: No center/right to avoid layout confusion
- **`height: 17`**: Use your target height to verify the module respects it
- **`include`**: Inject the module definition from the isolated file
- **Empty arrays for center/right**: Explicit, not defaulted

### 4. Add Sandbox CSS

Add CSS scoped to `#custom-<module>` **after** all existing styles, clearly marked as dev-only:

```css
/* === 5. DEV BAR — qwen-network sandbox === */
#custom-qwen-network {
  /* Let content drive size; no min-height/min-width so bar can stay compact */
  padding: 2px 8px;
  font-size: 13px;
  font-weight: 500;
  color: #94e2d5;
  background: rgba(0, 128, 128, 0.1);
  border: 1px solid rgba(148, 226, 213, 0.35);
  border-radius: 6px;
  margin: 0 4px;
}
#custom-qwen-network.medium  { background: rgba(249, 226, 175, 0.12); border-color: rgba(249, 226, 175, 0.4); color: #f9e2af; }
#custom-qwen-network.warning { background: rgba(250, 179, 135, 0.15); border-color: rgba(250, 179, 135, 0.5); color: #fab387; }
#custom-qwen-network.critical { background: rgba(243, 139, 168, 0.15); border-color: rgba(243, 139, 168, 0.5); color: #f38ba8; }
#custom-qwen-network.disconnected { background: rgba(100, 100, 100, 0.15); border-color: rgba(120, 120, 120, 0.3); color: #888; }
```

Key choices:
- **No `min-height/min-width`**: Let content drive the size, so you can verify if the bar actually reaches its target (17px)
- **Per-state variants**: Same `class` names from the script (`medium`, `warning`, `critical`, `disconnected`) for visual feedback
- **Teal accent theme**: Match production bar styling for context
- **Scoped naming**: `#custom-<module>` is unique to this bar (no name collision with production)

### 5. Validate and Start

```bash
# JSON validation
jq . config
jq . qwen-modules.json

# Bash syntax check
bash -n scripts/qwen-network.sh

# Test script manually
~/config/waybar/scripts/qwen-network.sh

# Start fresh waybar (no reload needed)
pkill waybar; sleep 0.5; nohup waybar >> /tmp/waybar-startup.log 2>&1 &

# Check startup
sleep 1; grep -E "\[error\]|Bar configured" /tmp/waybar-startup.log | tail -20
```

### 6. Iterate on the Sandbox

While the dev bar is running:
- Edit `scripts/qwen-network.sh` or `style.css`
- Reload: `pkill -SIGUSR2 waybar` (non-destructive)
- Observe visual changes on **only** `bar-horiz-dev`
- Check bar height in the startup log:
  ```
  Bar configured (width: 1920, height: 17) for output: eDP-1   ← Good!
  ```

If the bar height is **larger** than target (e.g., 46px instead of 17px), the module's CSS forces it. Remove `min-height` or reduce `padding` incrementally.

### 7. Port to Production

Once the module is tuned:
1. Merge the script definition into `default-modules.json` (or keep in `config` if bar-specific)
2. Copy the CSS to the production `.bar-horiz` scope or merge with `#custom-<module>`
3. Add the module to `bar-horiz.modules-left`/`modules-right`
4. Delete `bar-horiz-dev` and `qwen-modules.json`

## Common Pitfalls

- **Don't** use `set -euo pipefail` with `grep` pipelines without `|| true` or `wc -l` workaround (see `auto-skill-waybar-script-debug`)
- **Don't** use line-breaks or multi-line formatting in the JSON output — `jq` will preserve newlines and Waybar will render them as paragraph breaks
- **Don't** hard-code `min-width: auto` in CSS — GTK/CSS doesn't support `auto`; use `min-width: 0` or a numeric value
- **Don't** forget `return-type: "json"` in the module definition — Waybar will treat the output as raw text
- **Don't** put dev modules in production files — keep them isolated in sandbox files for easy cleanup
- **Don't** assume scripts produce output — always test manually before expecting Waybar to render them

## Verification Checklist

- [ ] Script output is valid JSON when run manually
- [ ] Script handles "no match" cases gracefully (e.g., disconnected wifi)
- [ ] JSON structure: `{text: string, class: string, tooltip: string}`
- [ ] Module defined with `return-type: "json"` and `interval` set
- [ ] CSS has no `min-height` or `min-width` (or they're `0`)
- [ ] Bar config explicitly lists only the test module
- [ ] Startup log shows bar height matches target (e.g., 17px)
- [ ] State classes (`medium`, `warning`, etc.) are tested visually

## Example: Dev Bar Config

```json
{
  "name": "bar-horiz-dev",
  "layer": "top",
  "position": "top",
  "height": 17,
  "modules-left": ["custom/qwen-network"],
  "modules-center": [],
  "modules-right": [],
  "include": ["/home/lexx/.config/waybar/qwen-modules.json"]
}
```

## Related Skills

- `auto-skill-waybar-script-debug`: Script debugging patterns
- `auto-skill-horizontal-bar-refactor`: Layout and spacing patterns
- `AGENTS.md`: Waybar conventions and signal table
- `STRUCT.md`: Module documentation

## Resources

- `scripts/<module>.sh` — source of truth for module output
- `qwen-modules.json` — isolated module definition
- `style.css` — dev-only CSS block at the end of the file
- `/tmp/waybar-startup.log` — bar height verification
