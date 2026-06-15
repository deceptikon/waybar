---
name: waybar-newline-bug
description: write_file mangles \n in bash scripts, use heredoc + printf for real newlines
source: auto-skill
extracted_at: '2026-06-14T19:08:00.000Z'
---

**Critical bug to avoid:** `\n` inside bash double-quotes is a **literal** backslash + n (two characters: `0x5C 0x6E`), NOT a newline byte (`0x0A`).

This caused two bugs:
1. **RAM module** — `\n` rendered as visible text (`\\n`) instead of line breaks
2. **CPU module** — `fgcolor='%s'` inside `awk '...'` got mangled, producing unquoted `fgcolor=#45475a` (Pango rejected it)

**Root cause:** Bash double-quotes preserve `\n` literally. `write_file` writes exactly what you give it, so the literal `\n` stayed as two characters.

---

## The Fix: Two Patterns

### Pattern 1: Heredoc + `printf` (Recommended)

```bash
# NEVER write scripts via write_file tool — it mangels \n
# Use shell heredoc to write files with real newline bytes:

cat > /path/to/script.sh << 'SCRIPT_END'
#!/bin/bash

# Use printf to interpret \n as a REAL newline byte (0x0A)
text=$(printf "<span ...>%s</span>\n<span ...>%s</span>" "$val1" "$val2")

jq -nc --arg text "$text" --arg cls "good" '{text:$text,class:$cls}'
SCRIPT_END

chmod +x /path/to/script.sh
```

**Why this works:**
- Heredoc (`cat > file << 'EOF'`) writes file content as-is, preserving `0x0A` newline bytes
- `printf` interprets `\n` inside its format string as a real newline (0x0A)
- No tool mangling between the editor/tool and the shell

### Pattern 2: `$'\n'` ANSI-C Quoting

```bash
#!/bin/bash

# $'\n' = ANSI-C quoting, produces real newline byte 0x0A
line1="<span ...>${val1}</span>"
line2="<span ...>${val2}</span>"
text="${line1}"$'\n'"${line2}"  # ← Uses $'...' for real newline

jq -nc --arg text "$text" --arg cls "good" '{text:$text,class:$cls}'
```

**Why:** `$'\n'` is bash's ANSI-C quoting syntax that produces `0x0A`, not literal `\n`.

---

## When to Use Which

| Scenario | Use | Reason |
|---|---|---|
| Script generation (one-time) | Heredoc + `printf` | Clean, explicit, no edge cases |
| Quick inline string concat | `$'\n'` | Fits in single line |
| Writing files via AI tool | **NEVER** - tool mangling | `write_file` preserves literal `\n` |

---

## Verification Before Reloading

Always test script output:

```bash
# Check for real newlines, not literal \n
bash script.sh | jq -r '.text' | od -c | grep -o '\\n'   # Should show 0x0A (shown as \n in od)

# Or visually:
bash script.sh | jq -r '.text' | cat -A   # Should show $ at end of lines, not \\n

# Test Pango rendering (no GTK warnings):
bash script.sh 2>&1 | grep -i error   # Should be empty
```

---

## Memory

This pattern (`bash \n = literal` + `write_file mangling`) is a **repeatable failure mode** for Waybar script generation. Never trust `write_file` for scripts containing `\n` — always use heredoc directly in shell.
