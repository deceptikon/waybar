# Vertical Bar Placement Proposal

**Date:** 2026-06-24
**Status:** DRAFT — awaiting user approval before any code changes

---

## 1. Complete Module Catalog

### A. Monitor Modules (continuous read-only, click opens viewer)

| Module | Source | Shows | Click | Right-Click | Freq |
|--------|--------|-------|-------|-------------|------|
| `group/qwen-gpu` | sysmon | icon + freq/usage/temp JSON | gpustat | nvtop | continuous |
| `group/qwen-cpu` | sysmon | icon + avg/cores/temp JSON | htop | gnome-system-monitor | continuous |
| `group/qwen-ram` | sysmon | icon + used/total/swapped JSON | gnome-system-monitor | free -h | continuous |
| `group/qwen-ssd` | sysmon | icon + used/total IO JSON | gnome-disks | lsblk | continuous |
| `group/qwen-asus` | sysmon | icon + fan RPM + profile name JSON | asusctl profile next + SIG10 | — | poll 2s |
| `group/qwen-network` | sysmon | icon + SSID/up-down JSON | nm-connection-editor | nm-applet | poll 2s |

These 6 groups use the **icon + info-card** pattern. `group/qwen-*` groups stay as-is — they render correctly and the user has not complained about them.

### B. Action/Toggle Modules

| Module | Source | Shows | Click | Right-Click | Freq |
|--------|--------|-------|-------|-------------|------|
| `power-profiles-daemon` | controls | `{icon} {profile}` — cycles between power-saver / balanced / performance | cycle ppd profile via DBus | — | **HIGH** |
| `idle_inhibitor` | controls | icon pair: activated (screen-awake) / deactivated (sleep) | toggle idle inhibit | — | **HIGH** |
| `custom/ext-display` | controls | JSON icon, class on/off/disconnected | ext-display.sh toggle | — | **HIGH** |
| `custom/checkupdates` | controls | JSON icon + pkg count, class active/inactive | wezterm -e yay -Syyu | — | medium |
| `custom/ollama` | controls | JSON " UP"/" DOWN", class on/off | — (indicator only; no on-click) | — | medium |
| `custom/llama` | controls | JSON " UP"/" DOWN" | llama-server.sh toggle | — | medium |
| `custom/dunst` | controls | JSON bell icon, class paused | dunst.sh toggle pause | — | LOW |
| `custom/recorder` | controls | JSON rec icon, class recording/stopped | capturer.sh toggle | kill wf-recorder | LOW |
| `custom/fnlock` | controls | JSON fn-key icon | toggle_fn_lock.sh | — | LOW |

### C. Indicator Modules

| Module | Source | Shows | Click | Freq |
|--------|--------|-------|-------|------|
| `custom/lang` | inline in config-vertical | EN / RU | — | continuous |
| `battery` | peripherals | icon + capacity % | — | poll 20s |
| `bluetooth#lite` | peripherals | state-aware BT icon | bt-toggle.sh | blueman-manager | event |

### D. Interactive Slider Modules (horizontal layout only — top bar)

| Module | Source | Shows | Action |
|--------|--------|-------|--------|
| `group/audio` | peripherals | icon + scroll slider | click mute, scroll volume |
| `group/bright` | peripherals | icon + scroll slider | scroll brightness |
| `group/bright-external` | peripherals | icon + DDC slider | scroll DDC, click set 50 |
| `custom/keylight` | peripherals | JSON kbd backlight icon | keylight toggler.sh |

### E. Composite Groups Defined in modules-controls.json

| Group Name | Members | Status |
|------------|---------|--------|
| `group/qwen-profile` | `power-profiles-daemon` (1-member) | **UNUSED** — not in any config |
| `group/vr-power` | `idle_inhibitor` + `custom/ext-display` | Currently in config-vertical VR — renders as tiny pair |
| `group/vr-ai` | `custom/ollama` + `custom/llama` | Currently in config-vertical VR — renders as tiny pair |
| `group/vr-capture` | `custom/recorder` + `custom/dunst` | Currently in config-vertical VR — renders as tiny pair; member modules are ALSO listed stand-alone causing double-rendering |
| `group/vr-sys` | `custom/fnlock` + `custom/checkupdates` | Currently in config-vertical VR — renders as tiny pair |

All 5 `group/vr-*` groups compress 9 modules into 4 tiny horizontal-pair blobs. Per user rule #7, **no composite groups for action buttons**. Delete all 5 group definitions.

### F. Inline Modules (defined in bar configs, not in module files)

| Module ID | Defined in | Notes |
|-----------|-----------|-------|
| `custom/lang` | config-vertical | Exec polls `swaymsg` for layout every 1s |
| `custom/uptime` | config-bottom | `uptime -p`, interval 60 |
| `custom/powerbtn` | config-bottom (duplicate) | Inline def copies modules-peripherals one |
| `custom/ollama` | config-bottom (richer version) | Shows running model names, different exec than controls.json version |
| `sway/workspaces#bottom` | config-bottom | Bottom-bar workspace buttons |
| `clock` | config-vertical | ⚠️ **DEAD** — defined but not in any modules list |

---

## 2. Dead / Stale CSS Audits

### A. Selectors in `style/vertical.css` that match nothing

All `#group-vr-power`, `#group-vr-ai`, `#group-vr-capture`, `#group-vr-sys` selectors (and their `> widget`, `> widget > label`, divider-line descendants) will become dead once we remove VR groups. **Delete the entire VR section (lines 172-227).**

### B. Missing selector — `power-profiles-daemon`

`power-profiles-daemon` is in `modules-right` but `vertical.css` has **zero** rules targeting it. The module renders with base-only styling (14px font, default padding). **Must add a selector.**

### C. State selectors — current status

| Selector | Currently | After rewrite |
|----------|-----------|---------------|
| `#idle_inhibitor.activated` | Under `#group-vr-power #idle_inhibitor` | Flat `#idle_inhibitor.activated` |
| `#custom-ext-display.on` / `.off` / `.disconnected` | Under `#group-vr-power #...` | Flat |
| `#custom-ollama.on` / `.off` | Under `#group-vr-ai #...` | Flat |
| `#custom-llama.on` / `.off` | Under `#group-vr-ai #...` | Flat |
| `#custom-dunst.paused` | Under `#group-vr-capture #...` | Flat |
| `#custom-recorder.recording` | Under `#group-vr-capture #...` | Flat |
| `#custom-checkupdates.active` | Under `#group-vr-sys #...` | Flat |

All state logic preserves — just the selector scope changes from nested group to flat `#module-name`.

### D. `text-align` / `width:` / `min-width: auto` — never use (GTK parser crashes / rejects)

---

## 3. Unused Module Definitions

| Module | Source File | Status |
|--------|-------------|--------|
| `group/qwen-profile` | modules-controls.json | 1-member group, never placed. **DELETE.** |
| `group/vr-power` / `group/vr-ai` / `group/vr-capture` / `group/vr-sys` | modules-controls.json | Compressed 9 buttons into 4 blobs; user rejected groups. **DELETE.** |

**No standalone module is fully orphaned.** Every bare module (`power-profiles-daemon`, `idle_inhibitor`, `custom/dunst`, etc.) appears in at least one `config-*.json` modules list.

---

## 4. Placement Proposal

### Vertical Bar (`config-vertical`)

> Bar: `position: right`, `width: 200` (keep current), GTK auto-expands.
> 3-column flow-box: `modules-left`, `modules-center`, `modules-right`.

**VL (`modules-left`) — Monitor stack:**

```
group/qwen-gpu           ← GPU freq/temp
group/qwen-cpu           ← CPU avg/temp
group/qwen-ram           ← RAM used/swapped
group/qwen-ssd           ← SSD usage/IO
                        ← extra margin spacer between compute & I/O
group/qwen-asus          ← fan RPM + profile name (hybrid)
group/qwen-network       ← SSID + traffic (hybrid)
```

**VC (`modules-center`) — Language indicator only:**

```
custom/lang              ← small "EN"/"RU" card
```

(Empty otherwise. Transparent container keeps the 3-column structure.)

**VR (`modules-right`) — All 9 action/toggle controls, flat list, frequency-ordered top-to-bottom:**

```
power-profiles-daemon    ← HIGH  (top — most clicked)
idle_inhibitor           ← HIGH
custom/ext-display       ← HIGH
                        ← section spacer
custom/checkupdates       ← MEDIUM
custom/ollama            ← MEDIUM
custom/llama             ← MEDIUM
                        ← section spacer
custom/dunst             ← LOW
custom/recorder          ← LOW
custom/fnlock            ← LOW
```

**Rationale:**

- Flat list, no group wrappers. Each button full-width, individually styled. No tiny compressed pairs.
- 11 buttons × ~30px + 2 spacers × ~8px ≈ **346px** total — fits in a 1080p vertical bar with comfortable margins.
- HIGH-freq controls at the top of VR (easy reach). LOW-freq at the bottom.
- `lang` stays in VC as a small text-only indicator. The VC container has `background: transparent` so it's invisible — the 3-column GTK flow-box structure is preserved by having it there, but visually nothing wastes space.

### Bottom Bar (`config-bottom`)

Current BC has `custom/powerbtn` + `custom/uptime` — user flagged this as **wrong**.

**Proposed BC:** Empty. Or keep `custom/uptime` alone if user wants it.

**Proposed BR:** `tray` only. (Move `custom/ollama` out of BR since it's in VR.)

### Top Bar (`config-top`)

| Zone | eDP-1 (laptop) | HDMI-A-1 (external) |
|------|----------------|---------------------|
| TL | bluetooth#lite, group/audio | group/audio, bluetooth#lite |
| TC | group/top-center | group/top-center |
| TR | group/bright, **idle_inhibitor**, custom/keylight, battery, custom/powerbtn | group/bright-external, custom/keylight, battery |

**Add `idle_inhibitor` to eDP-1 TR.** The working state (commit `d641550`) had it there; current config does not. It's HIGH-freq and should be accessible from the top bar on the primary screen.

**`tray`**: currently in bottom BR. Move to top-bar eDP-1 TR (after battery, before end) — standard location for system tray.

---

## 5. Dimensions

### Vertical Bar bar-level

| Property | Value | Rationale |
|----------|-------|-----------|
| `width` | **200** (keep current) | GTK auto-expands to ~173px usable. 200 gives headroom. |
| `padding` (window) | `12px 4px` | breathing room top/bottom |

### VL — Monitor group cards (NO CHANGE from current values)

| Property | Value |
|----------|-------|
| group container `margin` | `8px 4px` |
| group container `padding` | `5px 0` |
| info card `min-width` | `104px` |
| info card `padding` | `5px 4px` |
| icon `font-size` | `16px` |
| info card `font-size` | inherits base 14px (keep current) |
| left border accent | 3px per-group color |

### VR — Action buttons (flat, bare modules)

| Property | Value |
|----------|-------|
| `min-height` | **30px** |
| `min-width` | 36px (icons) — 80px (ollama/llama labels) — 90px (ppd profile text) |
| `padding` | `6px 8px` |
| `margin` | `2px 4px` |
| Section first-child `margin-top` | `+8px` (spacer between freq tiers) |
| `font-size` | **15px** |
| `font-weight` | 500 (regular) |
| `border-radius` | 8px |
| Default background | `rgba(30, 30, 46, 0.92)` |
| Default border | `1px solid rgba(255, 255, 255, 0.08)` |
| Default color | `#a6adc8` |
| Hover: background | `rgba(40, 40, 56, 0.95)` |
| Hover: color | `#cdd6f4` |

**Why 30px not 24px and not 32px:** 24px was explicitly rejected as "unusable." 32px was described as "too large for simple icon toggles." 30px sits between.

**Why 15px font:** 14px was "too small"; 18px was "oversized." 15px is the middle.

### Top bar TR modules

| Module | `min-width` | `font-size` |
|--------|-----------|-----------|
| `group/bright` | slider 80px | icon 14px |
| `idle_inhibitor` | 32px | 15px |
| `custom/keylight` | 32px | 15px |
| `battery` | 40px | 17px bold |
| `custom/powerbtn` | — | 14px |
| `tray` | icon-size 20 | — |

### Bottom bar (after changes)

| Zone | Contents |
|------|----------|
| BL | `sway/workspaces#bottom` (unchanged) |
| BC | empty (or `custom/uptime` alone — per Q1) |
| BR | `tray` (if not moved to top) OR empty |

---

## 6. CSS Strategy Summary

**Approach:** Flat list of bare modules in VR, all sharing one base button rule + per-module overrides for width/state. No composite groups.

### Rewrite: Delete entire VR group section (lines 172–227 of `vertical.css`)

Removes: `#group-vr-power`, `#group-vr-ai`, `#group-vr-capture`, `#group-vr-sys` and all descendants.

### Add: Flat VR button rule

```css
/* VR — bare action controls */
.bar-vert .modules-right #power-profiles-daemon,
.bar-vert .modules-right #idle_inhibitor,
.bar-vert .modules-right #custom-ext-display,
.bar-vert .modules-right #custom-checkupdates,
.bar-vert .modules-right #custom-ollama,
.bar-vert .modules-right #custom-llama,
.bar-vert .modules-right #custom-dunst,
.bar-vert .modules-right #custom-recorder,
.bar-vert .modules-right #custom-fnlock {
  background: rgba(30, 30, 46, 0.92);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  margin: 2px 4px;
  padding: 6px 8px;
  font-size: 15px;
  color: #a6adc8;
  min-height: 30px;
  min-width: 36px;
  transition: background 0.15s ease, color 0.15s ease;
}

/* Section spacers — first element of MEDIUM and LOW tiers */
.bar-vert .modules-right #custom-checkupdates,
.bar-vert .modules-right #custom-dunst {
  margin-top: 10px;
}

/* Per-module width overrides */
.bar-vert .modules-right #custom-ollama,
.bar-vert .modules-right #custom-llama { min-width: 80px; }
.bar-vert .modules-right #power-profiles-daemon { min-width: 90px; }
```

### Add: State class overrides (flat, no group nesting)

```css
#idle_inhibitor.activated        { color: #94e2d5; background: rgba(0,128,128,0.25); border-color: rgba(148,226,213,0.6); }
#custom-ext-display.on           { color: #94e2d5; }
#custom-ext-display.off          { color: #585b70; }
#custom-ext-display.disconnected { opacity: 0.5; }
#custom-ollama.on                { color: #94e2d5; }
#custom-ollama.off               { color: #666; }
#custom-llama.on                 { color: #94e2d5; }
#custom-llama.off                { color: #666; }
#custom-dunst.paused             { color: #94e2d5; }
#custom-recorder.recording       { color: #f38ba8; }
#custom-checkupdates.active      { color: #a6e3a1; }
```

### ppd profile-name colors (only when placed in VR)

```css
#power-profiles-daemon.balanced    { color: #f9e2af; }
#power-profiles-daemon.performance { color: #fab387; }
#power-profiles-daemon.power-saver { color: #a6e3a1; }
```

### Top-bar `idle_inhibitor` addition (if approved Q5)

Add to existing `style/top.css` `#idle_inhibitor` rule set — already has `.activated` styling there, just needs to be added to `.modules-right` selector list so it gets TR-zone padding/margin.

---

## 7. Blocking Questions

### Q1. Bottom bar BC — what goes here?

Current: `custom/powerbtn` + `custom/uptime`. You said this is wrong.

- **Option A**: Move powerbtn → top bar eDP-1 TR. Keep uptime in BC alone (small, unobtrusive).
- **Option B**: Move both out. BC becomes empty. Uptime folded into top-bar `clock#date` tooltip (shows after clock text).
- **Option C**: Keep uptime in BC, move powerbtn elsewhere. Specify where.

### Q2. VR button height — confirm 30px or specify?

11 buttons × 30px + spacers ≈ 346px fits a 1080p screen. Your prior rejects: 24px ("unusable"), 32px ("too large"). **30px** is the middle. Different preference?

### Q3. Tray location?

Currently in bottom BR. Standard location is top.
- **Move tray → top bar eDP-1 TR** (after battery)?
- **Keep in bottom BR**?
- **Move elsewhere**?

### Q4. `idle_inhibitor` on top bar?

It's HIGH-freq. Working state (commit `d641550`) had it in eDP-1 TR. Current config does not.
- **Add `idle_inhibitor` to top bar eDP-1 TR**, or keep VR-only?

### Q5. `ollama` override in `config-bottom`?

`config-bottom` has its own inline `custom/ollama` definition (shows running model names, uses `jq -cn` ✓). `modules-controls.json` has a simpler exec. Both use `jq -cn` already.
- **Keep the richer version in config-bottom** AND add the simpler version to VR? (Two independent instances, both fine.)
- **Remove the config-bottom inline def** and let VR pull from modules-controls.json only?

### Q6. Delete the dead inline `clock` definition from `config-vertical`?

It's defined but not in any modules list — just extra JSON clutter. Safe to delete. **Confirm?**

---

## 8. Implementation Checklist (after user answers + approval)

- [ ] Edit `config-vertical`:
  - [ ] Move `custom/lang` remains in `modules-center`
  - [ ] Replace `modules-right`: remove all `group/vr-*`, list 9 bare modules in frequency order
  - [ ] Remove dead inline `clock` definition (Q6)
- [ ] Edit `modules-controls.json`:
  - [ ] Delete `group/vr-power`, `group/vr-ai`, `group/vr-capture`, `group/vr-sys`, `group/qwen-profile`
  - [ ] Keep all bare module definitions unchanged
- [ ] Edit `config-bottom` (per Q1 answer):
  - [ ] Remove `custom/powerbtn` if moving
  - [ ] Handle `custom/ollama` + `tray` per Q3/Q5
- [ ] Edit `config-top` (per Q4 answer):
  - [ ] Add `idle_inhibitor` to eDP-1 `modules-right` if approved
  - [ ] Add `tray` to eDP-1 `modules-right` if Q3 = top
- [ ] Rewrite `style/vertical.css`:
  - [ ] Delete lines 172–227 (VR group section)
  - [ ] Add flat VR button rule block
  - [ ] Add section-spacer margins
  - [ ] Add per-module state overrides (flat)
  - [ ] Add ppd profile-color overrides
  - [ ] Keep VL monitor-group CSS unchanged
  - [ ] Keep `#custom-lang` VC CSS (or remove if lang moves per future change)
- [ ] Edit `style/top.css` (if Q4 or Q3 approved):
  - [ ] Add `#idle_inhibitor` to TR selector list
  - [ ] Add `#tray` rules if moved to top
- [ ] Reload: `scripts/waybar-start.sh reload`
- [ ] Screenshot verification

---

*Waiting for user answers to Q1–Q6 before writing any code.*
