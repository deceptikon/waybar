# AGENTS.md — Waybar Configuration

## Overview
Wayland status bar (Waybar) on Sway WM (ASUS ZenBook). 4 bars: top (eDP-1 + HDMI-A-1), vertical (right), vertical-lite (right, hidden), bottom.

## Commands

| Action | Command |
|---|---|
| Start all bars | `scripts/waybar-start.sh start` |
| Full restart | `scripts/waybar-start.sh reload` |
| Stop all | `scripts/waybar-start.sh stop` |
| Sway hotkey | `$mod+Shift+w` |
| Validate JSON | `for f in config-* modules-*.json; do jq . "$f" /dev/null 2>&1; done` |
| Validate CSS | `waybar -c config-vertical -s style/vertical.css` (check stderr) |
| Check script syntax | `bash -n scripts/**/*.sh` |

## File Structure

```
config-top                # Top bar (array: eDP-1 + HDMI-A-1), includes config-top-base.jsonc
config-top-base.jsonc     # Shared top-bar settings (layer, position, module lists)
config-vertical           # Vertical bar (bar-vert, right side)
config-vertical-lite      # Vertical lite bar (bar-vert-lite, hidden, toggleable)
config-bottom             # Bottom bar (bar-bottom)

modules-sysmon.json       # Sysmon monitor groups (GPU, CPU, RAM, SSD, ASUS, network)
modules-controls.json     # Action/toggle controls (ppd, dunst, ollama, ext-display, etc.)
modules-peripherals.json  # Hardware controls (audio, backlight, battery, bluetooth, powerbtn)
modules-top-shared.json   # Top-bar shared (clock, workspaces, window title, privacy, scratchpad)

style/base.css            # Shared: reset, fonts, battery, sliders, animations
style/top.css             # Top bar overrides + Catppuccin @define-color
style/vertical.css        # Vertical bar (full mode)
style/vertical-lite.css   # Vertical lite mode (compact)
style/bottom.css          # Bottom bar

scripts/waybar-start.sh   # Start/reload/stop all 4 bars
scripts/utils/            # Utility scripts (toggle-vert-lite, fn-lock, dunst, etc.)
scripts/sysmon/           # Sysmon pipeline (poller, collect, mapper, frame, compact-*.py)
scripts/network/          # Network scripts (wifi-info.sh)
```

## Key Decisions
- **No SIGUSR2 reload**: GLib assertion crash with multiple bar instances. Full restart (`waybar-start.sh reload`) is the only reliable method.
- **Per-bar D-Bus names**: `bar-top` / `bar-top-ext` avoids name conflicts within a single waybar process.
- **Vertical bars share `start_hidden`**: Lite bar starts hidden, toggle sends SIGUSR1 to swap visibility.
- **Group-based modules**: `group/audio`, `group/bright`, `group/qwen-*` combine icon + info sub-modules.

## Data Flow — sysmon Pipeline

```
poller.sh (background, every 2s)
  → collect.sh (reads /proc/* + /sys/* + sensors)
  → mapper.sh (parses → /tmp/sysmon.json)

6 waybar modules (interval 2, return-type: json):
  custom/qwen-<metric> → tail -F feeds/<metric>.json (written by poller via frame.sh)
  custom/qwen-<metric>-icon → sysmon/icon.sh <metric> (static glyph, interval: once)

Vertical-lite uses compact Python scripts instead:
  custom/compact-{gpu,cpu,ram,ssd} → sysmon/compact-*.py (reads /tmp/sysmon.json directly)
```

## Signal Convention

| Signal | Module(s) |
|---|---|
| `SIGRTMIN+8` | Recorder, checkupdates, keyboard backlight |
| `SIGRTMIN+9` | Dunst toggle |
| `SIGRTMIN+10` | ASUS profile switch, fnlock |
| `SIGRTMIN+11` | External display toggle, DDC brightness |
| `SIGRTMIN+22` | Llama server toggle |

## CSS Conventions
- **Selector naming**: `/` and `#` in module IDs become `-` (e.g., `bluetooth#lite` → `#bluetooth-lite`, `group/audio` → `#group-audio`).
- **GTK CSS subset**: No `line-height`, `text-align`, `max-width`, `min-width: auto`. Use numeric px only.
- **State classes**: `.warning`, `.critical`, `.activated`, `.paused`, `.recording`, `.on`, `.off`, `.disconnected`.
- **Font**: `"Monaspace Krypton Frozen", "JetBrainsMono Nerd Font", "MesloLGS Nerd Font", monospace`.

## Bash Conventions
- `set -euo pipefail` in startup/side-effect scripts. **Never** in waybar exec scripts (grep may exit 1).
- JSON output via `jq -cn` / `jq --compact-output`.
- Do NOT call `pkill -SIGRTMIN+N` from exec/refresh path (infinite loop). Only from on-click handlers.
- Background processes: `... & disown`.

## Adding a Module
1. Define in the appropriate `modules-*.json`.
2. Add to the bar's `modules-left/center/right`.
3. Add CSS rules in the bar's style file.
4. If using a script, place in `scripts/` and `chmod +x`.
5. Restart: `scripts/waybar-start.sh reload`.
