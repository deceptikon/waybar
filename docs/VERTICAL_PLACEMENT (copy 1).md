# Vertical Bar — Module Catalog, Placement Proposal, CSS Strategy

Generated: 2026-06-24 from live file audit + screenshot review.
**Status: AWAITING USER APPROVAL — no code changes until approved.**

---

## 0. Visual State Assessment (from screenshot)

![Current vertical bar state](/home/lexx/.gemini/antigravity/brain/faac1932-7fbf-4b35-975c-f2dcaf9a16cd/current_state.png)

**VL (monitor cards):** 6 cards rendering correctly — GPU (1000M1 68°C), CPU (colored load dots), RAM (AVG 39% 70°C), Network (signal bars + SSID "todaynet"), SSD (365Gb of 1.8T), ASUS (@Balanced curr_004), WiFi (BOOFC_56). Cards are readable but dense. ✅ Functional.

**VC (center):** Just "EN" — almost invisible, wasted space. This is where the 3 daily-use actions should go.

**VR (bottom-right cluster):** **This is the main problem.** ~7 tiny icons crammed into a small dark box. Icons are indistinguishable, unclickable, useless for daily controls. The `group/vr-*` wrappers compressed everything into blobs. Additionally, `custom/dunst` and `custom/recorder` render TWICE (once in group, once standalone).

**Bottom bar:** Thin workspace lines (BL), small powerbtn+uptime (BC), tray (BR). Functional and unobtrusive — **leaving as-is**.

**Top bar:** Working correctly. eDP-1 has powerbtn on right, HDMI-A-1 does not. No changes needed.

---

## 1. Complete Module Catalog

Every module defined across the four `modules-*.json` files.

### A. System Monitors — [modules-sysmon.json](file:///home/lexx/.config/waybar/modules-sysmon.json)

| Module ID | CSS Selector | Type | Displays | Click | Right-click |
|-----------|-------------|------|----------|-------|-------------|
| `group/qwen-gpu` | `#group-qwen-gpu` | **monitor** (group: icon + card) | GPU temp/util/VRAM | gpustat | nvtop |
| `group/qwen-cpu` | `#group-qwen-cpu` | **monitor** (group: icon + card) | CPU load/freq | htop | gnome-system-monitor |
| `group/qwen-ram` | `#group-qwen-ram` | **monitor** (group: icon + card) | RAM usage | gnome-system-monitor | free -h |
| `group/qwen-ssd` | `#group-qwen-ssd` | **monitor** (group: icon + card) | Disk usage | gnome-disks | lsblk |
| `group/qwen-asus` | `#group-qwen-asus` | **hybrid** (group: icon + card) | Fan RPM + profile name | `asusctl profile next` + SIG10 | — |
| `group/qwen-network` | `#group-qwen-network` | **hybrid** (group: icon + card) | SSID + signal + traffic | nm-connection-editor | nm-applet |

Sub-modules (internal to groups, not placed directly):
`custom/qwen-gpu-icon`, `custom/qwen-gpu`, `custom/qwen-cpu-icon`, `custom/qwen-cpu`, `custom/qwen-ram-icon`, `custom/qwen-ram`, `custom/qwen-ssd-icon`, `custom/qwen-ssd`, `custom/qwen-asus-icon`, `custom/qwen-asus`, `network#qwi`, `custom/qwen-wifi-info`

### B. Controls — [modules-controls.json](file:///home/lexx/.config/waybar/modules-controls.json)

| Module ID | CSS Selector | Type | Freq | Displays | Click | States |
|-----------|-------------|------|------|----------|-------|--------|
| `power-profiles-daemon` | `#power-profiles-daemon` | **action** | HIGH | icon + profile name | cycle ppd profile | `.power-saver` `.balanced` `.performance` |
| `custom/ext-display` | `#custom-ext-display` | **action** | HIGH | icon | toggle ext monitor | `.on` `.off` `.disconnected` |
| `idle_inhibitor` | `#idle_inhibitor` | **action** | HIGH | icon | toggle idle inhibit | `.activated` `.deactivated` |
| `custom/ollama` | `#custom-ollama` | **action** | MEDIUM | icon + model names | toggle ollama | `.on` `.off` |
| `custom/llama` | `#custom-llama` | **action** | MEDIUM | icon + status | toggle llama | `.on` `.off` |
| `custom/dunst` | `#custom-dunst` | **action** | LOW | icon | pause/resume dunst | `.paused` (normal has no class) |
| `custom/recorder` | `#custom-recorder` | **action** | LOW | icon | toggle wf-recorder | `.recording` `.stopped` |
| `custom/checkupdates` | `#custom-checkupdates` | **indicator** | LOW | icon + count | yay update | `.active` `.inactive` |
| `custom/fnlock` | `#custom-fnlock` | **action** | LOW | icon | toggle fn-lock | (via JSON class) |

#### Defined but UNUSED groups (dead config — to be deleted):

| Group ID | Members | Referenced in config? |
|----------|---------|----------------------|
| `group/vr-power` | `idle_inhibitor`, `custom/ext-display` | ❌ NOT in any `config-*` |
| `group/vr-sys` | `custom/fnlock`, `custom/checkupdates` | ❌ NOT in any `config-*` |
| `group/qwen-profile` | `power-profiles-daemon` | ❌ NOT in any `config-*` |

#### Groups causing double-rendering (to be removed from config):

| Group ID | Members | Problem |
|----------|---------|---------|
| `group/vr-ai` | `custom/ollama`, `custom/llama` | In `modules-right` — group renders, but members don't appear standalone since they're consumed by the group. However the group wrapper compresses them into a tiny horizontal pair. |
| `group/vr-capture` | `custom/recorder`, `custom/dunst` | Same compression problem AND `custom/dunst` + `custom/recorder` are ALSO listed standalone in `modules-right` — causing double rendering. |

### C. Peripherals — [modules-peripherals.json](file:///home/lexx/.config/waybar/modules-peripherals.json)

| Module ID | CSS Selector | Type | Displays | Click |
|-----------|-------------|------|----------|-------|
| `custom/powerbtn` | `#custom-powerbtn` | **action** | ⏻ icon | power menu (XML) |
| `custom/keylight` | `#custom-keylight` | **action** | kbd backlight icon | toggle kbd light |
| `group/audio` | `#group-audio` | **slider** (group: icon + slider) | volume icon + slider | mute toggle |
| `group/bright` | `#group-bright` | **slider** (group: icon + slider) | brightness icon + slider | — |
| `group/bright-external` | `#group-bright-external` | **slider** (group: icon + ddc) | brightness icon + ddc | ddc set 50/100/0 |
| `battery` | `#battery` | **indicator** | charge level | — |
| `bluetooth#lite` | `#bluetooth-lite` | **indicator/action** | BT icon | toggle BT / blueman |
| `custom/ddc` | `#custom-ddc` | **slider** (sub-module of bright-external) | DDC brightness text | set 50 |

### D. Top-Shared — [modules-top-shared.json](file:///home/lexx/.config/waybar/modules-top-shared.json)

| Module ID | CSS Selector | Type | Used In |
|-----------|-------------|------|---------|
| `clock#date` | `#clock-date` | **indicator** | top center |
| `sway/workspaces` | `#workspaces` | **nav** | top bar |
| `sway/window` | `#window` | **indicator** | top center |
| `sway/scratchpad` | `#scratchpad` | **indicator** | top center |
| `privacy` | `#privacy` | **indicator** | top center |
| `group/titlebox-row` | `#group-titlebox-row` | **group** | top center |
| `sway/mode` | `#mode` | **indicator** | top center |

### E. Inline modules (defined in bar configs, not in module files)

| Module ID | Defined in | Notes |
|-----------|-----------|-------|
| `custom/lang` | `config-vertical` (inline) | indicator — shows EN/RU |
| `custom/uptime` | `config-bottom` (inline) | indicator — shows uptime |
| `clock` | `config-vertical` (inline) | ⚠️ **DEAD** — defined but not in any modules list |
| `sway/workspaces#bottom` | `config-bottom` (inline) | nav |
| `custom/powerbtn` | `config-bottom` (inline, duplicates peripherals def) | action |
| `custom/ollama` | `config-bottom` (inline, different exec) | richer version showing model names |

---

## 2. Dead CSS Selectors Audit

CSS selectors in [vertical.css](file:///home/lexx/.config/waybar/style/vertical.css) targeting non-existent modules:

| CSS Selector | Lines | Status |
|-------------|-------|--------|
| `#group-vr-power` | 180-190 | ⛔ DEAD — `group/vr-power` not in any config |
| `#group-vr-sys` | 180-190 | ⛔ DEAD |
| `#group-vr-power > widget` | 192-198 | ⛔ DEAD |
| `#group-vr-sys > widget` | 192-198 | ⛔ DEAD |
| `#group-vr-power > widget > label` | 200-212 | ⛔ DEAD |
| `#group-vr-sys > widget > label` | 200-212 | ⛔ DEAD |
| `#group-vr-power #idle_inhibitor` | 221 | ⛔ DEAD |
| `#group-vr-sys #custom-fnlock` | 224 | ⛔ DEAD |
| `#group-vr-ai` | 180-227 | 🗑️ TO BE REMOVED (group being dissolved) |
| `#group-vr-capture` | 180-227 | 🗑️ TO BE REMOVED (group being dissolved) |

All `#group-vr-*` CSS will be replaced with flat per-module selectors.

---

## 3. Placement Proposal

### Design Principles
1. **No composite groups for action buttons** — the `group/vr-*` experiment failed visually (screenshot confirms: tiny compressed blobs)
2. **Monitor groups (icon+card) stay as groups** — `group/qwen-*` pattern works, no change
3. **Hybrids stay in VL** — ASUS and Network are visually monitor-like, moving them would lose consistency
4. **HIGH-freq actions get prominence in VC** — ppd, ext-display, idle_inhibitor deserve large clickable buttons
5. **Restore usable sizing** — min-width 36px, min-height 28px, font-size 16px for daily actions
6. **Delete all dead group definitions** from modules-controls.json

### Proposed Layout

```
┌─────────────────┐
│   VL (LEFT)     │  monitors + hybrids (6 icon+card groups)
│  ┌─────────────┐│
│  │ 🎮 GPU info ││  group/qwen-gpu
│  ├─────────────┤│
│  │ ⚙ CPU info  ││  group/qwen-cpu
│  ├─────────────┤│
│  │ 🧠 RAM info ││  group/qwen-ram
│  ├─────────────┤│
│  │ 💾 SSD info ││  group/qwen-ssd
│  ├─────────────┤│
│  │ ⚙ ASUS info ││  group/qwen-asus  (hybrid: fan RPM + click cycles profile)
│  ├─────────────┤│
│  │ 📶 WiFi info││  group/qwen-network  (hybrid: SSID + click opens nm-editor)
│  └─────────────┘│
│                 │
│   VC (CENTER)   │  lang indicator + 3 HIGH-freq daily actions
│  ┌─────────────┐│
│  │     EN      ││  custom/lang  (small indicator)
│  ├─────────────┤│
│  │  ⚡ ppd     ││  power-profiles-daemon  (icon + profile name, large button)
│  ├─────────────┤│
│  │  🖥 ext     ││  custom/ext-display  (large button)
│  ├─────────────┤│
│  │  ☕ idle    ││  idle_inhibitor  (large button)
│  └─────────────┘│
│                 │
│   VR (RIGHT)    │  MEDIUM/LOW-freq actions (flat, no groups)
│  ┌─────────────┐│
│  │  󱚣 ollama  ││  custom/ollama  (shows running model names)
│  │  🦙 llama   ││  custom/llama
│  │─────────────││
│  │  📦 updates ││  custom/checkupdates
│  │─────────────││
│  │  🔔 dunst   ││  custom/dunst
│  │  ⏺ recorder││  custom/recorder
│  │  ⌨ fnlock  ││  custom/fnlock
│  └─────────────┘│
└─────────────────┘
```

### Config Changes

#### [config-vertical](file:///home/lexx/.config/waybar/config-vertical)

```jsonc
{
  "width": 138,   // ← revert from 200; GTK auto-expands to ~173
  "modules-left": [
    "group/qwen-gpu",
    "group/qwen-cpu",
    "group/qwen-ram",
    "group/qwen-ssd",
    "group/qwen-asus",
    "group/qwen-network"
  ],
  "modules-center": [
    "custom/lang",
    "power-profiles-daemon",
    "custom/ext-display",
    "idle_inhibitor"
  ],
  "modules-right": [
    "custom/ollama",
    "custom/llama",
    "custom/checkupdates",
    "custom/dunst",
    "custom/recorder",
    "custom/fnlock"
  ]
}
```

Changes from current:
- `width`: 200 → **138**
- **VC gains**: ppd, ext-display, idle_inhibitor (the 3 daily-use actions)
- **VR becomes flat**: 6 standalone modules, no `group/vr-*` wrappers
- **Removes**: `group/vr-ai`, `group/vr-capture` references
- **Removes**: duplicate `custom/dunst`, `custom/recorder` standalone entries
- **Removes**: unused inline `clock` definition

#### [modules-controls.json](file:///home/lexx/.config/waybar/modules-controls.json) — cleanup

**Delete 5 dead group definitions:**
- `group/vr-power` (lines 74-80)
- `group/vr-ai` (lines 81-87)
- `group/vr-capture` (lines 88-94)
- `group/vr-sys` (lines 95-101)
- `group/qwen-profile` (lines 102-107)

**Enhance `custom/ollama` exec** — replace simple UP/DOWN with richer version showing running model names:
```bash
if curl -s http://localhost:11111/api/tags > /dev/null 2>&1; then
  models=$(OLLAMA_HOST=localhost:11111 ollama ps 2>/dev/null | awk 'NR>1 {print $1}' | paste -sd ' ' -)
  if [ -n "$models" ]; then
    jq -cn --arg m "$models" '{text:("󱚣 " + $m),tooltip:("Running: " + $m),class:"on"}'
  else
    jq -cn '{text:"󱚣 UP",tooltip:"Ollama is running (no models loaded)",class:"on"}'
  fi
else
  jq -cn '{text:"󱚣 DOWN",tooltip:"Ollama is not running",class:"off"}'
fi
```
(Uses `jq -cn` per rule #9.)

#### Bottom bar — **no changes** (functional as-is per screenshot)

#### Top bar — **no changes** (correct per user intent)

---

## 4. Dimensions

### Bar width
| Property | Value | Notes |
|----------|-------|-------|
| `width` | **138** | Reverts to pre-break value. GTK auto-expands to ~173px with content. |

### VL — Monitor group cards (no change from current)
| Property | Value |
|----------|-------|
| Card `min-width` | 104px |
| Card `padding` | 5px 4px |
| Card `font-size` | 14px (inherited from base) |
| Group `margin` | 8px 4px (vertical breathing room) |
| Group `border-left` | 3px solid (accent color per group) |
| Icon `font-size` | 16px |

### VC — Daily action buttons (ppd, ext-display, idle_inhibitor)
| Property | Value | Notes |
|----------|-------|-------|
| `min-width` | 36px | |
| `min-height` | 28px | Comfortable click target |
| `font-size` | 16px | Clearly readable |
| `padding` | 6px 8px | |
| `margin` | 4px 4px | |
| `border-radius` | 8px | |
| `custom/lang` | 12px font, 6px 12px padding | Smaller — it's an indicator |

### VR — Secondary action buttons
| Property | Value | Notes |
|----------|-------|-------|
| `min-width` | 36px | Same clickable area |
| `min-height` | 24px | Slightly shorter — secondary |
| `font-size` | 15px | |
| `padding` | 4px 8px | |
| `margin` | 2px 4px | |
| `border-radius` | 6px | |

### ppd special case
Format `{icon} {profile}` shows text like "⚡ balanced". In the vertical bar at ~173px actual width this should fit. Keeping text format — **will adjust to icon-only if it wraps badly during live testing.**

---

## 5. CSS Strategy

### File structure (no change)
- [base.css](file:///home/lexx/.config/waybar/style/base.css) — shared (imported by vertical.css)
- [vertical.css](file:///home/lexx/.config/waybar/style/vertical.css) — all vertical bar overrides

### Selectors to DELETE (lines 172-227 of vertical.css)

The entire VR groups section:
```css
/* DELETE all of these: */
#group-vr-power, #group-vr-ai, #group-vr-capture, #group-vr-sys { ... }
#group-vr-* > widget { ... }
#group-vr-* > widget > label { ... }
#group-vr-ai > widget > label { ... }
#group-vr-power #idle_inhibitor, ... { ... }
```

### Selectors to ADD — VC action buttons

```css
/* VC — daily-use action buttons */
.bar-vert .modules-center #power-profiles-daemon,
.bar-vert .modules-center #custom-ext-display,
.bar-vert .modules-center #idle_inhibitor {
  font-size: 16px;
  font-weight: 600;
  min-width: 36px;
  min-height: 28px;
  padding: 6px 8px;
  margin: 4px 4px;
  border-radius: 8px;
  color: #a6adc8;
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(255, 255, 255, 0.08);
  transition: color 0.2s ease, background 0.2s ease;
}
```

### Selectors to ADD — VR compact buttons

```css
/* VR — secondary actions */
.bar-vert .modules-right #custom-ollama,
.bar-vert .modules-right #custom-llama,
.bar-vert .modules-right #custom-checkupdates,
.bar-vert .modules-right #custom-dunst,
.bar-vert .modules-right #custom-recorder,
.bar-vert .modules-right #custom-fnlock {
  font-size: 15px;
  min-width: 36px;
  min-height: 24px;
  padding: 4px 8px;
  margin: 2px 4px;
  border-radius: 6px;
  color: #a6adc8;
  background: rgba(20, 20, 28, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.06);
  transition: color 0.2s ease;
}
```

### Selectors to ADD — ppd profile states

```css
#power-profiles-daemon.balanced    { color: #94e2d5; }
#power-profiles-daemon.performance { color: #fab387; }
#power-profiles-daemon.power-saver { color: #89b4fa; }
```

### State selectors to KEEP (already correct, no group dependency)

```css
#idle_inhibitor.activated         { color: #94e2d5; }
#custom-ext-display.on            { color: #94e2d5; }
#custom-ollama.on                 { color: #94e2d5; }
#custom-llama.on                  { color: #94e2d5; }
#custom-dunst.paused              { color: #94e2d5; }
#custom-recorder.recording        { color: #f38ba8; }
#custom-checkupdates.active       { color: #a6e3a1; }
#custom-ollama.off                { color: #585b70; }
#custom-llama.off                 { color: #585b70; }
#custom-ext-display.off           { color: #585b70; }
#custom-ext-display.disconnected  { opacity: 0.5; }
```

### VC zone container update

Currently transparent (only held lang). With 3 action buttons, it gets a visible container:

```css
.bar-vert .modules-center {
  background: rgba(30, 30, 46, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.06);
  margin: 4px 2px;
  padding: 8px 4px;
  border-radius: 10px;
}
```

---

## 6. Implementation Checklist (after approval)

- [ ] Revert `config-vertical` width to 138
- [ ] Update `modules-center`: add ppd, ext-display, idle_inhibitor after lang
- [ ] Update `modules-right`: flat list of 6 standalone modules (no groups)
- [ ] Remove unused inline `clock` definition from config-vertical
- [ ] Delete 5 dead group definitions from `modules-controls.json`
- [ ] Enhance `custom/ollama` exec in modules-controls.json to show model names (using `jq -cn`)
- [ ] Remove all `#group-vr-*` selectors from `style/vertical.css` (lines 172-227)
- [ ] Add VC action button styles (ppd, ext-display, idle_inhibitor)
- [ ] Add VR compact button styles (ollama, llama, checkupdates, dunst, recorder, fnlock)
- [ ] Add ppd profile state classes
- [ ] Update VC zone container from transparent → visible background
- [ ] Test with `scripts/waybar-start.sh reload`
