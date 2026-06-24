---
name: waybar-module-json-exec-compact
description: Exec modules must output compact single-line JSON; jq -n must use -c flag
source: auto-skill
extracted_at: '2026-06-24T00:00:00.000Z'
---

# Waybar Exec Modules: Compact JSON Output Requirement

## Overview
Waybar's exec modules return their output via stdout, which Waybar parses as JSON. **GTK's JSON parser only accepts compact single-line JSON output.** Using `jq -n` (pretty-print mode) causes JSON parse errors that hide the module or crash Waybar.

## The Problem

### Symptom 1: Module Hidden with Error
```bash
[2026-06-24 03:20:51.200] [error] custom/ollama: Error parsing JSON: * Line 1, Column 2
  Missing '}' or object member name
```

### Symptom 2: GTK Widget Tree Missing Module
```bash
[debug] GTK widget tree:
label#custom-ollama.module:dir(ltr)  ← Shows empty/hidden module
```

## Root Cause

**Wrong: `jq -n` (default is multi-line, indented)**
```json
{
  "text": " UP",
  "tooltip": "Ollama is running",
  "class": "on"
}
```

This multi-line output with newlines and indentation is NOT valid JSON from Waybar's perspective because:
1. Newlines break the parser's expectation of a single token
2. `jq -n` adds whitespace and newlines automatically

**Correct: `jq -cn` (`-c` flag = **compact** output)**
```json
{"text":" UP","tooltip":"Ollama is running","class":"on"}
```

This single-line, no-whitespace JSON is valid and parseable.

## Pattern: Always Use `jq -c` for Exec Modules

### Before (Broken)
```bash
# ❌ WRONG - crashes/hidden module
exec: "if curl -s http://localhost:11111/api/tags > /dev/null 2>&1; then
  jq -n '{text:\" UP\",tooltip:\"Ollama is running\",class:\"on\"}'
else
  jq -n '{text:\" DOWN\",tooltip:\"Ollama is not running\",class:\"off\"}'
fi"
```

### After (Fixed)
```bash
# ✅ CORRECT - compact output
exec: "if curl -s http://localhost:11111/api/tags > /dev/null 2>&1; then
  jq -cn '{text:\" UP\",tooltip:\"Ollama is running\",class:\"on\"}'
else
  jq -cn '{text:\" DOWN\",tooltip:\"Ollama is not running\",class:\"off\"}'
fi"
```

**Note:** `jq -cn` = `--compact-output` + `--null-input`, produces single-line JSON.

## Other Ways to Output Compact JSON

### Method 1: Python (no whitespace)
```bash
# ✅ CORRECT - print doesn't add extra whitespace
exec: "python3 -c \"import json; print(json.dumps({'text':' UP','tooltip':'Running','class':'on'}))\""
```

### Method 2: jq raw mode (no quotes)
```bash
# ✅ CORRECT - raw output, no extra formatting
exec: "jq -cn '.text = \" UP\" | .tooltip = \"Running\" | .class = \"on\"'"
```

### Method 3: Echo pre-formatted string (avoid if possible)
```bash
# ⚠️ WORKS but harder to escape quotes
exec: "echo '{\"text\":\" UP\",\"tooltip\":\"Running\",\"class\":\"on\"}'"
```

## How to Diagnose

### Step 1: Check exec output directly
```bash
# Test the exec command in isolation
bash -c "exec_command_from_config" | cat -A
# If you see \n or multi-line output → COMPACT IT
```

### Step 2: Check Waybar logs
```bash
tail -20 logs/waybar-vertical.log | grep -i "error\|json"
# Look for: "Error parsing JSON" or "Missing '}' or object member name"
```

### Step 3: Check if module has definition
```bash
grep "custom/ollama" config-*.json modules-*.json
# If exec is wrong, module will be hidden even though definition exists
```

## Common Scenarios

### Scenario 1: Ollama Status Module
**Original (broken):**
```bash
custom/ollama: {
  exec: "jq -n '{text:\" UP\",\"tooltip\":\"Running\",\"class\":\"on\"}'",  # ← no -c
  return-type: "json"
}
```

**Fixed:**
```bash
custom/ollama: {
  exec: "jq -cn '{text:\" UP\",\"tooltip\":\"Running\",\"class\":\"on\"}'",  # ← -c flag
  return-type: "json"
}
```

### Scenario 2: Dynamic Status Updates
**Original (broken):**
```bash
exec: "tail -F feed/status.json 2>/dev/null | jq ."  # ← outputs multi-line
```

**Fixed:**
```bash
exec: "tail -F feed/status.json 2>/dev/null | jq -c ."  # ← compact
```

### Scenario 3: Complex Command with Conditionals
**Original (broken):**
```bash
exec: "if [ -f /tmp/status ]; then jq -n '{class:\"active\"}'; else jq -n '{class:\"inactive\"}'; fi"
```

**Fixed:**
```bash
exec: "if [ -f /tmp/status ]; then jq -cn '{class:\"active\"}'; else jq -cn '{class:\"inactive\"}'; fi"
```

## Testing After Fix

```bash
# 1. Test exec in isolation
bash -c "$exec_command" | jq .  # Should format correctly if compact

# 2. Reload waybar
pkill -x waybar
sleep 0.5

# 3. Check logs for JSON parse errors
waybar -c config-vertical -s style/vertical.css > logs/test.log 2>&1 &
sleep 2
grep -i "json" logs/test.log | grep -i "error"
# Should show zero errors

# 4. Check widget tree
grep "custom/ollama" logs/test.log
# Should show: "label#custom-ollama.module" (visible module)
```

## Related Gotchas

### `return-type: "json"` vs No JSON
**Always use `return-type: "json"` for exec-based JSON modules:**
```bash
custom/ollama: {
  exec: "...",  # outputs JSON
  return-type: "json",  # ← required
  format: "{}"  # ← uses JSON output
}
```

**Without `return-type`, Waybar treats output as plain text.**

### Multiple exec outputs (e.g., from loop)
If exec outputs multiple JSON lines (not valid for single module):
```bash
# ❌ WRONG - outputs multiple JSON objects
exec: "for i in 1 2 3; do jq -cn '{id:$i}'; done"  # → JSON parse error

# ✅ CORRECT - single JSON object
exec: "jq -cn '{id:[$1,$2,$3]}' <<< '1 2 3'"
```

## Pattern Reference

| Tool | Compact Mode | Non-Compact Mode |
|------|--------------|------------------|
| `jq` | `jq -c` | `jq` (default) |
| `jq` | `jq -cn` | `jq -n` |
| `python` | `print(json.dumps(obj))` | `pprint.pprint(obj)` |
| `node` | `console.log(JSON.stringify(obj))` | `console.log(obj)` |

## Commit Template

When documenting JSON compact fix:

```
Fix: exec module JSON parse error

**Changes:**
- custom/ollama: exec now uses `jq -cn` instead of `jq -n`
  - Reason: GTK JSON parser requires compact single-line output
  - Without `-c`: multi-line JSON → "Error parsing JSON" error
  - With `-c`: single-line JSON → module visible and styled

**Validation:**
- All configs valid JSON
- exec output tests pass: `bash -c "$exec" | jq .`
- No "Error parsing JSON" in logs after reload
- Widget tree shows module as visible

**Files changed:**
- modules-controls.json: exec strings for custom/ollama
```

## Related Skills
- `auto-skill-waybar-module-reorganization` — Module positioning
- `auto-skill-waybar-gtk-quirks` — text-align crashers, color visibility
- `auto-skill-waybar-gtk-box-model` — Padding and bar height issues
