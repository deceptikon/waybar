# sysmon Pipeline — Data Flow

```
┌─────────────────────────────────────────────────────┐
│                  sysmon-poller.sh                    │
│  (background loop, started once at session start)   │
│                                                      │
│  while true; do                                      │
│    sysmon-collect.sh | sysmon-mapper.sh > /tmp/sysmon.json
│    sleep 2                                           │
│  done                                                │
└──────────────────────┬──────────────────────────────┘
                       │ writes every 2s
                       ▼
              ┌────────────────┐
              │ /tmp/sysmon.json│
              │  (JSON tree)    │
              └────────┬───────┘
                       │ read by 6 Waybar modules
          ┌────────────┼───────┬───────┬───────┬───────┬───────┐
          ▼            ▼       ▼       ▼       ▼       ▼       ▼
    sysmon-frame.sh  gpu     cpu     ram     ssd     temp    asus
    (reads cache,     │       │       │       │       │       │
     formats one      ▼       ▼       ▼       ▼       ▼       ▼
     metric via   Waybar  Waybar  Waybar  Waybar  Waybar  Waybar
     draw_module)  JSON    JSON    JSON    JSON    JSON    JSON
```

## Components

| File | Role |
|---|---|
| `scripts/sysmon-poller.sh` | Background loop: run collect+mapper every 2s → `/tmp/sysmon.json` |
| `scripts/sysmon-collect.sh` | Collector: reads `/proc/*` + sysfs + `sensors -j`, outputs labeled sections |
| `scripts/sysmon-mapper.sh` | Parser: reads labeled raw sections, emits unified JSON tree |
| `scripts/sysmon-frame.sh` | Formatter: reads `/tmp/sysmon.json`, formats one metric, outputs Waybar JSON |
| `scripts/lib/draw-module.sh` | Library: `draw_module` renders Pango unicode box with icon + 2 data rows |

## Startup

The poller must run before Waybar modules start. In sway config:

```
exec_always ~/.config/waybar/scripts/sysmon-poller.sh
```

This goes in `~/.config/sway/config` alongside the waybar start command.

## JSON Schema (what /tmp/sysmon.json contains)

```json
{
  "ts": 1718000000,
  "cpu":    { "avg": 12, "per_core": [12,3,16,...] },
  "ram":    { "used_kb": 25371204, "total_kb": 31940168, "used_pct": 79, "swap_used_kb": 1979732, "swap_total_kb": 33554428 },
  "disk":   { "read_sectors": 49513460, "write_sectors": 5475401 },
  "net":    { "rx_bytes": 557506264, "tx_bytes": 63097053 },
  "gpu":    { "busy_pct": 9, "mem_used": 496103424, "mem_total": 536870912, "temp_c": 48, "freq": 679, "power_w": 5.001 },
  "temp":   { "cpu_c": 50.125, "fan1": 2300, "fan2": 0 },
  "asus":   { "profile": "Quiet" }
}
```

## Config Structure

- `config-vertical` → `modules-left`: 6 metric groups + network group
- `modules-monitor-group.json` → each group wraps one `custom/qwen-*` module
- Each `custom/qwen-*` has `exec: "sysmon-frame.sh <metric>"`
- `style-new.css` → per-group border colors (peach/green/blue/red/teal)
- `config-top`, `config-bottom` → horizontal bars (unrelated)
