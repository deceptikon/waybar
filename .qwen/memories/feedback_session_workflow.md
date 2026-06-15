---
name: Session workflow — read STATUS.md at start, update at end
description: Always read STATUS.md at session start for context on current work state; always update it at task end to record what changed.
type: feedback
---

Always read `/home/lexx/.config/waybar/STATUS.md` at the start of every session to understand what's currently deployed and what's in progress.

**Why:** This project has multiple bars (production, dev, vertical, bottom) with shared configuration files. Without a status snapshot, it's easy to duplicate work, forget what's live vs. hidden, or lose context about recent migrations between bars.

**How to apply:** 
1. At session start: read STATUS.md before touching any config. Note what's deployed, what's hidden (dev bar), and what scripts/modules were recently changed.
2. After completing any task: update STATUS.md to reflect the new state — what changed, what's the current module lineup, any known issues still pending.
3. Keep it concise — one paragraph per bar, table for scripts, short commit list.