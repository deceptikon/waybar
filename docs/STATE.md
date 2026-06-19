# STATE.md — Known issues & next moves

## Changelog

- **2026-06-20** — Tight pass: font 12→11, icon 14→11, info 115→108, all pad→2px, bar 170→150.
- **2026-06-20** — Font 13→12px, GPU/SSD bars 4→6 segments to align with text width.
- **2026-06-20** — Compact pass 2: split GPU onto 2 rows (bar+pct / MHz+temp), icon min-width 18→14, info min-width 110→115, padding 4→3, group 4→3, bar width 200→170. All info cards now uniform ~121px.
- **2026-06-20** — Unified info-card `min-width` to 110px (126px → 110px) + icon cards to 18px, reduced all padding by 2px each side, group padding 6px→4px, bar width 250→200. Icons now align with info columns.
- **2026-06-20** — Unified info-card `min-width` to 126px (was 80px) + added network card match, so all monitor group columns have the same width.
- **2026-06-20** — Removed 3-space indent before CPU bar2 row so both 8-core bars left-align.

## Known issues

- **`text-align: left` in GTK CSS breaks Waybar** — GTK's CSS subset doesn't accept `text-align`; using it causes Waybar to exit with code 1. Never add it to any CSS rule.
- **Temp module always `warning`** — CPU idles at ~64°C, threshold is 60°C. Always orange. User deferred ("do nothing for now").
- **SSD read/write** — cumulative sectors, not live throughput (no delta between poller ticks). Disks module shows total I/O, not rate.
- **Net module** — not wired to current bar config (6 groups only). `net_rx/tx_bytes` in cache but unused.
- **Fan RPM on ASUS** — uses `temp.fan1` which may reflect CPU fan, not chassis fan. Verify the hwmon path.
- **No validation** — scripts have no unit tests; `bash -n` only catches syntax errors.
- **verify-setup.sh** — uses `path=~/.config/waybar/scripts/$script` (dynamic). Works but assumes scripts live flat under `scripts/`.

## Next moves

1. **Sway config audit** — grep `~/.config/waybar/scripts` in `~/.config/sway/config` for any stale paths.
2. **GPU freq source** — currently reads `sclk.freq1_input / 1000000` from sensors. Verify it shows MHz correctly under load.
3. **Temp thresholds** — tune `good/warning/critical` values once ready (currently 60/85°C).
4. **Cache TTL** — poller writes every 2s; modules use `interval: 2`. If poller dies, modules show stale data for up to 2s before `[ ! -s "$CACHE" ]` kicks in.
5. **Push branches** — `reliable` is ahead of `origin/reliable` by multiple commits; `cache-poller-icon-card` and `pango-boxes` are local only.
