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
5. **Reload**: `scripts/waybar-start.sh reload`
6. **Check stderr**: `grep '\[error\]' /tmp/waybar-startup.log | tail`
7. **Iterate on CSS** with reloads until the visual matches
8. **Commit**: `git add -A && git commit -m "..."`
9. **Once stable, move** the module definition into the production bar's config

## Common Data Sources

| What | Path | Format |
|---|---|---|
| CPU% | `/proc/stat` (aggregate line `cpu` OR per-core lines `cpu0..cpuN`) | `cpu <vals...>` |
| RAM used/free | `/proc/meminfo` MemTotal, MemAvailable | `Name:    12345 kB` |
| Swap used/free | `/proc/meminfo` SwapTotal, SwapFree | `Name:    12345 kB` |
| WiFi status | `nmcli -t -f active,ssid,signal,device dev wifi` | `yes:SSID:80:wlan0` |
| Disk usage | `df --output=... /` | tabular |
| Block I/O | `/sys/block/<dev>/stat` | fields 3 (read sectors), 7 (write sectors) |
| SSD temperature | `/sys/block/<dev>/device/hwmon*/temp*_input` | millidegrees C |
| CPU temperature | `/sys/class/thermal/thermal_zone*/temp` | millidegrees C |
| Bluetooth status | `rfkill list bluetooth` + `bt-adapter --list` | text |

## 5. Advanced Patterns

### Per-core CPU grid (awk-heavy, 2-file snapshot)

When you need **per-core** utilization, the cleanest approach is to write two snapshots to temp files, then let awk do all the math and Pango formatting. Avoids bash associative-array quoting issues and keeps the END block declarative.

```bash
#!/bin/bash
# CPU info — per-core 4×4 grid of colored pct% cells, plus overall avg + temp.

read_samples() {
  awk '/^cpu[0-9]/ {tot=$2+$3+$4+$5+$6+$7+$8; idle=$5; printf "%s %d %d\n", $1, tot, idle}' /proc/stat
}
read_samples > /tmp/qb_r1
sleep 0.5
read_samples > /tmp/qb_r2

awk '
FNR==NR { tot1[$1]=$2; idle1[$1]=$3; next }
{
  n=$1; dt=$2-tot1[n]; di=$3-idle1[n];
  if (dt<=0) dt=1;
  pct=int((dt-di)*100/dt);
  if (pct<0) pct=0; if (pct>100) pct=100;
  loads[n]=pct; sum+=pct; cnt++;
}
END {
  avg=int(sum/cnt)
  printf "%d\n", avg
  rows=4; cols=4; sep="";
  for (r=0; r<rows; r++) {
    for (c=0; c<cols; c++) {
      i=r*cols+c; name="cpu"i;
      if (!(name in loads)) { if (c>0) printf "  "; continue }
      pct=loads[name];
      if      (pct<20)  col="#45475a";   # idle
      else if (pct<25)  col="#a6e3a1";   # low
      else if (pct<40)  col="#89b4fa";   # low-med
      else if (pct<70)  col="#b4befe";   # med
      else if (pct<90)  col="#f9e2af";   # high
      else              col="#f38ba8";   # critical
      printf "%s<span fgcolor=%s><span size=xx-small>%d:%d%%</span></span>", sep, col, i, pct;
      sep="  ";
    }
    sep="";
    printf "\n";
  }
}
' /tmp/qb_r1 /tmp/qb_r2 > /tmp/qb_grid

overall=$(head -1 /tmp/qb_grid)
row1=$(sed -n '2p' /tmp/qb_grid); row2=$(sed -n '3p' /tmp/qb_grid)
row3=$(sed -n '4p' /tmp/qb_grid); row4=$(sed -n '5p' /tmp/qb_grid)
text="$overall  61°C\n$row1\n$row2\n$row3\n$row4"
jq -n --compact-output --arg text "$text" --arg cls "info" '{text:$text,class:$cls}'
```

**Why awk over bash here?** awk does the integer math in one pass with no quoting/IFS headaches. Each row prints directly as valid Pango markup — no bash `for ((...))` loops, no string concatenation errors. The two-file snapshot is also faster than keeping everything in a single pipeline because the awk END block can look up both lines by name without buffering.

### RAM + swap from /proc/meminfo

`/proc/meminfo` is one line per key — parse it with a single awk that emits labeled values, then load them into a bash associative array with `declare -A`.

```bash
read_meminfo() {
  awk '
    /^MemTotal:/     {printf "mt %d\n", $2}
    /^MemAvailable:/ {printf "ma %d\n", $2}
    /^SwapTotal:/    {printf "st %d\n", $2}
    /^SwapFree:/     {printf "sf %d\n", $2}
  ' /proc/meminfo
}
declare -A m
while read key val; do m[$key]=$val; done < <(read_meminfo)

mt=${m[mt]}; ma=${m[ma]}
st=${m[st]:-0}; sf=${m[sf]:-0}       # swap keys may be absent
mem_used=$((mt - ma))
mem_pct=$((mem_used * 100 / mt))
swap_used=$((st - sf))
swap_pct=0; [ "$st" -gt 0 ] && swap_pct=$((swap_used * 100 / st))
to_gib() { awk "BEGIN{printf \"%.1f\", $1/1024/1024}"; }
```

The `${m[st]:-0}` default is critical — machines without swap have no `SwapTotal` line at all, and `${m[st]}` unset + `set -u` would blow up.

### Color tier mapping in awk

Don't branch in bash for every cell — put the color tiers directly in awk's END block as inline `if/else if/else`. Keeps the output formatting co-located with the data.

```awk
      pct=loads[name];
      if      (pct<20)  col="#45475a";
      else if (pct<25)  col="#a6e3a1";
      else if (pct<40)  col="#89b4fa";
      else if (pct<70)  col="#b4befe";
      else if (pct<90)  col="#f9e2af";
      else              col="#f38ba8";
      printf "%s<span fgcolor=%s><span size=xx-small>%d:%d%%</span></span>", sep, col, i, pct;
```

The `sep` variable pattern avoids a trailing separator: first cell prints `""`, subsequent cells prepend `"  "`.

### Multi-row modules and height

Each `\n` in the `text` field creates a separate Pango line, which adds ~font-height + padding to the rendered module. The bar's `height` in config is a **floor** — the rendered bar grows to fit the tallest module.

A 2-row module (like RAM with bar + usage+swap) pushes a 17px bar to ~33px.

Pango `<span size='xx-small'>` keeps text visually smaller **without** reducing the line's baseline, so it doesn't actually save vertical height — it just changes font size. For height reduction, use fewer rows or shrink group padding.

### `xx-small` in Pango

Use `<span size=xx-small>` to shrink individual cells (like grid labels) while keeping the parent container font at a readable size. Without a unit, Pango size is a multiple of the default font — `size=xx-small` is a known-size alias in PANGO_SIZE_XX_SMALL.

### /tmp snapshot vs process substitution

Two approaches for 2-sample live data:

**Process substitution** (cleaner for simple aggregates):
```bash
sample() { awk '...' /proc/stat; }
read t1 i1 < <(sample); sleep 0.5; read t2 i2 < <(sample)
```

**Temp file** (cleaner for per-core, awk-heavy):
```bash
read_samples > /tmp/qb_r1
sleep 0.5
read_samples > /tmp/qb_r2
awk '...' /tmp/qb_r1 /tmp/qb_r2
```

The temp file wins when you need to sort cores, or when awk needs the full data at once in the END block. Process substitution wins when you just need aggregate stats — less I/O overhead and nothing to clean up.

### "Worst-of" class computation

For modules that aggregate multiple metrics (cpu + ram + temp, or mem + swap), compute the class by assigning numeric ranks:

```bash
rank() { case "$1" in 0)echo 0;; 1)echo 1;; 2)echo 2;; 3)echo 3;; esac; }
unrank() { case "$1" in 0)echo good;; 1)echo medium;; 2)echo warning;; 3)echo critical;; esac; }

r_cpu=$(rank "$cpu_cls"); r_mem=$(rank "$mem_cls"); r_tmp=$(rank "$temp_cls")
maxr=$r_cpu; [ "$r_mem" -gt "$maxr" ] && maxr=$r_mem; [ "$r_tmp" -gt "$maxr" ] && maxr=$r_tmp
overall=$(unrank $maxr)
```

This avoids fragile string comparisons (`warning > medium` in bash needs `[[ ... ]]`).

## Validation Commands

```bash
jq . config
jq . default-modules.json
jq . <group-modules>.json
bash -n scripts/<name>.sh
./scripts/<name>.sh                    # test output
scripts/waybar-start.sh reload         # full restart (SIGUSR2 unreliable on multi-bar)
grep '\[error\]' /tmp/waybar-startup.log | tail
```
