# Waybar Modules Structure

## Bars

Only `bar-vert` (vertical, right edge) is active, defined in `config-vertical`.

### bar-vert layout

| Position | Modules | Defined In |
|---|---|---|
| left | `group/qwen-temp`, `group/qwen-asus`, `group/qwen-cpu`, `group/qwen-ram`, `group/qwen-ssd`, `group/qwen-network` | `modules-monitor-group.json` |
| center | `clock`, `group/tray`, `custom/lang`, `privacy` | inline in `config-vertical` |
| right | `idle_inhibitor`, `power-profiles-daemon`, `custom/dunst`, `custom/recorder`, `custom/checkupdates`, `custom/fnlock`, `custom/backlight`, `custom/ext-display` | `modules-ux-group.json` |

## Module Groups (modules-monitor-group.json)

Each monitor group follows an **icon + info** pattern using a horizontal group:

```
group/qwen-<name>  (horizontal group)
  ├── custom/qwen-<name>-icon  (static glyph, no exec, tooltip: false)
  └── custom/qwen-<name>-info  (script, return-type: json, interval)
```

| Group | Icon Glyph | Info Script | Interval | Accent Color |
|---|---|---|---|---|
| `qwen-temp` |  | `qwen-temp-info.sh` | 3s | pink |
| `qwen-asus` |  | `qwen-asus-info.sh` | 2s | teal |
| `qwen-cpu` |  | `qwen-cpu-info.sh` | 5s | green |
| `qwen-ram` |  | `qwen-ram-info.sh` | 5s | blue |
| `qwen-ssd` |  | `qwen-ssd-info.sh` | 5s | green |
| `qwen-network` | `network#qwi` (built-in) | `qwen-wifi-info.sh` | 10s | teal |

The network group is special: it uses Waybar's built-in `network#qwi` as the icon (with signal-based icons and tooltip) plus `custom/qwen-wifi-info` for SSID + speed details.

## UX Modules (modules-ux-group.json)

Right-side toggle/indicator modules — all single-icon with click actions.

## Scripts Directory

| Script | Used by | Description |
|---|---|---|
| `qwen-cpu-info.sh` | `custom/qwen-cpu-info` | 16-core sparkline bars + avg% |
| `qwen-ram-info.sh` | `custom/qwen-ram-info` | Used/total RAM + swap + dots bar |
| `qwen-ssd-info.sh` | `custom/qwen-ssd-info` | Usage bar + live I/O speeds |
| `qwen-temp-info.sh` | `custom/qwen-temp-info` | CPU temp + fan RPM |
| `qwen-wifi-info.sh` | `custom/qwen-wifi-info` | SSID + download/upload speeds |
| `qwen-asus-info.sh` | `custom/qwen-asus-info` | ASUS profile (Quiet/Balanced/Performance) |
| `qwen-system-info.sh` | — | Unused (superseded) |
| `qwen-system-icon.sh` | — | Unused (superseded) |
| `qwen-ram-icon.sh` | — | Unused (superseded) |
| `archived/qwen-network.sh` | — | Archived predecessor |
