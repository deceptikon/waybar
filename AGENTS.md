# Waybar Config — AGENTS.md

## Structure
- **Config files**: One JSON file per bar (`config-top`, `config-vertical`, `config-vertical-lite`, `config-bottom`). Vertical bars share `config-vertical-base.jsonc` (layer, position, compact-* defs).
- **Inheritance**: `config-top` is an array with two bar objects (eDP-1 + HDMI-A-1). Both inherit from `config-top-base.jsonc` via `include`. Base holds all shared settings (layer, position, module lists). Each bar overrides only `name`, `output`, and custom modules.
- **Module files**: `modules-*.json` files hold per-module configs, included via `"include"` inside the base.
- **CSS**: `style/base.css` (shared layout), `style/top.css` (top bar overrides + inline Catppuccin @define-colors), `style/vertical.css`, `style/vertical-lite.css`, `style/bottom.css`.
- **Scripts**: `scripts/waybar-start.sh` starts all 4 bars sequentially (0.5s gaps) — full restart on reload (pkill + start). Other scripts in `scripts/utils/`, `scripts/network/`, `scripts/sysmon/`.

## Key Decisions
- **No SIGUSR2 reload**: GLib assertion crash with multiple bar instances. Full restart (pkill + sequential start) is the only reliable method.
- **No preset system**: Was broken (reload never worked). `@define-color` is inline in `top.css`.
- **Per-bar D-Bus names**: `bar-top` vs `bar-top-ext` avoids name conflicts within a single waybar process. `bar-vert` / `bar-vert-lite` follow same pattern.
- **Group-based modules**: `group/audio`, `group/bright`, `group/qwen-*` combine icon + info card sub-modules.

## Running
- `scripts/waybar-start.sh start` — start all bars.
- `scripts/waybar-start.sh reload` — full restart.
- `scripts/waybar-start.sh stop` — kill all.

## CSS Conventions
- Waybar generates CSS IDs from module names: `bluetooth#lite` → `#bluetooth-lite`, `group/audio` → `#group-audio`, `clock#date` → `#clock-date`.
- Group containers use `#group-xxx`. Bare `#xxx` never matches group modules.
