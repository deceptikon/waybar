# Waybar Module Structure Analysis

Generated: 2026-06-24
Status: **LIVE REFLECTION OF CURRENT STATE**

---

## 1. Available Modules (by source file)

### modules-sysmon.json — Monitor/telemetry groups
| Module | Type | Action | Frequency |
|--------|------|--------|-----------|
| group/qwen-gpu | monitor | click: gpustat, right-click: nvtop | continuous |
| group/qwen-cpu | monitor | click: htop, right-click: gnome-system-monitor | continuous |
| group/qwen-ram | monitor | click: gnome-system-monitor, right-click: free | continuous |
| group/qwen-ssd | monitor | click: gnome-disks, right-click: lsblk | continuous |
| group/qwen-asus | **hybrid** (shows fan RPM + profile name) | click: cycle profile, signal: 10 | poll 2s |
| group/qwen-network | monitor | click: nm-connection-editor, right-click: nm-applet | poll 2s |

### modules-controls.json — Action/toggle controls
| Module | Type | Action | Frequency |
|--------|------|--------|-----------|
| power-profiles-daemon | **action** | click: cycle profile via ppd | **HIGH** (daily) |
| custom/ext-display | **action** | click: toggle external monitor | **HIGH** (daily) |
| idle_inhibitor | **action** | click: toggle idle inhibit | **HIGH** (daily) |
| custom/ollama | **action** (LLM status) | click: toggle ollama | medium |
| custom/llama | **action** (LLM status) | click: toggle llama | medium |
| custom/dunst | action (notifications) | click: pause/resume dunst | low |
| custom/recorder | action (screen capture) | click: togg wf-recorder | low |
| custom/checkupdates | action (pkg updates) | click: run yay update | indicator |
| custom/fnlock | action (keyboard) | click: toggle fn-lock | low |

### modules-peripherals.json — Hardware/device controls
| Module | Type | Action |
|--------|------|--------|
| custom/powerbtn | **action** | click: power menu |
| custom/keylight | action | click: toggle keyboard backlight |
| group/audio | interactive (icon + slider) | click: mute, scroll: volume |
| group/bright | interactive (icon + slider) | click: on-click, scroll: brightness |
| group/bright-external | interactive (icon + slider) | scroll: ddc brightness |
| battery | monitor | auto (shows charge) |
| bluetooth#lite | monitor/action | click: toggle BT, right-click: blueman |

### modules-top-shared.json — Top-bar specific
| Module | Zone |
|--------|------|
| clock#date | center |
| sway/mode | center |
| group/titlebox-row | center |
| sway/workspaces | bottom |

---

## 2. Current Bar Layouts

### Vertical Bar (right side, 173px actual)
```
┌─────────────┐
│  VL (LEFT)  │ ← monitor groups only
│  GPU        │
│  CPU        │
│  RAM        │
│  SSD        │
│  ASUS ⚠    │ ← hybrid (monitor + action)
│  NETWORK ⚠ │ ← hybrid (monitor + action)
│             │
│  VC (CENTER)│ ← just "EN" (lang)
│  [EN]       │
│             │
│  VR (RIGHT) │ ← 4 grouped pairs
│  [∅|⊞]     │ ← vr-power (inhibitor + ext-display)
│  [UP|UP]   │ ← vr-ai (ollama + llama)
│  [|⊡]     │ ← vr-capture (recorder + dunst)
│  [⊠|⊕]     │ ← vr-sys (fnlock + checkupdates)
└─────────────┘
```

**Problem:** `power-profiles-daemon` is MISSING. User says it and network are action controls, not monitors. ASUS card shows profile text but isn't clickable for ppd.

### Top Bar eDP-1 (laptop screen)
```
┌─────────────────────────────────────────────┐
│ L: [BT] [🔊━━] │ C: [DATE + MODE + TITLE] │ R: [☀━━] [⌨] [🔋] [] │
└─────────────────────────────────────────────┘
```

### Top Bar HDMI-A-1 (external monitor)
```
┌─────────────────────────────────────────────┐
│ L: [🔊━━] [BT]   │ C: [same center]     │ R: [☀━━] [⌨] []         │
└─────────────────────────────────────────────┘
```

**Difference:** HDMI-A-1 has `group/bright-external` (with ddc slider) instead of `group/bright`. No powerbtn on HDMI (user said "never needed two powers").

### Bottom Bar
```
┌─────────────────────────────────────────────┐
│ L: [workspaces] │ C: [⏻ 4h 23m] │ R: [UP] [tray] │
└─────────────────────────────────────────────┘
```

---

## 3. Identified Patterns

### Pattern A: Monitor groups (icon + info card)
- GPU, CPU, RAM, SSD — pure monitors, click opens viewer app
- Visual: colored left border, icon+card layout

### Pattern B: Action controls (toggle/state buttons)
- ppd, ext-display, idle_inhibitor, fnlock, dunst, recorder
- Visual: icon-only or icon+label, toggle state on click
- **User wants these grouped functionally**

### Pattern C: Hybrid controls (monitor + action)
- ASUS: shows fan speed (monitor) + profile name (action — cycles profile)
- Network: shows SSID/traffic (monitor) + opens nm-connection-editor (action)
- **These are the problematic ones — they don't fit cleanly**

### Pattern D: Interactive sliders
- Audio (icon + slider)
- Brightness (icon + slider)
- **Only work in top bar (horizontal layout)**

### Pattern E: Standalone indicators
- Battery (auto-updating)
- Bluetooth (icon + state)
- Tray (system icons)
- Lang (EN/RU indicator)

---

## 4. User Constraints (from feedback)

1. **WiFi and profile are ACTION controls, not monitors** — they belong with buttons, not GPU/CPU/RAM/SSD
2. **Daily-used controls need prominence** — ppd, ext-display, idle_inhibitor are clicked frequently
3. **Buttons must be usable** — not puny icons in a dark corner
4. **Groups should be functional** — not arbitrary, but based on what they do
5. **Old grouping was fine but something broke** — user acknowledges old approach worked until recently

---

## 5. Missing Context

**Question to resolve:** Why did the old approach break?
- Was it a CSS change that made buttons unclickable?
- Did a module get removed/renamed?
- Did the VR zone get too crowded?

Need to check git history to see what changed in the last working state.

---

## 6. Proposed Next Steps (after user confirms)

1. Identify what "old working state" looked like (git log)
2. Revert broken changes OR fix forward with clear grouping
3. Ensure ppd and network are treated as actions
4. Ensure daily-used controls are prominent and usable
5. Ensure ASUS/network hybrid cards either:
   - (a) Split into monitor + action parts
   - (b) Stay hybrid but marked clearly as actions
