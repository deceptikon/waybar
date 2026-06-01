---
name: waybar-toggle-button
description: Pattern for adding a new toggle-style button module to the Waybar right (vertical) panel, following the existing fnlock/dunst/backlight conventions.
source: auto-skill
extracted_at: '2026-06-01T03:45:00.000Z'
updated_at: '2026-06-01T03:50:00.000Z'
---

# Adding a Toggle Button to Waybar

This skill covers adding a new icon-style toggle button to the vertical bar (`bar-vert`) right section, visually matching siblings like `custom/dunst`, `custom/fnlock`, and `custom/backlight`.

## Overview of the Pattern

Each toggle button has four parts:
1. A **bash script** in `~/.config/waybar/scripts/` that (a) queries the real state from the source-of-truth command, (b) toggles the state when invoked without `refresh`, and (c) emits JSON for Waybar to render.
2. A **module definition** in `config` (at bar-vert level) pointing to the script with a free `SIGRTMIN+N` signal.
3. **CSS rules** in `style.css` covering the default look plus `.on` / `.off` (or similarly named) state classes.
4. **Docs updates** in `STRUCT.md` and the signal table in `AGENTS.md`.

## 1. Detect the Target

Before writing anything, confirm what you're toggling:

```bash
# For displays
swaymsg -t get_outputs | jq -r '.[] | "\(.name) \(.make) \(.model) \(.active)"'
# For audio sinks
pactl list sinks short
# For bluetooth
bluetoothctl devices
```

Hard-code the resulting identifier (e.g. `HDMI-A-1`) as a variable at the top of the script.

## 2. Write the Toggle Script

Use a `case` structure that cleanly separates the toggle path (from `on-click`) from the refresh path (from `exec`). The toggle path is the **only** place a signal should fire:

```bash
#!/bin/bash
set -euo pipefail

TARGET="<identifier>"

get_state() {
  # Query real state from source of truth; echo "on" or "off"
  ...
}

emit() {
  local state="$1"
  if [ "$state" = "on" ]; then
    jq -n --compact-output '{
      text: "<icon-on>",
      tooltip: "... ON",
      class: "on"
    }'
  else
    jq -n --compact-output '{
      text: "<icon-off>",
      tooltip: "... OFF",
      class: "off"
    }'
  fi
}

case "${1:-}" in
  toggle)
    current=$(get_state)
    if [ "$current" = "on" ]; then
      # command to turn off
    else
      # command to turn on
    fi
    # Signal ONLY on toggle — never from refresh path
    pkill -SIGRTMIN+<N> waybar || true
    ;;
  refresh|"")
    ;;
esac

# Always emit current state (exec calls this via the refresh path)
emit "$(get_state)"
```

Key points:
- Use `jq -n --compact-output` for JSON, never string interpolation.
- Query the real state (don't cache in a state file) so the button stays in sync if the user changes state outside Waybar.
- Use `|| true` on the pkill so `set -e` doesn't abort the script if waybar isn't running.
- Icons are Nerd Font glyphs — pick an enabled/disabled pair (e.g. `󰍹` / `󰍺`).
- **No `sleep` calls** — they add latency and blocking. `swaymsg` and similar commands are already synchronous.
- **Never** put `pkill -SIGRTMIN+N waybar` in the refresh path or at the script's end — `exec` will call `refresh` periodically, so a self-signal there triggers `exec` again → infinite loop → CPU spike (see pitfalls below).
- Make executable: `chmod +x ~/.config/waybar/scripts/<script>.sh`.
- Test: `~/.config/waybar/scripts/<script>.sh refresh` should emit valid JSON and complete quickly.

## 3. Pick a Free Signal

Check the signal table at the bottom of `AGENTS.md`. Currently allocated signals:

| Signal | Used by |
|---|---|
| `SIGRTMIN+3` | VPN toggle |
| `SIGRTMIN+8` | Recorder, checkupdates, keyboard backlight |
| `SIGRTMIN+9` | Dunst toggle |
| `SIGRTMIN+10` | ASUS profile switch |
| `SIGRTMIN+11` | External display toggle |

Pick the next free number and register it in the table.

## 4. Wire into config

Add the module name to `bar-vert.modules-right`, then define it at **bar-vert level** (sibling to `custom/fnlock` and `custom/backlight`), not in `default-modules.json`:

```json
"modules-right": [
  ...,
  "custom/<new-module>"
],
...
"custom/<new-module>": {
  "exec": "~/.config/waybar/scripts/<script>.sh refresh",
  "return-type": "json",
  "format": "{}",
  "on-click": "sh -c '~/.config/waybar/scripts/<script>.sh toggle &'",
  "signal": <N>
}
```

The `on-click` line uses `sh -c '... &'` to launch the script **non-blocking**. If you use a bare `"on-click": "script.sh"` without `&`, the script blocks Waybar's event router and can cause all bars to become clickable trigger areas (Waybar bug).

Validate: `jq . config`.

## 5. Add CSS Styling

Add the new `#custom-<new-module>` selector to the existing vertical-bar button group in `style.css` (the one that starts with `#custom-powerbtn, #idle_inhibitor, ...`). This gives it the standard teal-bordered look for free:

```css
#custom-powerbtn,
...,
#custom-<new-module>,
#custom-checkupdates {
   border: 1px solid rgba(0, 128, 128, 0.3);
   border-top: 2px solid lightseagreen;
   border-bottom: 2px solid teal;
   border-radius: 8px;
   margin: 2px 4px;
   min-height: 20px;
   min-width: 30px;
   color: #249e94;
   font-size: 24px;
   padding: 4px;
   box-shadow: -1px 1px 3px rgba(0, 128, 128, 0.3);
}
```

Then add a state-specific block matching the class names from the script:

```css
#custom-<new-module>.on {
    border: 1px solid lightseagreen;
    box-shadow: -1px 1px 5px rgba(222, 90, 0, 0.95);
    border-bottom: 4px solid teal;
    color: #90ee90;
}

#custom-<new-module>.off {
    color: #555;
    border: 1px solid rgba(100, 100, 100, 0.3);
    box-shadow: none;
}
```

Also add `#custom-<new-module>.on` to the combined "active highlight" selector group alongside `#custom-backlight.active`, `#custom-fnlock.active`, etc.

CSS selector rule reminder: `custom/<name>` becomes `#custom-<name>` (kebab-case, `/` → `-`).

## 6. Update Documentation

- **STRUCT.md**: add a `custom/<new-module>:` block under the `modules:` section with the exec/format/signal fields.
- **AGENTS.md**: add a row to the Signal Convention table mapping `SIGRTMIN+<N>` → purpose.

## 7. Validate and Reload

```bash
bash -n ~/.config/waybar/scripts/<script>.sh   # syntax check
jq . config                                      # JSON validity
pkill -SIGUSR2 waybar                           # non-destructive reload
pgrep waybar > /dev/null && echo OK              # verify still running
```

## Common Pitfalls

- **Don't** put the new module definition in `default-modules.json` if it needs to live only on `bar-vert` — put it as a key directly inside the `bar-vert` object in `config`.
- **Don't** cache state in `/tmp/<...>.state` files if the real state can change elsewhere (e.g. user opens `wdisplays` and disables HDMI manually). Always re-query the source of truth.
- **Don't** forget the `|| true` on the final `pkill -SIGRTMIN+N waybar` call, or `set -e` will kill the script on reload failure.
- **Don't** escape Nerd Font glyphs in `old_string`/`new_string` when editing CSS — match them literally as they appear in the file.
- **Don't** let `on-click` call the script synchronously (bare `"on-click": "script.sh"`). Always wrap in `sh -c '... &'` so it runs non-blocking. A blocking `on-click` will lock up Waybar's event routing — all bars become clickable trigger areas for that module, requiring a full Waybar restart to recover.
- **Don't** put `pkill -SIGRTMIN+N waybar` in the `exec` / `refresh` path, or at the end of the script unconditionally. The `exec` field calls `refresh` periodically (per `interval`), so if `refresh` self-signals, it triggers `exec` again → infinite loop → orphaned script processes pile up under Waybar → sustained CPU spike (observed: 5-6% waybar CPU, 70+ min accumulated over 24 hours). The signal must live **only** in the `toggle)` branch, fired from `on-click`.
- **Don't** use `sleep` in toggle scripts — it serves no purpose for synchronous commands like `swaymsg` and adds unnecessary latency.

