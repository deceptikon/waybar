# Waybar Stories — Big Reworks (Separate Sessions)

## STORY-TL: Top bar TL/TR zone overhaul
**Problem:** Top bar left/right zones look unpolished — powerbtn + BT + audio slider vs bright + battery clash in visual weight.
**Notes:**
- TL `border-radius: 0 0 12px 0`, TR `border-radius: 0 0 0 12px` — asymmetric but intentional
- Audio slider dominates TL; battery icon oversized in TR
- `custom/powerbtn` appears on both eDP-1 left and right

## STORY-VL: Vertical left module polish
**Problem:** Monitor groups cramped in 173px actual width. Font too large.
**Notes:**
- Group containers `padding: 3px 0, margin: 4px 2px` — need more vertical spacing
- `font-size: 14px` in base.css propagates; info cards need smaller font for vertical

## STORY-VR: Vertical right button consolidation
**Problem:** VR buttons still large (`min-height: 30px, min-width: 36px, font-size: 15px`) for simple icon toggles.
**Notes:**
- These are low/medium frequency actions — could be more compact
- ollama/llama have text labels, need wider min-width

## STORY-BR: Bottom right prettification
**Problem:** Undefined — needs design direction.
**Decision needed:** What should live in BR? Tray relocation target? Quick toggles? Empty?

## Guidelines
- Stories tracked here; do NOT touch until user schedules a session
- STORY-TL/VL/VR/BR are independent and can be done in any order
