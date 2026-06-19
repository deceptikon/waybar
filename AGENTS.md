# AGENTS.md — Waybar Configuration

## Project Overview
This is a **Waybar** (Wayland status bar) configuration for a Sway WM setup on an ASUS ZenBook. It is **not** a software project — there are no build, lint, or test commands. Changes take effect by reloading Waybar.

## Commands

| Action | Command |
|---|---|
| Reload both Waybars (sway hotkey) | `$mod+Shift+w` (runs `$waybar-start` in sway config) |
| Restart both Waybars | `pkill waybar 2>/dev/null && (waybar &) && (waybar -c ~/.config/waybar/config-vertical -s ~/.config/waybar/style-new.css &)` |
| Run vertical bar only (alias) | `waybar-vert` |
| Validate JSON | `jq . config && jq . config-vertical && jq . default-modules.json && jq . default-modules-v2.json` |
| Validate CSS | `gtk-launch waybar` (check stderr for CSS warnings) |
| Run a script manually | `~/.config/waybar/scripts/<script>.sh` |
| Check script syntax | `bash -n ~/.config/waybar/scripts/<script>.sh` |

## File Structure

```
config                  # Horizontal bars (bar-low, bar-horiz-dev, bar-horiz)
config-vertical         # Vertical bar only (bar-vert), uses style-new.css
default-modules.json    # Module definitions (primary, 374 lines)
default-modules-v2.json # Module definitions (secondary, 88 lines)
style.css               # GTK CSS for horizontal bars
style-new.css           # GTK CSS for vertical bar
STRUCT.md               # Module hierarchy documentation
scripts/                # Custom module scripts (bash)
scripts/lib/            # Shared libraries (draw-module.sh)
```

## sysmon-collect Pipeline

Single-pass data collection pipeline for all monitoring modules.

```
sysmon-raw3.sh          # Collector: reads /proc/* + sensors + sysfs (two CPU snaps)
        │ pipe
        ▼
sysmon-mapper.sh        # Parser: labeled sections → unified JSON tree (+ CPU delta)
        │ pipe
        ▼
sysmon-format.sh        # Formatter: JSON → 5 Waybar-ready JSON lines (GPU/CPU/RAM/SSD/TEMP)
```

| Command | Description |
|---|---|
| `bash scripts/sysmon-collect.sh \| bash scripts/sysmon-mapper.sh` | Full pipeline to JSON |
| `bash scripts/sysmon-collect.sh \| bash scripts/sysmon-mapper.sh \| bash scripts/sysmon-format.sh` | Full to formatted output |
| `watch -n 2 'bash scripts/sysmon-collect.sh \| bash scripts/sysmon-mapper.sh \| bash scripts/sysmon-format.sh'` | Live refresh |

## draw-module.sh Library

Located at `scripts/lib/draw-module.sh`. Called by all info scripts:

```bash
source "$(dirname "$0")/lib/draw-module.sh"
draw_module <icon> <row1> <row2> <color_hex> [class]
```

Produces 3-line Pango text (icon + two data rows) with accent color and Waybar state class.

## sysmon-frame.sh — Unified Module

A single script replaces all separate monitor modules. Called with metric as arg:

```bash
~/.config/waybar/scripts/sysmon-frame.sh gpu
```

Waybar config uses `custom/sysmon_frame#<metric>` variants:
```json
"custom/sysmon_frame#gpu": {
  "exec": "~/.config/waybar/scripts/sysmon-frame.sh gpu",
  "interval": 2, "return-type": "json"
}
```

Each variant gets its own CSS selector (`#custom-sysmon_frame-gpu`) with colored border.

| Metric | Icon | Accent | CSS selector |
|---|---|---|---|
| `gpu` | 󰢮 | `#fab387` peach | `#custom-sysmon_frame-gpu` |
| `cpu` | 󰍛 | `#a6e3a1` green | `#custom-sysmon_frame-cpu` |
| `ram` |  | `#89b4fa` blue | `#custom-sysmon_frame-ram` |
| `ssd` | 󰋊 | `#a6e3a1` green | `#custom-sysmon_frame-ssd` |
| `temp` | 󰔐 | `#f38ba8` red | `#custom-sysmon_frame-temp` |
| `asus` |  | `#94e2d5` teal | `#custom-sysmon_frame-asus` |

`draw_module` draws a unicode box table with icon in left column (merged rows) and data in right column. Pango markup inside cells preserves formatting. CSS is transparent — the box is entirely Pango-drawn.

## Sysmon JSON Schema

```json
{
  "ts": 1718000000,
  "cpu":    { "avg": 12, "per_core": [12,3,16,...] },
  "ram":    { "used_kb": 25371204, "total_kb": 31940168, "avail_kb": 6568964, "used_pct": 79, "swap_used_kb": 1979732, "swap_total_kb": 33554428, "swap_pct": 5 },
  "disk":   { "read_sectors": 49513460, "write_sectors": 5475401 },
  "net":    { "rx_bytes": 557506264, "tx_bytes": 63097053 },
  "gpu":    { "busy_pct": 9, "mem_used": 496103424, "mem_total": 536870912, "temp_c": 48, "freq": 679, "power_w": 5.001 },
  "temp":   { "cpu_c": 50.125, "fan1": 2300, "fan2": 0 },
  "asus":   { "profile": "Quiet" }
}
```

Both configs are loaded as separate waybar instances via sway's `$waybar-start` variable (`~/.config/sway/config:495`).
Reload both at once with `$mod+Shift+w`.

## JSON Config Conventions

### Module Naming
- Built-in modules: lowercase with slashes (e.g., `sway/workspaces`, `pulseaudio/slider`)
- Custom modules: `custom/<name>` with kebab-case (e.g., `custom/checkupdates`)
- Groups: `group/<name>` with kebab-case (e.g., `group/bat-group`)
- Variants: use `#` suffix (e.g., `bluetooth#lite`, `network#lite`)

### Module Definition Patterns
- **exec-based**: must include `exec`, `interval`, `format`; use `return-type: "json"` when script outputs JSON
- **Signal refresh**: modules that change state use `signal` (integer) + `pkill -SIGRTMIN+<N> waybar` in scripts
- **Groups**: require `orientation` (`"horizontal"` or `"vertical"`) and `modules` array
- **Drawer groups**: add `"drawer": { "transition-duration": 500, "transition-left-to-right": true/false }`

### Include Order
Both `default-modules-v2.json` and `default-modules.json` are included in every bar. Later definitions override earlier ones.

## CSS Conventions

- **Selector naming**: `#<module-id>` matches the module name with `/` and `#` replaced by `-` (e.g., `custom/checkupdates` → `#custom-checkupdates`)
- **Bar-scoped selectors**: `.bar-horiz`, `.bar-vert`, `.bar-low` prefix for bar-specific styles
- **State classes**: `.warning`, `.critical`, `.activated`, `.paused`, `.recording`, `.notify`, `.on`, `.disconnected`
- **Theme**: dark translucent backgrounds with teal accent (`rgba(0, 128, 128, ...)`)
- **Font**: `"Monaspace Krypton Frozen", "JetBrainsMono Nerd Font", "MesloLGS Nerd Font", monospace`
- **Animations**: `blinkwarn`, `blinkred`, `blink`, `wait` — defined at bottom of file

## Bash Script Conventions

- All scripts use `#!/bin/bash` shebang
- Use `set -euo pipefail` for safety (present in newer scripts)
- JSON output: use `jq -n --compact-output` for structured output, not string interpolation
- Waybar refresh: `pkill -SIGRTMIN+<N> waybar || true` (use `|| true` to avoid exit on failure)
- Logging: scripts that need debug output use `/tmp/<name>.log`
- Background processes: use `nohup ... & disown` for long-running tasks

## Signal Convention

| Signal | Module(s) |
|---|---|
| `SIGRTMIN+3` | VPN toggle |
| `SIGRTMIN+8` | Recorder, checkupdates, keyboard backlight |
| `SIGRTMIN+9` | Dunst toggle |
| `SIGRTMIN+10` | ASUS profile switch |
| `SIGRTMIN+11` | External display toggle |

## Adding a New Module

1. Define the module in `default-modules.json` or `default-modules-v2.json`
2. Add it to a bar's `modules-left/center/right` array in `config` or `config-vertical`
3. Add CSS rules to `style.css` using `#<module-id>` selector
4. If using a script, place it in `scripts/` and make executable (`chmod +x`)
5. Update `STRUCT.md` to document the new module
6. Reload: `pkill -SIGUSR2 waybar`
