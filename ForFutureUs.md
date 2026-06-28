# Waybar — Session Handoff

## Current State (2026-06-28)

### Bars (all 4 running)
| Bar | Config | CSS | Width | Status |
|-----|--------|-----|-------|--------|
| Top | `config-top` (eDP-1 + HDMI-A-1) | `style/top.css` | 1920 | OK |
| Vertical | `config-vertical` | `style/vertical.css` | 138 (expands ~173) | OK |
| Vertical-lite | `config-vertical-lite` | `style/vertical-lite.css` | 69 (start_hidden) | OK |
| Bottom | `config-bottom` | `style/bottom.css` | 1920 | OK |

### Module config files
| File | Group | Used by |
|------|-------|---------|
| `modules-vc.json` | Vertical controls (ollama, llama, recorder, fnlock, powerbtn, dunst, ext-display, profile, idle_inhibitor) | Vertical & Vertical-lite |
| `modules-sysmon.json` | Sysmon (network, gpu, cpu, ram, ssd, asus, netfan) | Vertical |
| `modules-peripherals.json` | Peripherals (audio, brightness, battery, bluetooth, wifi, ddc, keylight) | Top |
| `modules-top-shared.json` | Top bar (clock, workspaces, window, scratchpad, privacy) | Top |

### Recent commit
`d0ee118` — inline checkupdates + icon modules, rename `modules-controls` → `modules-vc`, dedup `custom/powerbtn`

### Known issues
1. ~~**`custom/checkupdates` not displaying** — Fixed by removing `set -euo pipefail` from `scripts/utils/checkupdates.sh`. `yay -Qu` returns non-zero when no updates, and `-e` (errexit) was killing the script before it could produce JSON output.~~
2. **Toggle-vert-lite**: Sends SIGUSR1 but waybar doesn't handle this signal. Non-functional.
3. **power-profiles-daemon**: Not installed, dbus error in log (benign). System uses `asusctl`.
4. **VL icons in compact mode**: Need verification that icons render when data cards are hidden.

### Next Steps (ask user)
1. Fix `custom/checkupdates` — try moving definition into each bar config directly
2. Fix toggle-vert-lite (SIGUSR1 → full restart?)
3. Verify VL compact icons
4. Test animations
