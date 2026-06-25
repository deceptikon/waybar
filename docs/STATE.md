# Known Issues & Next Moves

**Updated:** 2026-06-26

## Known Issues

- **`text-align` in GTK CSS breaks Waybar** — GTK's CSS subset doesn't accept `text-align`; using it causes Waybar to exit with code 1. Never add it to any CSS rule.
- **Temp module always `warning`** — CPU idles at ~64°C, threshold is 60°C. Always orange.
- **SSD read/write** — cumulative sectors, not live throughput (no delta between poller ticks). Shows total I/O, not rate.
- **Net module** — not wired to current bar config. `net_rx/tx_bytes` in cache but unused.
- **Fan RPM on ASUS** — uses `temp.fan1` which may reflect CPU fan, not chassis fan.
- **No validation** — scripts have no tests; `bash -n` only catches syntax errors.
- **GPU freq source** — currently reads `sclk.freq1_input / 1000000` from sensors. Verify MHz under load.
- **Cache TTL** — poller writes every 2s; modules use `interval: 2`. If poller dies, modules show stale data up to 2s.
- **Temp thresholds** — `good/warning/critical` currently at 60/85°C. May need tuning.
- **power-profiles-daemon DBus error** — benign. PPD not installed on this system; `asusctl` is used instead.

## Next Moves (Priority Order)

1. **Fix toggle-vert-lite** — SIGUSR1 signal does nothing in waybar by default. Toggle script likely non-functional.
2. **Verify VL icons in compact** — Check if sysmon icons render when data cards return `{}` in compact mode.
3. **Test animations** — Once toggle works, verify smooth transitions between full/lite bars.
4. **Stop pushing branches** — `reliable` is ahead of `origin/reliable` by multiple commits.
