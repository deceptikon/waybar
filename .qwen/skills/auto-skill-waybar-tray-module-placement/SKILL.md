---
name: tray-module-horizontal-wrap
description: Wrap tray module in horizontal group for proper layout in vertical bars
source: auto-skill
extracted_at: '2026-06-16T08:30:00.000Z'
---

When placing the built-in `tray` module in a vertical bar's modules-center/left, it stacks icons vertically by default. To keep tray icons horizontal within a vertical bar, wrap tray in a `group/tray-h` horizontal group.

**Why:** The built-in `tray` module uses default vertical orientation which looks bad in narrow vertical bars. A horizontal group forces horizontal stacking while preserving the bar's vertical layout.

**How to apply:**

1. **Add group definition in qwen-modules.json:**
```json
"group/tray-h": {
  "orientation": "horizontal",
  "modules": ["tray"]
}
```

2. **Update bar config** (vertical bar):
```json
{
  "name": "bar-vert",
  "modules-center": [
    "clock",
    "group/tray-h",
    "custom/lang",
    "privacy"
  ],
  "include": [
    "/home/lexx/.config/waybar/qwen-modules.json",
    ...
  ]
}
```

3. **Unstyle tray for vertical bar** in `style.css` to remove default borders/padding:
```css
/* Tray in vertical bar — unstyled */
.bar-vert #tray {
  border: none;
  background: transparent;
  padding: 0;
  margin: 0;
  font-size: 12px;
  min-width: 0;
}

/* Keep default styling for horizontal bars */
#tray {
  padding: 0 10px;
  min-width: 120px;
}
#tray > .passive,
#tray > .active,
#tray > .needs-attention {
  border-radius: 4px;
}
```

**Example layout after applying:**
- Vertical bar center: `clock → tray-h (horizontal) → lang → privacy`

**Notes:**
- Ensure `qwen-modules.json` is included in the bar's `include` array
- The group name must match exactly (`group/tray-h` in config must equal `"group/tray-h"` in JSON)
- CSS selector `.bar-vert #tray` uses the bar name class to differentiate
