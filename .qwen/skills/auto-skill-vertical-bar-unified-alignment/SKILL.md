---
name: vertical-bar-unified-alignment
description: Unifying vertical bar module widths, margins, and paddings for consistent layout
source: auto-skill
extracted_at: '2026-06-16T12:59:38.810Z'
---

# Vertical Bar Unified Alignment Pattern

When adding modules to a Waybar vertical bar, ensure all grouped modules share consistent dimensions to avoid visual misalignment.

## Approach

1. **Define a common min-width** (e.g., 110px) for all vertical bar modules
2. **Use uniform margins** (e.g., `4px 0`) between modules
3. **Standardize padding** (e.g., `4px 6px`) for outer group wrappers
4. **Apply bar-scoped selectors** using `.bar-vert #module` prefix

## Example CSS

```css
/* === VERTICAL BAR — unified module alignment === */
.bar-vert #group-qwen-cpu,
.bar-vert #group-qwen-ram,
.bar-vert #group-qwen-ssd,
.bar-vert #group-qwen-network,
.bar-vert #custom-temp-fan,
.bar-vert #custom-asus-profile {
  min-width: 110px;
  margin: 4px 0;
  padding: 4px 6px;
}

/* Optional: per-module border color */
.bar-vert #group-qwen-cpu { border-color: rgba(166, 227, 161, 0.5); }
.bar-vert #group-qwen-ram { border-color: rgba(137, 180, 250, 0.5); }
.bar-vert #group-qwen-ssd { border-color: rgba(166, 227, 161, 0.5); }
.bar-vert #group-qwen-network { border-color: rgba(148, 226, 213, 0.5); }
```

## Notes

- **Do NOT use `max-width`** — Waybar CSS parser throws errors for it
- Keep icon sizes consistent (e.g., 16px instead of 20px) for compact vertical layouts
- Outer group wrappers should have solid dark background (`rgba(20, 20, 28, 0.92)`) with colored border
- Inner info tiles should use slightly lighter background with matching border

## Why

Without unified dimensions, modules appear with varying heights and gaps, breaking the visual rhythm of the vertical bar. This pattern ensures all groups snap to the same visual grid.