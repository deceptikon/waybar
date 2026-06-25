# Postmortem — 2026-06-24 VC Tile Grid Session

## What we started with
Antigravity implemented the 4-pattern vertical bar proposal. Config/CSS/scripts all scaffolded, 9 files created/modified, **nothing tested or reloaded**. Bar was crashing on reload.

## What was fixed this session

| # | Bug | Fix |
|---|-----|-----|
| 1 | Bar crash in compact mode | `@keyframes` multi-stop syntax — GTK only accepts `to { }` single-stop. Rewrote. |
| 2 | Bar crash in full mode | `min-width: 0 / min-height: 0` produces zero-size widgets → GTK "invalid matrix" crash. Replaced with `4px / opacity: 0`. |
| 3 | `max-width` invalid GTK property | Removed. GTK CSS has no `max-width`. |
| 4 | PPD dbus errors | `power-profiles-daemon` not installed on this Arch box. Not our bug — uses `asusctl` instead. Empty PPD tile is environmental. |
| 5 | SIP glyphs garbled in VC tiles | Scripts output Supplementary Plane icons (U+F033D, U+F0336, U+F05A9) that the font doesn't have. |
| 6 | Pipe hack exec overrides in config-vertical | Layered on top of #5 to strip Pango markup. Wrong layer. |
| 7 | idle_inhibitor blank tile | Was U+F04B/U+F04D (FontAwesome) — not in this Nerd Font. → U+F28D/U+F186 (BMP). |

**Done properly:**
- Fixed 3 scripts at source: `fn-lock.sh` (→ U+F11C), `kbd_status_json.sh` (→ U+F0EB), `ext-display.sh` (→ U+F26C)
- Removed pipe hack exec overrides from `config-vertical`
- Removed `max-width` from `vertical.css`
- `vertical-compact.css` `@keyframes` rewritten to single-stop syntax

## What was NOT done (still broken)

- **P1 VC tile grid visual verification** — config fixes applied, exec overrides removed, scripts patched. Three bars alive after reload. But no screenshot confirms it actually renders 2-column.
- **P2 service console verification** — mini glyph scripts (`ollama-mini`, `llama-mini`, etc.) were never audited. Same SIP glyph risk applies to them.
- **Menu wiring** — 3 menu XMLs exist in `feeds/` but no module references them (`menu` or `on-click-right`). Menus dead.
- **ASUS profile tile** — works (U+F013 BMP), but PPD slot next to it remains blank (no PPD on this box).
- **Compact mode toggle round-trip** — toggle button exists, flag file logic works, but visual confirmation of compact→full toggle cycle not done.
- **task.md** — still shows tasks as unchecked.

## Where time went wrong

**Pattern of false work:** I generated multiple Python one-liners, regex experiments, and multi-step shell commands to clean exec overrides in `config-vertical`. None worked on the first try. The actual fix — 3 lines of `sed` or a 5-line Python script addressing lines by number — was straightforward. Instead of doing it, I iterated on broken approaches. That's imitation of progress.

**Specific waste:**
- 2 rounds of `edit` tool failures because SIP unicode bytes in file didn't match my literal strings
- A heredoc Python attempt with quoting errors
- A `re.sub` regex that didn't account for escaped unicode syntax
- A `replace` approach inside Python that produced syntax errors

**Total wasted turns on the exec cleanup:** ~4. Could have written a targeted Python script by line number on turn 1.

## Root lesson

When a multi-step regex/replace approach fails, **switch to direct line-addressed replacement**. Don't keep polishing the fragile parser — address the file by structure (line numbers, specific markers) and move on.

## Blocking questions for next session

1. **P1 tiles actually rendering?** — Bar is up, scripts emit BMP, but no screenshot confirmed the 2-column layout actually works now. User screenshot next.
2. **P2 mini scripts audited?** — `checks/ollama-mini`, `llama-mini`, `updates-mini` execs may also have SIP glyphs. Need to check before declaring P2 fixed.
3. **Compact mode toggle works end-to-end?** — Toggle → flag file → style swap → visual change → back. Not yet verified.
4. **Menues wired or abandoned?** — 3 XML files exist, zero modules reference them. Either wire them or delete them.
5. **PPD tile — swap for asusctl?** — User's note was clear: we use `asusctl`, not PPD. But the tile is already blank. Question is whether to replace it or accept the blank slot.

## Files changed this session

| File | Action |
|------|--------|
| `style/vertical.css` | Removed `max-width`; mini hide changed from `min-width:0` to `4px`/`opacity:0` |
| `style/vertical-compact.css` | `@keyframes` rewritten; sysmon/P2 hide changed likewise |
| `scripts/utils/fn-lock.sh` | Replaced SIP output with U+F11C + tooltip |
| `scripts/utils/keylight/kbd_status_json.sh` | Replaced SIP output with U+F0EB + tooltip |
| `scripts/utils/ext-display.sh` | Replaced SIP output with U+F26C + tooltip |
| `config-vertical` | Removed pipe hack execs for fnlock/keylight/ext-display (now direct script calls) |
