# Waybar — Session Handoff

## Current State (2026-07-07)

### Bars (all 4 running)
| Bar | Config | CSS | Status |
|-----|--------|-----|--------|
| Top | `config-top.tmpl` (eDP-1 + HDMI-A-1) | `style/top.css` | OK |
| Vertical | `config-vertical.tmpl` | `style/vertical.css` | OK |
| Vertical-lite | `config-vertical-lite.tmpl` | `style/vertical-lite.css` | OK |
| Bottom | `config-bottom.tmpl` | `style/bottom.css` | OK |

### Where configs live now

Waybar config is part of the **arch-deploy monorepo** at:
```
arch-deploy/dotfiles/dot_config/waybar/
```
Deployed to `~/.config/waybar/` via `chezmoi apply`.  
Config files are chezmoi **templates** (`.tmpl` extension) — rendered at deploy time.  
Scripts are all `executable_`-prefixed so chezmoi auto-sets `chmod +x`.

### Module config files
| File | Group | Used by |
|------|-------|---------| 
| `modules-vc.json` | Vertical controls (ollama, llama, recorder, fnlock, powerbtn, dunst, ext-display, idle_inhibitor) | Vertical & Vertical-lite |
| `modules-sysmon.json` | Sysmon (network, gpu, cpu, ram, ssd, asus, netfan) | Vertical |
| `modules-peripherals.json` | Peripherals (audio, brightness, battery, bluetooth, wifi, ddc, keylight) | Top |
| `modules-top-shared.json` | Top bar (clock, workspaces, window, scratchpad, privacy) | Top |

### Recently fixed
- `ext-display.sh` — `command -v` was leaking to stdout, breaking JSON parse. Fixed with `>/dev/null`.
- `toggler.sh` / `keywatcher.sh` — autobacklight regex was broken. Reverted to working state.
- All scripts now named `executable_*.sh` for chezmoi compatibility.
- Error logging: errors go to `/tmp/waybar_errors.log` instead of being silenced.

### Known issues
1. **toggle-vert-lite**: Sends SIGUSR1 but waybar doesn't handle this signal. Non-functional.
2. **power-profiles-daemon**: Not installed, dbus error in log (benign). System uses `asusctl`. Power mode switch deferred (asusd issue).
3. **VL icons in compact mode**: Need verification that icons render when data cards are hidden.

### Next Steps
1. Fix toggle-vert-lite (SIGUSR1 → full restart with flag?)
2. Verify VL compact icons
3. Test animations
4. asusd power mode switch investigation
