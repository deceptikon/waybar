---
name: waybar-module-debugging
description: Diagnosing and fixing broken or blank Waybar module tiles (icon missing, wrong data, signal loops)
source: auto-skill
extracted_at: '2026-06-16T06:48:20.361Z'
---

## Problem Patterns

1. **Blank icon tile**: Script outputs correct JSON but character doesn't exist in your Nerd Font. Solution: Test with `printf '<utf8>' | od -c` and compare known working glyphs.
2. **Wrong data shown**: Script runs fine in isolation (test with `~/.config/waybar/scripts/<name>.sh 2>&1 | jq .`) but Waybar shows different output. Check if `interval: 1000` + `signal` pattern causing self-signaling infinite loops.
3. **Click-stealing/toggle loops**: `exec` calling script without "refresh" + `interval: 1000` + `signal` makes script fire `pkill -SIGRTMIN+N` every poll cycle. Solution: Either remove signal toggle entirely (just polled icon), or add `if [ "${1:-}" = "refresh" ]` check to only signal on click path.

## Diagnostic Steps

1. **Test script**: `~/.config/waybar/scripts/<script>.sh 2>&1 | jq .`
2. **Verify JSON output**: `~/.config/waybar/scripts/<script>.sh 2>&1 | jq -r '.text' | od -c`
3. **Check icon rendering**: `printf '\xf3\xb0\x85\x85'` and compare visual vs known working `U+F1DB` (``) or `U+F035B` (`󰍛`)
4. **Verify config**: `jq '.["custom/<name>"]' qwen-modules.json`
5. **Restart Waybar**: `pkill waybar && sleep 1 && waybar &` (full restart clears cached state)

## Toggle Module Pattern (working)

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh refresh",
  "interval": 1000,
  "signal": <unused_int>,
  "on-click": "~/.config/waybar/scripts/<name>.sh",
  "format": "{}",
  "return-type": "json"
}
```

Script must handle `${1:-}` to distinguish "refresh" vs click-only modes.

## Non-toggle (polling) Pattern (simpler for icons)

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh",
  "interval": 5,
  "format": "{}",
  "return-type": "json"
}
```

No signal, no on-click toggle logic.

## Bash Script Caveats

- **Never use `write_file`** for scripts that need literal `\n` — heredoc (`cat > file << 'EOF' ... EOF`) preserves real newlines
- **Remove `set -euo pipefail`** silently on awk failures (grep exit 1 = script dies); test without it first
- **Use heredoc + printf** for UTF-8 character literals in scripts to avoid shell mangling