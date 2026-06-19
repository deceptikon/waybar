# STATUS — Waybar Configuration

*Last updated: 2026-06-16*

---

## Current State

### Top bar (`bar-horiz`) — production
Modules-left: `powerbtn → temp-fan → group/qwen-cpu → group/qwen-ram → group/qwen-ssd → group/qwen-network`

- **group/qwen-cpu**: Chip icon + 2-line tile (16 colored per-core blocks on row 1, `avg:XX% YY°C` on row 2). Clicks launch htop/system-monitor.
- **group/qwen-ram**: RAM stick icon + inline capacity bar (12 /· segments with usedG at boundary, totalG suffix, swap line below).
- **group/qwen-ssd**: Disk icon + usage bar + live I/O.
- **group/qwen-network**: WiFi icon + SSID/signal % info.
- **group/qwen-network** uses `wifi-big-icon.sh` + `qwen-wifi-info.sh`.

All groups use nested-box pattern: outer dark wrapper with accent border, transparent icon tile, inner info tile with its own border.

### Right bar (`bar-vert`) — unchanged
Clock, workspaces, battery, profile switcher, lang, privacy, idle inhibitor, power-profiles, dunst, recorder, checkupdates, fnlock, backlight, ext-display.

### Dev bar (`bar-horiz-dev`)
Positioned top. Output set to `NONEXISTENT_OUTPUT` so it never renders. Modules match production for isolated iteration.

### Bottom bar (`bar-low`)
Uptime (left), sway mode (center), ollama (right). Transparent indicator line.

---

## Scripts (`scripts/`)

| Script | Purpose |
|---|---|
| `qwen-cpu-icon.sh` | nf-fa microchip icon (U+F1DB), plain polling |
| `qwen-ram-icon.sh` | RAM stick icon, plain polling |
| `qwen-ssd-icon.sh` | SSD/HDD icon (detects rotational), plain polling |
| `wifi-big-icon.sh` | WiFi signal icon, plain polling |
| `qwen-cpu-info.sh` | 16 per-core colored blocks + avg% + temp |
| `qwen-ram-info.sh` | inline ▓/· capacity bar + swap |
| `qwen-ssd-info.sh` | SSD usage bar + live I/O |
| `qwen-wifi-info.sh` | SSID, signal %, upload/download |
| `qwen-network.sh` | Network toggle (used by other modules) |

---

## Config files
- `config` — bar definitions
- `qwen-modules.json` — qwen module definitions (included by bar-horiz)
- `default-modules.json` — built-in module definitions
- `default-modules-v2.json` — secondary built-in modules
- `style.css` — GTK styling

---

## Recent commits
```
cfae4ce 135:08 Migrate dev bar qwen modules to production top bar
f7edeb0     CPU module: per-core 16-block usage grid, big 2-line layout
990dca4     RAM: inline capacity bar with symbols after label
```

---

## Known issues / next items
- Bar actual height exceeds configured 17px (memory: actual_bar_height_exceeds_config.md)
- CSS has duplicate rules for `#group-qwen-ram` and `#custom-qwen-ram-icon`