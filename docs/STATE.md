# Known Issues & Next Moves

**Updated:** 2026-07-07

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
- **power-profiles-daemon DBus error** — benign. PPD not installed on this system; `asusctl` is used instead. Power mode switch is deferred (`asusd` issue).
- **toggle-vert-lite** — SIGUSR1 signal does nothing in waybar by default. Toggle script likely non-functional.

## Fixed (for the record)

- ~~**`custom/checkupdates` not displaying**~~ — Fixed by removing `set -euo pipefail` from `checkupdates.sh`. `yay -Qu` returns non-zero when no updates.
- ~~**`ext-display.sh` JSON parse error**~~ — Fixed by redirecting `command -v` to `>/dev/null` so it doesn't bleed into stdout JSON.
- ~~**autobacklight not working**~~ — Fixed by reverting botched regex in `toggler.sh` and `keywatcher.sh`.
- ~~**Scripts not executable after chezmoi deploy**~~ — Fixed by renaming all scripts with the `executable_` prefix so chezmoi auto-sets `chmod +x`.

## Next Moves (Priority Order)

1. **Fix toggle-vert-lite** — SIGUSR1 signal does nothing in waybar by default. Consider switching to full restart with visibility flag.
2. **Verify VL icons in compact** — Check if sysmon icons render when data cards return `{}` in compact mode.
3. **Test animations** — Once toggle works, verify smooth transitions between full/lite bars.
4. **asusd power mode switch** — Deferred. Needs `asusd` investigation.
