---
name: waybar-toggle-module
description: Fixed pattern for toggle-style exec modules with signal handling and proper interval
source: auto-skill
extracted_at: '2026-06-15T14:35:00.000Z'
---

# Waybar Toggle Module Pattern

This skill covers the correct way to define toggle-style exec modules that use signal-based refresh and have proper click handling without triggering click-stealing bugs.

## When to Use

Use this pattern when:
- You need a module that can be toggled via click to trigger an action
- The module uses an exec script that refreshes periodically
- You want immediate state updates via signals after a toggle
- The module is grouped with other modules (e.g., icon + info)

## The Core Requirements

Toggle modules **MUST** have three critical properties, or they will malfunction:

1. **`"interval": 1000`** — Required to prevent Waybar's exec loop from stealing all clicks
2. **`"on-click"` pointing to the direct script path** — Must NOT wrap with `sh -c '...' &`
3. **`"signal": N`** — Must have a signal number for refreshing after toggle

## Module Definition Pattern

### Basic Toggle-Style Module

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh refresh",
  "interval": 1000,
  "return-type": "json",
  "format": "{}",
  "on-click": "~/.config/waybar/scripts/<name>.sh",
  "signal": 15
}
```

### Grouped Toggle-Style Modules

When modules are grouped (e.g., icon + info) and both need toggle behavior:

```json
"custom/<name>-icon": {
  "exec": "~/.config/waybar/scripts/<name>-icon.sh refresh",
  "interval": 1000,
  "return-type": "json",
  "format": "{}",
  "on-click": "~/.config/waybar/scripts/<name>-icon.sh",
  "signal": 15
},
"custom/<name>-info": {
  "exec": "~/.config/waybar/scripts/<name>-info.sh refresh",
  "interval": 1000,
  "return-type": "json",
  "format": "{}",
  "on-click": "~/.config/waybar/scripts/<name>-info.sh",
  "signal": 15
}
```

**Note**: If only the info module needs toggle behavior (icon is static), only the info module gets the toggle properties.

## Script Design Requirements

The exec script must handle two scenarios:

1. **Refresh path** (`$1 = "refresh"`): Called periodically by Waybar via exec
2. **Toggle path** (no argument or different first arg): Called from on-click

```bash
#!/bin/bash
set -euo pipefail

# Only signal from toggle path, NEVER from refresh path!
if [ "${1:-}" != "refresh" ]; then
  # Perform the toggle action here
  do-toggle
fi

# Emit current state (called from both paths)
get-state | emit-jq

# IMPORTANT: Signal ONLY from toggle path
if [ "${1:-}" != "refresh" ]; then
  pkill -SIGRTMIN+15 waybar || true
fi
```

### Critical: No Self-Signaling from Refresh

**NEVER** put `pkill -SIGRTMIN+N waybar` in the refresh path or at the end of the script unconditionally:

```bash
# BAD: This causes infinite loop
get-state | emit-jq
pkill -SIGRTMIN+15 waybar || true  # ← Called from exec, triggers exec again!
```

**Good**: Only signal from toggle path:

```bash
# GOOD: Signal only when triggered from click
if [ "${1:-}" != "refresh" ]; then
  pkill -SIGRTMIN+15 waybar || true
fi
```

## Why `interval: 1000` Matters

Setting `"interval": 1000` tells Waybar to run `exec` only about every 1000ms (real behavior is closer to ~17 minutes, but this is the signal trigger threshold). Without this:

1. Waybar runs `exec` continuously, re-parsing the script
2. Combined with signal-based refresh, this creates a click-stealing bug
3. ALL bars treat the module's click area as the toggle button
4. Result: No other modules respond to clicks on any bar

This issue was observed on Waybar v0.15.0 with modules lacking `interval: 1000`.

## Why Direct Script Path in on-click?

**Correct:**
```json
"on-click": "~/.config/waybar/scripts/<name>.sh"
```

**Incorrect:**
```json
"on-click": "sh -c '~/.config/waybar/scripts/<name>.sh &'"
```

Direct paths work with Waybar's exec-based modules. Wrapping with `sh -c '...' &` adds unnecessary complexity and can interfere with Waybar's event routing.

## Complete Example: CPU Module

### qwen-modules.json

```json
"custom/qwen-cpu-icon": {
  "exec": "~/.config/waybar/scripts/qwen-cpu-icon.sh refresh",
  "interval": 1000,
  "return-type": "json",
  "format": "{}",
  "on-click": "~/.config/waybar/scripts/qwen-cpu-icon.sh",
  "signal": 15
},
"custom/qwen-cpu-info": {
  "exec": "~/.config/waybar/scripts/qwen-cpu-info.sh refresh",
  "interval": 1000,
  "return-type": "json",
  "format": "{}",
  "on-click": "~/.config/waybar/scripts/qwen-cpu-info.sh",
  "signal": 15
},
"group/qwen-cpu": {
  "orientation": "horizontal",
  "modules": [
    "custom/qwen-cpu-icon",
    "custom/qwen-cpu-info"
  ]
}
```

### qwen-cpu-icon.sh

```bash
#!/bin/bash

# Always emit current state
emit-jq() {
  local icon=$(printf '\xf3\xb0\x85\x85')  # nf-mdi-chip
  jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
}

case "${1:-}" in
  refresh)
    emit-jq
    exit 0
    ;;
esac

# Toggle action (if any) — unlikely for icon
emit-jq
pkill -SIGRTMIN+15 waybar || true
```

### qwen-cpu-info.sh

```bash
#!/bin/bash
set -euo pipefail

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}

get-state() {
  # Sample CPU, calculate usage, format as JSON
  local output=$(read_samples > /tmp/qb_r1; sleep 0.5; read_samples > /tmp/qb_r2)
  # ... process and format output ...
  jq -n --compact-output --arg text "$text" --arg cls "info" '{text:$text,class:$cls}'
}

case "${1:-}" in
  refresh)
    get-state
    exit 0
    ;;
esac

# Toggle action (e.g., launch htop)
if [ -n "${1:-}" ]; then
  case "$1" in
    htop)
      htop &
      ;;
    system-monitor)
      gnome-system-monitor &
      ;;
  esac
fi

get-state
pkill -SIGRTMIN+15 waybar || true
```

## Debugging Checklist

- [ ] Script syntax valid: `bash -n script.sh`
- [ ] Script produces valid JSON: `script.sh | jq .`
- [ ] Module has `"interval": 1000`
- [ ] Module has `"signal": N` where N is unused
- [ ] Module has `on-click` pointing to script directly (no shell wrapper)
- [ ] Script never signals from refresh path
- [ ] Script uses `|| true` on pkill to avoid exit code issues
- [ ] Module renders correctly after reload: `pkill -SIGUSR2 waybar`

## Signal Table

Pick an unused signal number and document it:

| Signal | Used by |
|---|---|
| `SIGRTMIN+15` | CPU toggle (new) |

Check AGENTS.md or memory.md for allocated signals before picking a new one.

## Related Skills

- `waybar-toggle-button`: Button-style toggle modules for vertical bar
- `auto-skill-waybar-newline-bug`: Handling \n in bash scripts
- `auto-skill-waybar-script-debug`: Debugging silent script failures
- AGENTS.md: Waybar conventions and signal table
- CUSTOM_MODULE_GUIDE.md: Module definition patterns

## Common Pitfalls

- **Don't** forget `interval: 1000` — click stealing bug
- **Don't** put `pkill` in refresh path — infinite loop
- **Don't** wrap `on-click` with `sh -c '...' &` — event routing issues
- **Don't** use same `signal` number as another module — unintended side effects
- **Don't** forget `|| true` on `pkill` — script exits on failure

## Related Skills

- `waybar-module-diagnosis`: Diagnostic procedures for broken modules
- `auto-skill-waybar-newline-bug`: Handling \n in bash scripts
- `auto-skill-waybar-script-debug`: Debugging silent script failures
- AGENTS.md: Waybar conventions and signal table
- CUSTOM_MODULE_GUIDE.md: Module definition patterns

## Resources

- `~/.config/waybar/scripts/toggleDunst.sh`: Working toggle module example
- `~/.config/waybar/scripts/toggle-vpn.sh`: Another working toggle example
- `qwen-modules.json`: Example grouped toggle module definitions
- `default-modules.json`: Reference for module patterns
- `.config/waybar/scripts/`: Where custom toggle scripts live

## See Also

- `waybar-module-diagnosis`: Diagnostic procedures for fixing broken modules
