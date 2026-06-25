# sysmon Pipeline — Data Flow

```
poller.sh (background daemon, wakes every 2s)
  │
  ├─ collect.sh  (reads /proc/* + /sys/* + sensors -j — labeled lines)
  │   │ pipe
  │   ▼
  ├─ mapper.sh   (parses labeled sections → unified JSON → stdout)
  │   │
  │   ├──(tee)──→ /tmp/sysmon.json (atomic write once per cycle)
  │   │
  │   ▼
  └─ formatter.sh  (reads /tmp/sysmon.json → writes per-metric feeds/)
```

```
/tmp/sysmon.json ← written atomically every 2s by poller (write tmp + mv)

  ├─ sysmon/formatter.sh       ← reads /tmp/sysmon.json, writes to feeds/<metric>.json
  │                              (consumed by 6 waybar modules via tail -F)
  │
  └─ sysmon/compact-*.py       ← reads /tmp/sysmon.json directly
                                   (consumed by vertical-lite bar modules)
```

## Components

| File | Role |
|---|---|
| `sysmon/poller.sh` | Background loop: collect + mapper every 2s → `/tmp/sysmon.json` |
| `sysmon/collect.sh` | Collector: reads `/proc/*` + sysfs + `sensors -j`, outputs labeled sections |
| `sysmon/mapper.sh` | Parser: reads labeled raw sections, emits unified JSON tree |
| `sysmon/formatter.sh` | Formatter: reads `/tmp/sysmon.json` (stdin), writes all per-metric feeds atomically |
| `sysmon/icon.sh` | One-liner per metric, outputs Waybar JSON with just the icon glyph |
| `sysmon/compact-{gpu,cpu,ram,ssd}.py` | Python compact formatters for vertical-lite bar |

## Sources

| Data | Read by | JSON key |
|---|---|---|
| `/proc/stat` (two snaps, 0.3s delta) | collect.sh | `cpu.avg`, `cpu.per_core[]` |
| `/proc/meminfo` | collect.sh | `ram.*` |
| `/sys/class/drm/card*/device/gpu_busy_percent` | collect.sh | `gpu.busy_pct` |
| `/sys/class/drm/card*/device/mem_info_vram_*` | collect.sh | `gpu.mem_used`, `gpu.mem_total` |
| `/sys/class/powercap/intel-rapl:0/power_now` | collect.sh | `gpu.power_w` |
| `sensors -j` | collect.sh | `gpu.temp_c`, `temp.*` |
| `/sys/block/nvme0n1/stat` | collect.sh | `disk.*` |
| `/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy` | collect.sh | `asus.profile` |
| `df /` | frame.sh (live) | N/A |

## JSON Schema

```json
{
  "ts": 1718000000,
  "cpu":    { "avg": 12, "per_core": [12,3,16,...] },
  "ram":    { "used_kb": 25371204, "total_kb": 31940168, "avail_kb": 6568964, "used_pct": 79, "swap_used_kb": 1979732, "swap_total_kb": 33554428, "swap_pct": 5 },
  "disk":   { "read_sectors": 49513460, "write_sectors": 5475401 },
  "net":    { "rx_bytes": 557506264, "tx_bytes": 63097053 },
  "gpu":    { "busy_pct": 9, "mem_used": 496103424, "mem_total": 536870912, "temp_c": 48, "freq": 679, "power_w": 5.001 },
  "temp":   { "cpu_c": 50.125, "fan1": 2300, "fan2": 0 },
  "asus":   { "profile": "Quiet" }
}
```

## Bar-Specific Consumers

| Bar | Modules | Source |
|---|---|---|
| Vertical (full) | `group/qwen-{gpu,cpu,ram,ssd,asus,network}` | `tail -F feeds/<metric>.json` |
| Vertical-lite | `custom/compact-{gpu,cpu,ram,ssd}` | `compact-*.py` reads `/tmp/sysmon.json` |
| Top | `group/qwen-{cpu,ram,ssd,network}` (in `group/top-center`) | `tail -F feeds/<metric>.json` |
