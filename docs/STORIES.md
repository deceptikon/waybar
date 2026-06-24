# Waybar Stories — Big Reworks (Handle in Separate Sessions)

## STORY-TL: Top bar TL/TR zone overhaul
**Zone:** Top bar — `modules-left` (powerbtn, bluetooth, audio) and `modules-right` (bright, keylight, battery)
**Problem:** Both zones look unpolished. Current layout shows powerbtn + BT + audio slider on TL, bright + battery + icons on TR. They clash in visual weight, spacing, and styling. TC (center) is good as-is.
**Notes:**
- TL has `border-radius: 0 0 12px 0`, TR has `border-radius: 0 0 0 12px` — asymmetric but intentional; may need rebalance
- Audio slider dominates TL
- Battery icon oversized in TR
- `custom/powerbtn` duplicated on HDMI-A-1 (both left and right)

---

## STORY-VL: Vertical left module polish
**Zone:** VL (vertical left) — monitor groups (GPU, CPU, RAM, SSD, ASUS, network)
**Problem:** Font too large for 173px actual width. Groups are cramped together with almost no breathing room between them.
**Notes:**
- Current: `min-width: 104px` but all cards appear at different visible widths
- Group containers: `padding: 3px 0, margin: 4px 2px` — need more vertical spacing
- `font-size: 14px` in base.css propagates; info cards use base font which is too big for the vertical format
- Network group (`group/qwen-network`) and power profile (`power-profiles-daemon` in VC) don't visually integrate

---

## STORY-VR: Vertical right button consolidation
**Zone:** VR (vertical right) — dunst, recorder, checkupdates, fnlock, idle_inhibitor, ext-display
**Problem:** Buttons too large (`min-height: 32px, min-width: 36px, font-size: 18px`) for simple icon toggles. Wastes space.
**Notes:**
- These are low/medium frequency actions — don't deserve 32px+ each
- LLM orphan buttons (ollama/llama) from VC should be absorbed here
- Need compact icon-row layout instead of stacked large cards

---

## STORY-BR: Bottom right prettification
**Zone:** BR (`bar-bottom` → `modules-right` = ollama + tray)
**Problem:** Undefined — needs design direction. Currently has ollama status + tray at `icon-size: 15`.
**Decision needed:** What should live in BR? Tray relocation target? Quick toggles? Or empty this zone?

---

## Current Status
- Stories tracked here; do NOT touch until user schedules a session for one
- Quick fixes tracked in `VISUAL_ISSUES_CHECKLIST.md`
