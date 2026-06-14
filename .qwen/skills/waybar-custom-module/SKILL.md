# Waybar Custom Module — Creation Guide

End-to-end guide for adding a new indicator module to the Waybar config at `/home/lexx/.config/waybar`.

## Quick Checklist

For each new module you need to touch 4 files:

```
scripts/<name>.sh           # executable script, outputs JSON
default-modules.json        # module definition (or <group>.json)
config                      # add module to some bar's modules-left/center/right
style.css                   # #<module-id> selector + optional state classes
```

Then: validate → reload → commit.

## 1. Bash Script

### Must output valid Waybar JSON

```bash
jq -n --compact-output \
  --arg text "icon  SSID" \
  --arg cls "medium" \
  --arg tip "tooltip text" \
  '{text: $text, class: $cls, tooltip: $tip}'
```

Fields:
- `text`: display string. Supports Pango markup (`<b>`, `<i>`, `<span fgcolor='#rrggbb'>`, `<span size='small'>`). Use `\n` inside text for two rows.
- `class`: CSS class name appended to the module element. Common values: `good`, `medium`, `warning`, `critical`, `disconnected`, `icon`.
- `tooltip`: hover text, also supports Pango markup.

### Unicode glyphs — MUST embed via explicit bytes

UTF-8 characters for Nerd Font icons **do NOT survive** being written into the file as literal characters. Use `printf` with hex byte sequences:

```bash
icon=$(printf '\xf3\xb1\x98\xb2')   # 󱘲 nf-mdi-ssd (U+F1632)
```

Get bytes for any codepoint:
```bash
python3 -c "cp='\U000f1632'; print(' '.join(f'{b:02x}' for b in cp.encode('utf-8')))"
# → f3 b1 98 b2
```

### Safe pipeline pattern

```bash
# BAD — set -euo pipefail + grep exits 1 = script aborts
set -euo pipefail
val=$(cat foo | grep "pattern" | wc -l)

# GOOD — wc -l always succeeds, no set in exec path
val=$(grep "pattern" foo 2>/dev/null | wc -l)
```

**Never** put `set -euo pipefail` in an exec script. The refresh path runs frequently and any pipeline that has a grep match-or-not pattern will randomly kill your script.

Never call `pkill -SIGRTMIN+N waybar` from the exec/refresh path — that creates an infinite refresh loop. Only the on-click path may signal.

### Live data sampling

For I/O, CPU, or any "rate" metric, sample twice with a `sleep` between:

```bash
stat_file="/sys/block/$dev/stat"
r1=$(awk '{print $3}' "$stat_file"); w1=$(awk '{print $7}' "$stat_file")
sleep 0.5
r2=$(awk '{print $3}' "$stat_file"); w2=$(awk '{print $7}' "$stat_file")
delta_r=$(( (r2 - r1) * 512 / 2 ))   # sectors × 512 bytes / 0.5s
```

### Read CPU usage from /proc/stat

```bash
sample() { awk '/^cpu / {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; print tot, idle}' /proc/stat; }
read t1 i1 < <(sample); sleep 0.5; read t2 i2 < <(sample)
dt=$((t2 - t1)); [ "$dt" -le 0 ] && dt=1
pct=$(( (dt - (i2 - i1)) * 100 / dt ))
```

### File permissions

```bash
chmod +x scripts/<name>.sh
```

## 2. Module Definition (JSON)

### Single-module

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh",
  "interval": 5,
  "format": "{}",
  "return-type": "json",
  "on-click": "some-launcher",
  "on-right-click": "other-launcher"
}
```

Key notes:
- `interval`: how often exec re-runs. 5-10s for live data, 30-60s for slow-changing state.
- `return-type: "json"`: tells Waybar to parse script output as JSON, not wrap it in a default format.
- `on-click` / `on-right-click`: shell commands. Do NOT wrap with `sh -c '...' &`.

### Toggle-style (exec + signal refresh)

```json
"custom/<name>": {
  "exec": "~/.config/waybar/scripts/<name>.sh refresh",
  "interval": 1000,
  "signal": 8,
  "on-click": "~/.config/waybar/scripts/<name>.sh",
  "format": "{}",
  "return-type": "json"
}
```

Critical: `interval: 1000` prevents Waybar's exec loop from stealing all clicks. The script must check `$1 != "refresh"` before emitting a signal.

### Grouped modules (side-by-side tiles)

```json
"group/<group-name>": {
  "orientation": "horizontal",
  "modules": ["custom/<name>-icon", "custom/<name>-info"]
}
```

Use groups when you want two visually related sub-modules in one box (e.g. icon tile + info tile).

## 3. Config Wiring

Add to the relevant bar's `modules-left`, `modules-center`, or `modules-right` array in `config`.

For rapid iteration, use a dev bar:

```json
{
  "name": "bar-horiz-dev",
  "layer": "top",
  "position": "top",
  "height": 17,
  "modules-left": ["group/<your-module>"],
  "modules-center": [],
  "modules-right": [],
  "include": ["~/.config/waybar/<modules-file>.json"]
}
```

Dev bar is scoped to one or two modules — faster feedback, no interference from production modules.

## 4. CSS

### Selector naming

Module `<prefix>/<name>` → CSS `#<prefix>-<name>`. Replace both `/` and `#` with `-`.

Examples:
- `custom/qwen-ssd-info` → `#custom-qwen-ssd-info`
- `group/qwen-network` → `#group-qwen-network`

### GTK CSS subset — what's NOT supported (gotchas)

The following are **invalid** in Waybar's GTK CSS. Using any of them causes a startup error:

```
❌ line-height: 1.1;
❌ text-align: center;
❌ min-width: auto;      (must be numeric px)
❌ any value of `auto` for sizing props
❌ font-style: italic;    (use Pango <i> instead)
```

### Nested-box pattern (single outer border, inner tile has its own border)

```css
/* Outer wrapper — the frame */
#group-<name> {
  background: rgba(20, 20, 28, 0.92);
  border: 1px solid rgba(<accent-r, g, b>, 0.4);
  border-radius: 8px;
  padding: 2px 4px 2px 6px;
  margin: 0 4px;
}

/* Icon tile — icon only, no border, sits inside the wrapper */
#custom-<name>-icon {
  font-size: 20px;
  min-width: 32px;
  border: none;
  background: transparent;
  border-radius: 0;
  color: <accent-color>;
}

/* Info tile — nested inner box */
#custom-<name>-info {
  font-size: 12px;
  padding: 2px 8px;
  border: 1px solid rgba(<accent-r, g, b>, 0.4);
  border-radius: 6px;
  background: rgba(30, 30, 42, 0.85);
  color: <accent-color>;
}
```

### Per-state colors

Append the class name to the selector:

```css
#custom-<name>-info.medium  { background: rgba(249, 226, 175, 0.15); border-color: rgba(249, 226, 175, 0.4); }
#custom-<name>-info.warning { background: rgba(250, 179, 135, 0.2);  border-color: rgba(250, 179, 135, 0.5); }
#custom-<name>-info.critical { background: rgba(243, 139, 168, 0.2); border-color: rgba(243, 139, 168, 0.5); }
```

State thresholds (typical): `good < 70%`, `medium 70-84%`, `warning 85-94%`, `critical ≥ 95%`. For temperature: `good < 60°C`, `medium 60-69°C`, `warning 70-79°C`, `critical ≥ 80°C`.

### Bar sizing reality

The bar's `height` property in config is a **floor**, not a ceiling. If any module has `min-height: 20px` or 2-line Pango text, the bar expands to fit.

To actually hit a small target height:
- Remove `min-height` from module CSS (or set to `0`)
- Reduce group padding to `0-2px`
- Single-line Pango text only

To measure actual rendered height, watch `waybar` stderr: `Bar configured (width: ..., height: ...) for output: ...`.

## Recommended Iteration Workflow

1. **Write the script** in `scripts/`. Test it standalone: `chmod +x && ./scripts/name.sh`
2. **Add to `qwen-modules.json`** (or `default-modules.json`). Validate: `jq .`
3. **Add CSS** to `style.css` (scoped to `#<module-id>`)
4. **Wire to `bar-horiz-dev`** in config for isolated iteration (don't touch production bar yet)
5. **Reload**: `pkill -SIGUSR2 waybar`
6. **Check stderr**: `grep '\[error\]' /tmp/waybar-startup.log | tail`
7. **Iterate on CSS** with SIGUSR2 reloads until the visual matches
8. **Commit**: `git add -A && git commit -m "..."`
9. **Once stable, move** the module definition into the production bar's config

## Common Data Sources

| What | Path | Format |
|---|---|---|
| CPU% | `/proc/stat` (aggregate line) | `cpu <vals...>` |
| RAM used/free | `/proc/meminfo` MemTotal, MemAvailable | `Name:    12345 kB` |
| WiFi status | `nmcli -t -f active,ssid,signal,device dev wifi` | `yes:SSID:80:wlan0` |
| Disk usage | `df --output=... /` | tabular |
| Block I/O | `/sys/block/<dev>/stat` | fields 3 (read sectors), 7 (write sectors) |
| SSD temperature | `/sys/block/<dev>/device/hwmon*/temp*_input` | millidegrees C |
| CPU temperature | `/sys/class/thermal/thermal_zone*/temp` | millidegrees C |
| Bluetooth status | `rfkill list bluetooth` + `bt-adapter --list` | text |

## Validation Commands

```bash
jq . config
jq . default-modules.json
jq . <group-modules>.json
bash -n scripts/<name>.sh
./scripts/<name>.sh                    # test output
pkill -SIGUSR2 waybar                  # reload (no restart needed)
pkill waybar; sleep 0.4; waybar &      # full restart (if reload doesn't pick up)
grep '\[error\]' /tmp/waybar-startup.log | tail
```
