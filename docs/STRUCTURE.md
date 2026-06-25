# Waybar Module Structure

**Status:** Live reflection of current state.
**Last updated:** 2026-06-26

## Bar Architecture

```
4 waybar processes, started by scripts/waybar-start.sh
  ├─ config-top       → style/top.css       (2 outputs: eDP-1 + HDMI-A-1)
  ├─ config-vertical  → style/vertical.css  (right edge, full sysmon)
  ├─ config-vertical-lite → style/vertical-lite.css (right edge, compact, start_hidden)
  └─ config-bottom    → style/bottom.css    (bottom edge)
```

## Module Patterns

### Pattern A: Monitor groups (icon + info card)
- GPU, CPU, RAM, SSD — pure monitors, click opens viewer
- `group/qwen-*` with two sub-modules: `custom/qwen-*-icon` + `custom/qwen-*`
- Visual: accent-colored top border, icon+data layout
- Data from `tail -F feeds/<metric>.json` (written by sysmon pipeline)

### Pattern B: Hybrid controls (monitor + action)
- ASUS: shows fan RPM + profile name, click cycles asusctl profile
- Network: shows SSID/traffic, click opens nm-connection-editor
- Rendered as monitor groups but are action controls

### Pattern C: Action/toggle buttons
- ppd, ext-display, idle_inhibitor, fnlock, dunst, recorder, ollama, llama, checkupdates
- Icon-only or icon+label, toggle state on click
- Frequency-ordered: HIGH (top of VC) → MED → LOW (bottom of VR)

### Pattern D: Interactive sliders
- Audio (icon + pulseaudio slider)
- Brightness (icon + backlight slider)
- Only in top bar (horizontal layout)

### Pattern E: Standalone indicators
- Battery, Bluetooth, tray, lang, uptime, clock

## Vertical Bar Zones

```
┌──────────────────────────────┐
│ VL (LEFT) — 6 monitor groups │
│  group/qwen-gpu              │
│  group/qwen-cpu              │
│  group/qwen-ram              │
│  group/qwen-ssd              │
│  group/qwen-asus             │
│  group/qwen-network          │
├──────────────────────────────┤
│ VC (CENTER) — lang + HIGH    │
│  custom/lang                 │
│  power-profiles-daemon       │
│  custom/ext-display          │
│  idle_inhibitor              │
├──────────────────────────────┤
│ VR (RIGHT) — MED/LOW actions │
│  custom/ollama               │
│  custom/llama                │
│  custom/checkupdates         │
│  custom/dunst                │
│  custom/recorder             │
│  custom/fnlock               │
└──────────────────────────────┘
```

## CSS File Roles

| File | Applies To | Key Rules |
|---|---|---|
| `base.css` | All bars | Font, reset, battery, sliders, animations |
| `top.css` | Top bar | Catppuccin colors, workspaces, date, groups |
| `vertical.css` | Vertical bar | Full sysmon groups, VC/VR action buttons |
| `vertical-lite.css` | Vertical-lite bar | Compact module styles, tighter spacing |
| `bottom.css` | Bottom bar | Workspace buttons, uptime, tray, ollama |

## Dead/Unused Files

- `style/vertical-full.css` — Leftover from old toggle mechanism. Not referenced anywhere.
