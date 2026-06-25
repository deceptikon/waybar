# POSTMORTEM — 2026-06-25: Vbar expand/collapse toggle rewrite

## What went wrong

I was given a working (if imperfect) toggle mechanism and asked to improve it. Instead of
making targeted fixes, I rewrote the architecture three times, each time breaking something
the previous version had working.

## Attempts

### Attempt 1: Copy + touch (original)
- `vert-compact-toggle.sh` copies `vertical-compact.css` or `vertical-full.css` over
  `vertical.css`, then touches it.
- **Problem**: `reload_style_on_change` (inotify) doesn't fire reliably → no visual
  change. Modules don't re-exec.

### Attempt 2: Symlink swap + setsid restart
- `vertical.css` becomes a symlink. Toggle swaps target + touches. `setsid` forks a
  targeted vertical bar restart.
- **Problem**: `pkill -f 'waybar.*config-vertical'` inside the `bash -c` wrapper also
  matches the wrapper itself (self-kill). Restart never completes. Bar goes dark.

### Attempt 3: @import loader, no restart
- `vertical.css` becomes `@import "vertical-full.css"` or `@import "vertical-compact.css"`.
  Toggle rewrites the import line + touches.
- **What worked**: CSS transitions fired — opacity, font-size, padding animated on reload.
- **What broke**: module content didn't change. VL sysmon data cards, VC tiles, VR service
  cards kept their old output. Waybar doesn't re-exec modules on CSS reload — only
  SIGRTMIN signals trigger re-exec, and even those don't work for `tail -F` modules that
  check the flag only at startup.

### Attempt 4 (current): @import fade-out + full restart
- Step 1: Write `@import "current.css"; window.bar-vert { opacity: 0; transition: 0.3s; }`
  → fade out via `reload_style_on_change`.
- Step 2: Flip `.vert-compact` flag.
- Step 3: Rewrite @import to new mode CSS.
- Step 4: Kill old bar.
- Step 5: Start new bar.
- **Problem**: Step 3 before Step 4 lets the old bar read the new @import and fade back in
  before dying (flicker). Also, `min-width: 100%` additions may have broken layout.

### Attempt 5 (will-fix, this document): Correct ordering + combined approach

## Root causes

1. **Overcomplication**: Three architecture rewrites instead of layering fixes on the
   working approach (restart).
2. **Self-kill in forked restart**: `pkill -f` matched the wrapper process.
   Fix: capture PID before forking, kill by PID.
3. **CSS size properties don't animate on reload**: GTK3 doesn't re-negotiate widget sizes
   when CSS `min-width` changes via reload. Only `opacity`, `font-size`, `padding`,
   `color` animate. Restart is required for size changes.
4. **Module re-exec requires restart**: CSS reload doesn't trigger module re-exec.
   SIGRTMIN works for some modules but not `tail -F` ones that check a startup
   condition.
5. **@import reload ordering**: Writing the new mode @import before killing the old bar
   causes a visual flicker (bar fades in then dies).

## Lessons

- **Restart is reliable. Fade is CSS. Do both, in order:**
  1. Fade out (CSS reload)
  2. Kill old bar (no file change)
  3. Write new mode CSS
  4. Start new bar (fresh, correct)
  5. Fade in (CSS reload again)

- `pkill -f` is dangerous in self-spawning scripts. Capture PIDs before forking.

- Test the toggle sequence end-to-end before declaring done. A single `waybar -l debug`
  run catches CSS errors but not logic errors in the toggle script.

- When the user says "it works" about restart, believe them. Add animations on top
  of the working mechanism — don't replace the mechanism.
