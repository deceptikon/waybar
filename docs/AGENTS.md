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

## Data Flow — sysmon Pipeline

```
scripts/sysmon/poller.sh (background daemon, wakes every 2s)
  │
  ├─ scripts/sysmon/collect.sh     # reads /proc/* + /sys/* + sensors-j — labeled lines
  │        │ pipe
  │        ▼
  └─ scripts/sysmon/mapper.sh      # parses labeled sections → unified JSON → /tmp/sysmon.json

/tmp/sysmon.json ← written atomically every 2s by poller (write tmp + mv)

  6 waybar modules (each interval: 2, return-type: json):
    custom/qwen-<metric> → scripts/sysmon/frame.sh <metric>
      │ cat /tmp/sysmon.json
      │ jq .<metric>
      │ draw_module "" "$row1" "$row2" $accent $class
      │ → Waybar JSON {text: "<span fgcolor='accent'>row1\nrow2</span>", class: "good"}
      │
      └─ in group/qwen-<metric> with icon sibling:
           custom/qwen-*-icon → scripts/sysmon/icon.sh <metric>
```

| Source | Read by | → JSON key |
|---|---|---|
| `/proc/stat` (two snaps, 0.3s delta) | `sysmon-collect.sh` | `cpu.avg`, `cpu.per_core[]` |
| `/proc/meminfo` | `sysmon-collect.sh` | `ram.*` |
| `/sys/class/drm/card*/device/gpu_busy_percent` | `sysmon-collect.sh` | `gpu.busy_pct` |
| `/sys/class/drm/card*/device/mem_info_vram_*` | `sysmon-collect.sh` | `gpu.mem_used`, `gpu.mem_total` |
| `/sys/class/drm/card*/.../pp_dpm_sclk` | `sysmon-collect.sh` | `gpu.freq` |
| `/sys/class/powercap/intel-rapl:0/power_now` | `sysmon-collect.sh` | `gpu.power_w` |
| `sensors -j` | `sysmon-collect.sh` | `gpu.temp_c`, `temp.*` |
| `/sys/block/nvme0n1/stat` | `sysmon-collect.sh` | `disk.*` |
| `df /` | `sysmon-frame.sh ssd` (live, not cached) | N/A |
| `/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy` | `sysmon-collect.sh` | `asus.profile` |

## draw-module.sh Library

`scripts/lib/draw-module.sh` — two functions:

- **`draw_module <icon> <row1> <row2> <color_hex> [class]`** — Outputs Waybar JSON.
  When `icon` is empty: plain `<span fgcolor='color'>row1\nrow2</span>` (no box art).
  When `icon` is set: draws a unicode box table (used by `pango-boxes` branch).

- **`draw_box <line1> [<line2> ...]`** — Wraps lines in a unicode box, returns Pango text only (no JSON). Unused in current branch.

## sysmon-icon.sh — Icon Output

One-liner per metric, outputs Waybar JSON with just the icon glyph:

```bash
~/.config/waybar/scripts/sysmon-icon.sh gpu   # → {"text":" 󰢮 ","class":"good"}
```

Each icon module has `interval: "once"` — Waybar runs it once and never re-polls (icon never changes).
CSS provides the accent color (`#custom-qwen-gpu-icon { color: #fab387; }`).

## sysmon-frame.sh — Metric Formatter

Reads `/tmp/sysmon.json` and outputs Waybar JSON for one metric.

```bash
~/.config/waybar/scripts/sysmon-frame.sh gpu   # → {text, class}
```

Each group contains two modules side by side:
```
custom/qwen-<metric>-icon  ← sysmon-icon.sh  (big icon, fixed accent color)
custom/qwen-<metric>       ← sysmon-frame.sh (stats text, state-dependent card)
```

| Metric | Icon | Accent | CSS icon | CSS info |
|---|---|---|---|---|
| `gpu` | 󰢮 | `#fab387` peach | `#custom-qwen-gpu-icon` | `#custom-qwen-gpu` |
| `cpu` | 󰍛 | `#a6e3a1` green | `#custom-qwen-cpu-icon` | `#custom-qwen-cpu` |
| `ram` |  | `#89b4fa` blue | `#custom-qwen-ram-icon` | `#custom-qwen-ram` |
| `ssd` | 󰋊 | `#a6e3a1` green | `#custom-qwen-ssd-icon` | `#custom-qwen-ssd` |
| `temp` | 󰔐 | `#f38ba8` red | `#custom-qwen-temp-icon` | `#custom-qwen-temp` |
| `asus` |  | `#94e2d5` teal | `#custom-qwen-asus-icon` | `#custom-qwen-asus` |

**Key rule:** modules never read hardware — only the cache file.

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
