# Waybar — Session Handoff

## Current State (2026-06-26)

### Bars (all 4 running)
| Bar | Config | CSS | Width | Status |
|-----|--------|-----|-------|--------|
| Top | `config-top` (eDP-1 + HDMI-A-1) | `style/top.css` | 1920 | OK |
| Vertical | `config-vertical` | `style/vertical.css` | 138 (expands ~173) | OK |
| Vertical-lite | `config-vertical-lite` | `style/vertical-lite.css` | 69 (start_hidden) | OK |
| Bottom | `config-bottom` | `style/bottom.css` | 1920 | OK |

### Docs cleaned up
- Deleted stale: `README.md`, `STRUCT.md`, `STATUS.md`, `PROMPT_REDESIGN.md`, `VERTICAL_PLACEMENT` copy
- Rewrote: `AGENTS.md`, `FLOW.md`, `INDEX.md`, `STRUCTURE.md`, `STATE.md`, `STORIES.md`
- Kept: `POSTMORTEM-2026-06-24.md`, `POSTMORTEM-2026-06-25.md`, `CUSTOM_MODULE_GUIDE.md`
- `VERTICAL_PLACEMENT.md` → marked DEPRECATED
- `ForFutureUs.md` → this file

### Recent commit
`c73542a` compact sysmon: tighten bars (n=4), use Pango line_height, tweak VL CSS

### Known issues
1. **Toggle-vert-lite**: Sends SIGUSR1 but waybar doesn't handle this signal. Non-functional.
2. **power-profiles-daemon**: Not installed, dbus error in log (benign). System uses `asusctl`.
3. **line-height**: No instances found in current CSS (was a legacy GTK parser error).
4. **VL icons in compact mode**: Need verification that icons render when data cards are hidden.

### Next Steps (ask user)
1. Fix toggle-vert-lite (SIGUSR1 → full restart?)
2. Verify VL compact icons
3. Test animations
4. Any of the STORIES (TL/TR polish, VL cramping, VR sizing, BR direction)
