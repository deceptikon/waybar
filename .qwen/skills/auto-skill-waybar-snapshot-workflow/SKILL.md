---
name: waybar-snapshot-workflow
description: SESSION START: Read STATUS.md for current state; SESSION END: Update STATUS.md with changes made
source: auto-skill
extracted_at: '2026-06-16T06:48:20.361Z'
---

## Rule
At the **start of every session**: read `~/.config/waybar/STATUS.md` to understand what's deployed, what's hidden, and recent commit history.  
At the **end of every task**: update STATUS.md with the current state and changes.

## Why
Waybar has multiple bars (production, dev, vertical, bottom) with shared config/scripts. Without a status snapshot, easy to duplicate work or lose context about migrations between bars.

## When to Update
- After moving modules between bars
- After changing script logic or CSS
- After adding/removing modules
- When dev bar output/output config changes

## How to Update STATUS.md
1. **Bar lineup**: One line per bar listing modules-left/center/right
2. **Scripts**: Table of key scripts and their purpose
3. **Recent commits**: Last 3-4 commit hashes + titles
4. **Known issues**: Any unresolved problems (e.g., bar height exceeding config)

## Example Update Pattern
```markdown
## Recent commits
```
cfae4ce 135:08 Migrate dev bar qwen modules to production top bar
f7edeb0     CPU module: per-core 16-block usage grid, big 2-line layout
```

## Current State
### Top bar (`bar-horiz`) — production
Modules-left: `powerbtn → temp-fan → group/qwen-cpu → group/qwen-ram → group/qwen-ssd → group/qwen-network`
```

## File Locations
- **STATUS.md**: `/home/lexx/.config/waybar/STATUS.md`
- **Skills memory**: `.qwen/memories/feedback_session_workflow.md` (auto-created)