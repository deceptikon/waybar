# AGENTS.md — Waybar Configuration

## Overview
Wayland status bar (Waybar) on Sway WM (ASUS ZenBook). 4 bars: top (eDP-1 + HDMI-A-1), vertical (right), vertical-lite (right, hidden), bottom.

**Location in monorepo:** `arch-deploy/dotfiles/dot_config/waybar/`  
Deployed by chezmoi to: `~/.config/waybar/`  
All scripts are prefixed `executable_` so chezmoi sets `chmod +x` automatically.

## Commands

| Action | Command |
|---|---|
| Start all bars | `waybar-start.sh start` |
| Full restart | `waybar-start.sh reload` |
| Stop all | `waybar-start.sh stop` |
| Sway hotkey | `$mod+Shift+w` |
| Validate JSON | `for f in config-* modules-*.json; do jq . "$f" > /dev/null && echo OK: $f; done` |
| Validate CSS | `waybar -c config-vertical -s style/vertical.css` (check stderr) |
| Check script syntax | `bash -n scripts/executable_*.sh scripts/**/*.sh` |

## File Structure

```
config-top.tmpl                    # Top bar (array: eDP-1 + HDMI-A-1), includes config-top-base.jsonc — chezmoi template
config-top-base.jsonc.tmpl         # Shared top-bar settings (layer, position, module lists) — chezmoi template
config-vertical.tmpl               # Vertical bar (bar-vert, right side) — chezmoi template
config-vertical-lite.tmpl          # Vertical lite bar (bar-vert-lite, hidden, toggleable) — chezmoi template
config-vertical-base.jsonc.tmpl    # Shared vertical settings — chezmoi template
config-bottom.tmpl                 # Bottom bar — chezmoi template

modules-sysmon.json                # Sysmon monitor groups (GPU, CPU, RAM, SSD, ASUS, network)
modules-vc.json                    # Action/toggle controls (ppd, dunst, ollama, ext-display, etc.)
modules-peripherals.json           # Hardware controls (audio, backlight, battery, bluetooth, powerbtn)
modules-top-shared.json            # Top-bar shared (clock, workspaces, window title, privacy, scratchpad)

style/base.css                     # Shared: reset, fonts, battery, sliders, animations
style/top.css                      # Top bar overrides + Catppuccin @define-color
style/vertical.css                 # Vertical bar (full mode)
style/vertical-lite.css            # Vertical lite mode (compact)
style/bottom.css                   # Bottom bar

scripts/executable_waybar-start.sh # Start/reload/stop all 4 bars (chmod +x via chezmoi executable_ prefix)
scripts/utils/                     # Utility scripts — all named executable_*.sh for chezmoi
scripts/sysmon/                    # Sysmon pipeline (executable_poller.sh, executable_collect.sh, etc.)
scripts/network/                   # Network scripts (executable_wifi-info.sh)
scripts/lib/                       # Shared lib (executable_draw-module.sh)
```

## Key Decisions
- **No SIGUSR2 reload**: GLib assertion crash with multiple bar instances. Full restart (`waybar-start.sh reload`) is the only reliable method.
- **Per-bar D-Bus names**: `bar-top` / `bar-top-ext` avoids name conflicts within a single waybar process.
- **Vertical bars share `start_hidden`**: Lite bar starts hidden; `toggle-vert-lite.sh` sends SIGUSR1 to swap visibility.
- **Group-based modules**: `group/audio`, `group/bright`, `group/qwen-*` combine icon + info sub-modules.
- **chezmoi `executable_` prefix**: ALL scripts in `scripts/` are prefixed `executable_` — this is how chezmoi sets the execute bit on deploy. Do NOT rename them without the prefix or the scripts will land as non-executable files.

## Data Flow — sysmon Pipeline

```
poller.sh (background, every 2s)
  → collect.sh (reads /proc/* + /sys/* + sensors)
  → mapper.sh (parses → /tmp/sysmon.json)
  → formatter.sh (reads /tmp/sysmon.json → writes feeds/<metric>.json + feeds/compact-<metric>.json)

All bars consume via tail -F:
  vertical full + top → tail -F feeds/{gpu,cpu,ram,ssd,asus,network}.json
  vertical-lite       → tail -F feeds/compact-{gpu,cpu,ram,ssd}.json
  icon modules        → sysmon/icon.sh <metric> (interval: once, static glyph)
```

## Signal Convention

| Signal | Module(s) |
|---|---|
| `SIGRTMIN+8` | Recorder, checkupdates, keyboard backlight |
| `SIGRTMIN+9` | Dunst toggle |
| `SIGRTMIN+10` | ASUS profile switch, fnlock |
| `SIGRTMIN+11` | DDC brightness (ext-display uses interval, not signal) |
| `SIGRTMIN+22` | Llama server toggle |

## CSS Conventions
- **Selector naming**: `/` and `#` in module IDs become `-` (e.g., `bluetooth#lite` → `#bluetooth-lite`, `group/audio` → `#group-audio`).
- **GTK CSS subset**: No `line-height`, `text-align`, `max-width`, `min-width: auto`. Use numeric px only.
- **State classes**: `.warning`, `.critical`, `.activated`, `.paused`, `.recording`, `.on`, `.off`, `.disconnected`.
- **Font**: `"Monaspace Krypton Frozen", "JetBrainsMono Nerd Font", "MesloLGS Nerd Font", monospace`.

## Bash Conventions
- **NO `set -euo pipefail`** in waybar `exec`/`return-type: json` scripts — `grep`, `yay -Qu`, etc. return non-zero when they find nothing. `errexit` will kill the script and Waybar shows an empty/broken module.
- `set -euo pipefail` IS correct in `waybar-start.sh` and other side-effect scripts.
- JSON output via `jq -cn` / `jq --compact-output`.
- Log errors to `/tmp/waybar_errors.log` — never silence with `>/dev/null`. Stray stdout breaks JSON parsing in Waybar.
- `command -v foo >/dev/null` is correct for availability checks in exec scripts (redirect stdout only, let stderr flow).
- Do NOT call `pkill -SIGRTMIN+N` from exec/refresh path (infinite loop). Only from on-click handlers.
- Background processes: `... & disown`.

## Adding a Module
1. Define in the appropriate `modules-*.json`.
2. Add to the bar's `modules-left/center/right`.
3. Add CSS rules in the bar's style file.
4. If using a script, place in `scripts/` and `chmod +x`.
5. Restart: `scripts/waybar-start.sh reload`.
