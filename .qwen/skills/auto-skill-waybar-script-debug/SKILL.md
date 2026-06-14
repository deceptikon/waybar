---
name: waybar-script-debug
description: Debugging Waybar indicator scripts that fail silently due to pipefail and grep exit codes
source: auto-skill
extracted_at: '2026-06-14T15:30:00.000Z'
---

# Waybar Script Debugging Pattern

This skill covers systematic debugging of Waybar indicator scripts that fail silently, particularly those using `set -euo pipefail` with `grep` pipelines that return non-zero exit codes when no match is found.

## When to Use

Use this pattern when:
- A Waybar custom module script is producing **no output** or **empty JSON**
- The script exits silently without errors
- The module appears invisible in the bar
- The script uses `set -euo pipefail`
- The script uses `grep` to check for conditions

## The Problem: Silent Failures

With `set -euo pipefail`, any command that returns non-zero (exit code ≠ 0) will cause the script to exit immediately:

```bash
#!/bin/bash
set -euo pipefail

# PROBLEM: If grep finds no match, it returns exit 1 → script exits
bt_rfkilled=$(rfkill list bluetooth | grep "Soft blocked: yes" | wc -l)
```

When `grep "Soft blocked: yes"` finds no match, it exits with code 1. With `pipefail`, this kills the pipeline, `bt_rfkilled` is never set, and the script exits **before producing any JSON**. Waybar sees an empty module.

## Diagnostic Steps

### 1. Run Script Manually

```bash
# Check if script exists and is executable
test -x ~/.config/waybar/scripts/bt-indicator.sh && echo "OK" || echo "NOT FOUND"

# Full trace with bash -x to see where it fails
bash -x ~/.config/waybar/scripts/<script>.sh 2>&1

# Check exit code explicitly
/home/lexx/.config/waybar/scripts/bt-indicator.sh; echo "EXIT: $?"
```

### 2. Look for Missing Output

If `bash -x` output shows the script starts executing but then stops without reaching `jq -n --compact-output`, the failure is in a pipeline before the output.

### 3. Identify the Pipeline

Look for patterns like:
```bash
variable=$(command | grep "pattern" | wc -l)
```

With `set -euo pipefail`, if `grep` finds no match, the entire pipeline exits with code 1.

## The Fix: Safe Pipelines

### Option 1: Remove `pipefail` (simplest)

```bash
#!/bin/bash

# Remove -o pipefail, keep -eu for basic safety
set -eu

bt_rfkilled=$(rfkill list bluetooth 2>/dev/null | grep "Soft blocked: yes" | wc -l)
```

Without `pipefail`, the pipeline succeeds even if grep returns non-zero.

### Option 2: Use `|| true` or `|| echo "0"` (safe fallback)

```bash
#!/bin/bash
set -euo pipefail

# Add fallback if grep finds nothing
bt_rfkilled=$(rfkill list bluetooth 2>/dev/null | grep -c "Soft blocked: yes" || echo "0")
bt_rfkilled=$((bt_rfkilled + 0))  # ensure it's a valid integer
```

**Note**: The `grep -c || echo "0"` pattern can produce double output (e.g., `0\n0`). The safer approach is option 3.

### Option 3: Use `wc -l` with pipeline (recommended)

```bash
#!/bin/bash
set -euo pipefail

# wc -l always succeeds, so pipeline succeeds
bt_rfkilled=$(rfkill list bluetooth 2>/dev/null | grep "Soft blocked: yes" | wc -l)
bt_rfkilled=$((bt_rfkilled + 0))  # ensure it's a valid integer

connected_devices=$(bt-adapter --list 2>/dev/null | grep "Connected: yes" | wc -l)
connected_devices=$((connected_devices + 0))  # ensure integer
```

This pattern is foolproof:
- `grep` returns non-zero if no match, but the pipeline continues
- `wc -l` always succeeds and counts lines (0 if grep found nothing)
- The arithmetic ensures the variable is a valid integer

### Option 4: Explicit if-checks (most verbose but clearest)

```bash
#!/bin/bash
set -euo pipefail

if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
  bt_rfkilled=1
else
  bt_rfkilled=0
fi
```

## Best Practices

### 1. Default to `set -eu` without `pipefail`

Unless you need strict pipeline error handling, `set -euo` is sufficient. `pipefail` can cause brittle scripts that break on expected "no match" scenarios.

### 2. Always use 2>/dev/null for external commands

```bash
rfkill list bluetooth 2>/dev/null | grep ...
bt-adapter --list 2>/dev/null | grep ...
```

This prevents permission errors or missing commands from breaking the script.

### 3. Use `|| true` for optional checks

For commands that might legitimately fail:

```bash
rfkill list bluetooth 2>/dev/null || true
bt-adapter --list 2>/dev/null || true
```

### 4. Ensure integer variables

After any pipeline that returns strings:

```bash
variable=$((variable + 0))  # ensures it's a valid integer
```

### 5. Test script in isolation

```bash
# Run directly
home/lexx/.config/waybar/scripts/bt-indicator.sh

# Check exit code
/home/lexx/.config/waybar/scripts/bt-indicator.sh; echo "EXIT: $?"

# View JSON output
/home/lexx/.config/waybar/scripts/bt-indicator.sh | jq .
```

## Debug Checklist

- [ ] Script is executable: `test -x script.sh`
- [ ] Script produces JSON output when run manually
- [ ] Script uses `grep` with `|| true` or `wc -l` instead of `pipefail`
- [ ] External commands have `2>/dev/null` to suppress errors
- [ ] Numeric variables are validated with `$((var + 0))`
- [ ] `jq` output is valid: `script.sh | jq .`
- [ ] Module definition in `default-modules.json` has `return-type: "json"`

## Example: Fixed bt-indicator.sh

```bash
#!/bin/bash

# Check bluetooth status via rfkill (wc -l always succeeds)
bt_rfkilled=$(rfkill list bluetooth 2>/dev/null | grep "Soft blocked: yes" | wc -l)
bt_rfkilled=$((bt_rfkilled + 0))  # ensure integer

if [ "$bt_rfkilled" -gt 0 ]; then
  jq -n --compact-output \
    --arg text "󰂲" \
    --arg tooltip "Bluetooth disabled" \
    '{text: $text, class: "disabled", tooltip: $tooltip}'
  exit 0
fi

# Check for connected devices
connected_devices=$(bt-adapter --list 2>/dev/null | grep "Connected: yes" | wc -l)
connected_devices=$((connected_devices + 0))  # ensure integer

if [ "$connected_devices" -gt 0 ]; then
  # ... connection logic ...
else
  jq -n --compact-output \
    --arg text "" \
    --arg tooltip "Bluetooth enabled, no devices connected" \
    '{text: $text, class: "enabled", tooltip: $tooltip}'
fi
```

## Related Skills

- `auto-skill-horizontal-bar-refactor`: Refactoring Waybar layouts and CSS
- `waybar-toggle-button`: Pattern for toggle-style button modules

## Resources

- AGENTS.md: Waybar configuration, JSON conventions, signal patterns
- `default-modules.json`: Module definitions for custom scripts
- `style.css`: CSS styling for custom module selectors
