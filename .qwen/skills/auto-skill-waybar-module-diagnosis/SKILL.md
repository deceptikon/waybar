---
name: waybar-module-diagnosis
description: Diagnostic procedure for identifying and fixing broken Waybar modules showing stale/wrong data
source: auto-skill
extracted_at: '2026-06-15T22:48:24.795Z'
---

# Waybar Module Diagnosis

This skill covers the systematic diagnostic process for identifying and fixing Waybar modules that appear broken, show stale data, or display incorrect information.

## Common Symptoms

### Symptom: Module shows data from wrong module
- **Example**: CPU tile shows RAM data (e.g., "20G", "swap: XX.YY")
- **Cause**: Configuration mismatch, stale Waybar cache, or script not reloaded
- **Solution**: Verify `on-click` and `exec` fields point to correct scripts; reload Waybar

### Symptom: Only wrapper renders (modules in group don't appear)
- **Cause**: Module missing required properties (`interval`, `signal`, `on-click`)
- **Solution**: Add proper toggle module attributes per documented pattern

### Symptom: Module not updating
- **Cause**: Missing `interval` or `signal` configuration
- **Solution**: Add `"interval": 1000` and `"signal": N`

### Symptom: Script runs but returns empty/wrong output
- **Cause**: Script has runtime error or missing dependencies
- **Solution**: Test script manually with `script.sh refresh` and check stderr

## Step 1: Verify Configuration

### Check Module Definition in JSON

The module must have the correct structure:

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh refresh",
  "interval": 1000,        // CRITICAL: prevents click-stealing
  "signal": 15,            // Choose unused signal number
  "on-click": "~/.config/waybar/scripts/<name>.sh",
  "format": "{}",
  "return-type": "json"
}
```

**Key checks:**
- ✅ `interval: 1000` present
- ✅ `signal: N` present (unique number)
- ✅ `on-click` points directly to script (no shell wrapper)
- ✅ `exec` includes `refresh` argument

### Check Group Configuration

If module is inside a group:

```json
"group/<name>": {
  "orientation": "horizontal",
  "modules": [
    "custom/<name>-icon",
    "custom/<name>-info"
  ]
}
```

**Common issues:**
- Module name in `modules` array doesn't match definition
- Group orientation is wrong for the layout

## Step 2: Test Scripts Manually

Run each script manually to verify output:

```bash
# Test exec path (refresh mode)
~/.config/waybar/scripts/<name>.sh refresh | jq .

# Test click path (toggle mode)
~/.config/waybar/scripts/<name>.sh | jq .

# Check syntax
bash -n ~/.config/waybar/scripts/<name>.sh
```

### Expected Output Format

Scripts must output valid JSON:

```json
{
  "text": "display content",
  "class": "good|warning|critical|icon|info"
}
```

### Debugging Script Issues

If script fails:
1. Check stderr: `script.sh 2>&1 | head -10`
2. Check exit code: `script.sh; echo $?`
3. Look for missing variables: `set -euo pipefail; script.sh`
4. Check file permissions: `ls -la script.sh`

## Step 3: Reload Waybar

After making changes:

```bash
# Reload (preserves state)
pkill -SIGUSR2 waybar

# Or restart (full reload)
pkill waybar && waybar &
```

**Wait 2-3 seconds** for Waybar to fully reload before checking results.

## Step 4: Verify with Dev Bar

Test on dev bar first before applying to production bars:

```json
{
  "name": "bar-horiz-dev",
  "modules-left": ["group/<your-module>"],
  "include": ["~/.config/waybar/qwen-modules.json"]
}
```

**Benefits:**
- Isolated testing environment
- No interference from production modules
- Faster feedback loop

## Common Configuration Errors

### Error: Module shows "wrong data"
```json
// BAD: wrong script reference
"custom/qwen-cpu-info": {
  "exec": "~/.config/waybar/scripts/qwen-ram-info.sh"  // ← Wrong!
}

// GOOD
"custom/qwen-cpu-info": {
  "exec": "~/.config/waybar/scripts/qwen-cpu-info.sh"
}
```

### Error: Module doesn't update
```json
// BAD: no interval
"custom/qwen-cpu": {
  "exec": "~/.config/waybar/scripts/cpu.sh"
}

// GOOD
"custom/qwen-cpu": {
  "exec": "~/.config/waybar/scripts/cpu.sh refresh",
  "interval": 1000
}
```

### Error: Click stealing behavior
```json
// BAD: missing interval causes click stealing
"custom/my-toggle": {
  "on-click": "script.sh",
  "exec": "script.sh refresh",
  // Missing: interval and signal
}

// GOOD
"custom/my-toggle": {
  "on-click": "script.sh",
  "exec": "script.sh refresh",
  "interval": 1000,
  "signal": 15
}
```

## Debugging Checklist

- [ ] Run `bash -n script.sh` to check syntax
- [ ] Run `script.sh refresh | jq .` to verify JSON output
- [ ] Check `qwen-modules.json` or `default-modules.json` for module definition
- [ ] Verify `"interval": 1000` is present
- [ ] Verify `"signal": N` is present (unique)
- [ ] Verify `on-click` points to script directly
- [ ] Check group definition in config
- [ ] Reload Waybar: `pkill -SIGUSR2 waybar`
- [ ] Test on dev bar before production
- [ ] Wait 2-3 seconds after reload

## Signal Number Selection

Choose an unused signal number:

1. Check AGENTS.md or MEMORY.md for allocated signals
2. Pick an unused number (10-15 are typically available)
3. Document choice for future reference

**Warning**: Don't use same signal for multiple modules - causes unintended side effects.

## Related Skills

- `waybar-toggle-module`: Toggle module pattern for exec-based modules
- `auto-skill-waybar-newline-bug`: \n handling in bash scripts
- `auto-skill-waybar-script-debug`: Diagnosing silent script failures
- AGENTS.md: Waybar conventions and signal table
- CUSTOM_MODULE_GUIDE.md: Module definition patterns

## Resources

- `~/.config/waybar/config`: Main configuration file
- `~/.config/waybar/qwen-modules.json`: Custom module definitions
- `~/.config/waybar/default-modules.json`: Built-in module patterns
- `~/.config/waybar/scripts/`: Custom script directory
