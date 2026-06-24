# Промпт для новой сессии — Waybar vertical bar redesign

Скопируй содержимое от «BEGIN PROMPT» до «END PROMPT» в новую сессию.

---

## BEGIN PROMPT

Read `/home/lexx/.config/waybar/AGENTS.md` first, then scan the files `docs/STRUCTURE.md`, `docs/VISUAL_ISSUES_CHECKLIST.md`, `docs/STORIES.md`, and the current `config-vertical`, `config-bottom`, `config-top`, `style/vertical.css`, `style/bottom.css`.

You are redesigning the **Waybar vertical bar layout** (`~/.config/waybar`). The previous sessions (500+ tool calls across multiple models) made things WORSE by:
- Changing config without understanding what each module does
- Lumping unrelated modules into named "groups" that rendered as tiny unclickable blobs
- Shrinking buttons to 24px height, 14px font — unusable for daily controls
- Removing `power-profiles-daemon` just because the CSS had a DBus error (service is running but GTK CSS parser was rejecting unrelated `line-height` rule)
- Never actually asking the user where they want things BEFORE editing

### What you KNOW from the prior sessions:

**Module taxonomy** (documented in `docs/STRUCTURE.md`):
- **Monitors** (show data, click opens viewer): GPU, CPU, RAM, SSD
- **Hybrids** (show data AND click does action): ASUS (fan RPM + profile cycle), Network (SSID + nm-connection-editor)
- **Actions/toggles** (icon, toggle on click): ppd, ext-display, idle_inhibitor, dunst, recorder, fnlock, checkupdates, ollama, llama
- **Indicators** (show state): lang, battery, bluetooth
- **Interactive sliders**: audio, backlight (horizontal only, top bar)

**Daily usage frequency** (user's own words):
- HIGH frequency (clicked daily): ppd, ext-display, idle_inhibitor
- MEDIUM: checkupdates (indicator), ollama/llama
- LOW: dunst, recorder, fnlock

**What was working before** (commit `d641550`):
- `modules-right` had: `power-profiles-daemon`, `custom/dunst`, `custom/recorder`, `custom/checkupdates`, `custom/fnlock`, `custom/ext-display`
- Each button: min-width 36px, min-height 28px, font-size 18px, padding 6px 8px
- `modules-center` had: `custom/lang`, `custom/ollama`, `custom/llama`
- `modules-left` had all 6 qwen groups (monitors + hybrids)
- width: 138 (but GTK expanded to ~173 actual)

**What broke**:
- I split buttons into 2-element "groups" (`group/vr-power`, `group/vr-ai`, etc.) — rendered as tiny compressed blobs
- I shrank buttons (24px height, 14px font)
- I removed ppd, ollama, llama from vertical config at various points without restoring
- I never asked WHERE user wants things before putting them somewhere

**Current state** (read the actual files — they may be broken):
- `config-vertical`: width 200, VR has 9 modules including groups that don't match CSS
- `style/vertical.css`: has stale VR group selectors that don't match current config
- Bottom bar BC has `custom/powerbtn` + `custom/uptime` — user says this is wrong
- Top bar eDP-1 right: bright, keylight, battery, powerbtn
- Top bar HDMI-A-1 right: bright-external, keylight, battery (no powerbtn — user wanted that)

### What you must produce for the user BEFORE touching any code:

A single markdown file at `docs/VERTICAL_PLACEMENT.md` containing:

1. **Catalog of every module** that exists across sysmon/controls/peripherals/mon-shared JSON files — name, type (monitor/hybrid/action/indicator/slider), what it shows, what click does.

2. **Placement proposal**: for each bar zone (VL, VC, VR, also BC, TL, TR), list exactly which modules go there and in what order.

3. **Dimensions**: width/height, per-button sizes, font sizes, margin values.

4. **CSS strategy**: which selectors apply, how groups are styled, how individual buttons are styled, how state classes (.balanced, .activated, .on, .recording, etc.) override base style.

5. **Questions for user** — ONLY things that block you. Don't ask about things you can infer. Don't ask about things that have clear defaults.

### Rules (follow them strictly):

1. Read all config and CSS files before proposing anything.
2. Read `docs/STRUCTURE.md` and `docs/VISUAL_ISSUES_CHECKLIST.md` for context.
3. Don't write a single `edit`, `write_file`, or `run_shell_command` that touches `config-*.json`, `style/*.css`, or `modules-*.json` until the user has explicitly approved the placement document.
4. If a selector in CSS doesn't match a module name in config, flag it. Don't silently leave dead CSS.
5. If a module config exists in modules-*.json but is not referenced in any config-*.json, flag it as unused.
6. Do not remove modules the user has not explicitly named for removal.
7. Do not group modules into named composite groups unless the user asks for that.
8. Default button sizing: min-width 36px, min-height 28px, font-size 15–18px, padding 6px 8px — unless user specifies otherwise.
9. The ollama exec in modules-controls.json must use `jq -cn` (not `jq -n`) for compact single-line JSON output.
10. power-profiles-daemon DBus error is a GTK CSS parser issue with `line-height` — NOT a ppd service issue. Do NOT remove ppd because of DBus errors. The DBus error appears because waybar's CSS parser rejects an unrelated property and the line number is wrong.

## END PROMPT

---

## Notes (do not include in prompt — for the user only)

- The old working baseline is commit `d641550`. You can `git show d641550:config-vertical` and `git show d641550:style/vertical.css` to see what worked.
- `docs/STRUCTURE.md` was auto-generated in the broken session. Verify its data against the actual JSON files — it may be stale.
- `docs/VISUAL_ISSUES_CHECKLIST.md` has 7 issues, most of which are now moot (we made more changes).
- The user's core insight: ASUS and Network are NOT monitors — they are action controls that happen to display data. They were in VL (monitors zone) because there was no better home. Moving them to VC (actions zone) is the correct architectural fix, but the user never explicitly approved it before. Ask.
- The user said "Buttons became more unusable because request was to restructure, regroup." That means: regrouping is fine, but NOT if it results in unrecognizable tiny blobs. The grouping must preserve button usability.
