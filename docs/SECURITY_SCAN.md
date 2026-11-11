# Security Scan & Refactoring Notes

> Scope: Waybar configuration repo (`/home/dev/work/waybar`).  
> Method: manual review of shell scripts, JSON/JSONC configs, and CSS. No dynamic testing was performed.
>
> **Status:** the `/tmp` log/state findings, the `eval` of `jq` output, the duplicated
> `health()` function, and the broken `netfan.sh` feed path were fixed in
> `refactor/cleanup-modules`. All logs now go to `<waybar-root>/logs/`; mutable
> state lives under `XDG_STATE_HOME` / `XDG_RUNTIME_DIR`. The text below is kept as
> the original audit record; remaining items are still tracked in §3.

---

## 1. Executive Summary

The project is a personal Waybar configuration, so the threat model is mostly **local privilege escalation / accidental self-harm** rather than remote exploitation. The biggest recurring issues are:

1. Heavy use of predictable world-writable `/tmp` files (symlink-attack surface).
2. `eval` of `jq` output in a few data-pipeline scripts.
3. Inconsistent hardening (`set -euo pipefail`, quoting, full paths).
4. Inline shell snippets embedded in JSON configs.
5. A handful of stale references and one likely syntax/duplication bug.

None of these are “remote root” vulnerabilities, but they are easy to clean up and would make the config safer and more maintainable.

---

## 2. Security Findings

### 2.1 Predictable world-writable `/tmp` files — **High priority**

Many scripts write diagnostics and state to `/tmp` with fixed names:

- `/tmp/waybar_errors.log` — **46 occurrences** across `collect.sh`, `ddc.sh`, `vpn.sh`, `dunst.sh`, `bt-indicator.sh`, `wifi-info.sh`, `llama-server.sh`, `keylight/*.sh`, `netfan.sh`, `profile-indicator.sh`, `wifi-toggle.sh`, `verify-setup.sh`.
- `/tmp/recording_temp.mkv`, `/tmp/capturer.log` in `capturer.sh`.
- `/tmp/keywatcher.pid`, `/tmp/keywatcher_checker.pid`, `/tmp/kbd_last_action` in `keylight/*.sh`.
- `/tmp/waybar-vert-swap` in `toggle-vert-lite.sh`.
- `/tmp/llama_health_lastlog` in `llama-server.sh`.
- `/tmp/waybar_vpn_state` in `wg-vpn.sh`.

**Risk:** On a multi-user or compromised host, an attacker can pre-create symlinks at these paths and redirect writes to arbitrary files (log-poisoning, truncation, disk exhaustion). Even on a single-user laptop, this is unnecessary attack surface.

**Fix:** Move all mutable state under the user’s `XDG_STATE_HOME` or `XDG_RUNTIME_DIR`, or use `mktemp` for transient files.

```bash
# suggested default
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-$STATE_DIR}/run"
mkdir -p "$STATE_DIR" "$RUNTIME_DIR"
ERRLOG="$STATE_DIR/errors.log"
```

---

### 2.2 `eval` of `jq` output — **High priority**

Three scripts `eval` strings produced by `jq`:

- `scripts/sysmon/formatter.sh:60`
- `scripts/sysmon/mapper.sh:3`
- `scripts/utils/netfan.sh:3`

The input is local JSON, but if any feed file is ever symlinked, corrupted, or attacker-controlled, this becomes arbitrary shell code execution.

**Fix:** Never `eval` jq output. Use `--arg` / `--argjson` to bind values safely, or read individual fields with `jq -r '.field'` and quote them.

Example refactor for `netfan.sh`:

```bash
read -r rx tx fan <<< "$(jq -r '[.net.rx_speed // 0, .net.tx_speed // 0, .temp.fan1 // 0] | @tsv' <<< "$data")"
```

---

### 2.3 Missing / inconsistent shell hardening — **Medium priority**

Several scripts lack `set -euo pipefail`:

- `scripts/utils/wifi-toggle.sh`
- `scripts/utils/bt-toggle.sh`
- `scripts/utils/bt-indicator.sh`
- `scripts/utils/shutdown-dmenu.sh`
- `scripts/utils/keylight/kbd_status_json.sh`
- `scripts/utils/keylight/keywatcher.sh`
- `scripts/utils/keylight/toggler.sh`
- `scripts/utils/lang-monitor.sh`
- `scripts/utils/profile-indicator.sh`

Some also use unquoted variables (`cat $KBD_LED`, `kill $(cat $PID_FILE)`, etc.) or rely on the inherited `PATH` for privileged commands (`sudo`, `pkill`, `rfkill`).

**Fix:** Standardize every script with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

and quote all variable expansions. For privileged commands, prefer full paths where practical (e.g. `/usr/bin/sudo`, `/usr/bin/rfkill`).

---

### 2.4 Hardcoded user-specific path — **Medium priority**

`scripts/utils/wg-vpn.sh` hardcodes:

```bash
CONFIG_PATH="/home/alex/.vpn.conf"
```

This breaks on any other user account and leaks a username if the repo is published.

**Fix:** Use a configurable variable with a `$HOME` default:

```bash
VPN_CONF="${VPN_CONF:-$HOME/.vpn.conf}"
```

---

### 2.5 Privileged commands without terminal / polkit — **Medium priority**

- `shutdown-dmenu.sh` runs `sudo shutdown -r now &` and `sudo shutdown -h now &` in the background. If `sudo` requires a password, the command hangs or fails silently because there is no terminal.
- `vpn.sh` runs `sudo kvpnc start/stop` directly from a Waybar click, again with no terminal.

**Fix:** Either:

- configure passwordless `sudo` for these specific commands (document the rules), or
- open a terminal/polkit dialog for authentication, as the commented-out `wg-vpn.sh` logic attempted to do.

---

### 2.6 Process killing with broad patterns — **Medium priority**

Many scripts use `pkill -f <pattern>` or `pkill -x waybar`:

- `waybar-start.sh`: `pkill -x waybar`
- `keylight/toggler.sh`: `pkill -f "keylight/keywatcher.sh"`, `pkill -f "evtest.*platform-i8042"`
- `ext-display.sh`, `wifi-*.sh`, `dunst.sh`, etc.: `pkill -SIGRTMIN+N waybar`

`pkill -f` matches any substring of any process command line; a malicious or unusually named process could be hit. `pkill -x waybar` is safer but still kills *all* waybar instances.

**Fix:** Track PIDs explicitly (the poller already does this) and send signals only to known processes.

---

### 2.7 Inline shell in JSON configs — **Medium priority**

Several modules embed complex shell directly in JSON:

- `custom/lang` in `config-top-base.jsonc`
- `custom/recorder`, `custom/ollama`, `custom/powerbtn` in `modules-vc.json`
- `custom/checkupdates` `on-click` in `config-vertical-base.jsonc`

This makes the configs hard to read, impossible to lint with `shellcheck`, and harder to audit. If any interpolated value later comes from user input, it becomes command injection.

**Fix:** Move each snippet into a small script under `scripts/modules/` and reference it from the config.

---

### 2.8 Stale / mismatched feed path — **Low priority**

`scripts/utils/netfan.sh` reads:

```bash
data=$(cat /tmp/sysmon.json ...)
```

but the sysmon pipeline writes to:

```bash
~/.config/waybar/feeds/sysmon.json
```

So `netfan.sh` is reading a stale or non-existent file. This is a correctness bug, not a security bug, but it shares the same root cause as the `/tmp` abuse.

---

### 2.9 Duplicate function definition — **Low priority (bug)**

`scripts/utils/llama-server.sh` defines `health()` twice (lines 9 and 35). Bash silently uses the second definition. The duplicate is likely a copy-paste artifact and should be removed.

---

### 2.10 Invalid JSON / trailing commas — **Low priority**

`config-bottom` contains a trailing comma in `persistent-workspaces`:

```json
"2": ["HDMI-A-1"],
```

Waybar uses JSONC and may tolerate it, but it is invalid strict JSON and can break validators or other tools.

---

### 2.11 Input validation gaps — **Low priority**

- `ddc.sh` accepts `combo set N` but does not verify `N` is numeric before arithmetic.
- Several scripts parse `iwgetid`, `bt-adapter`, `nmcli` output without sanitizing it before passing to `jq --arg`. `jq --arg` is safe, but downstream `printf` format strings in `draw-module.sh` could misbehave if text contains `%`.

---

## 3. Refactoring Roadmap

### 3.1 Immediate (high value, low effort)

| Task | Files / Areas |
|------|---------------|
| Replace `/tmp/waybar_errors.log` with `XDG_STATE_HOME/waybar/errors.log` | All `*.sh` scripts |
| Replace predictable `/tmp/*` PID/state files with `XDG_RUNTIME_DIR` or `XDG_STATE_HOME` | `keylight/*.sh`, `toggle-vert-lite.sh`, `capturer.sh`, `wg-vpn.sh`, `llama-server.sh` |
| Remove `eval` of jq output | `formatter.sh`, `mapper.sh`, `netfan.sh` |
| Fix hardcoded `/home/alex/.vpn.conf` | `wg-vpn.sh` |
| Add `set -euo pipefail` to all scripts | Scripts listed in §2.3 |
| Quote all variable expansions | Entire `scripts/` tree |
| Fix duplicate `health()` function | `llama-server.sh` |
| Fix invalid trailing comma in JSON | `config-bottom` |
| Fix `netfan.sh` reading `/tmp/sysmon.json` instead of feeds dir | `netfan.sh` |

### 3.2 Short-term (structure / maintainability)

1. **Create a shared library**  
   Add `scripts/lib/common.sh` with helpers:
   - `waybar_home()`, `state_dir()`, `runtime_dir()`
   - `log_error()` that writes to `$STATE_DIR/errors.log`
   - `require_cmd()` for dependency checks
   - `signal_waybar()` that uses a PID file instead of `pkill -f`
   - `mktemp_safe()` wrapper

2. **Centralize user-specific constants**  
   Move values like `SYSMON_NET_IF`, `SYSMON_DISK_DEV`, `VPN_CONF`, `OUTPUT` (HDMI-A-1) into `sysmon.env` or a new `waybar.env` so the same scripts work on multiple machines without edits.

3. **Move inline shell out of JSON**  
   Convert inline `exec` / `on-click` strings in `modules-vc.json` and `config-top-base.jsonc` into small wrapper scripts under `scripts/modules/`.

4. **Standardize log rotation**  
   Replace the ad-hoc `tail -n 50 … > … .tmp && mv` in `waybar-start.sh` with `logrotate` or a small rotate function.

5. **Use full paths or sanitize PATH**  
   At the top of each script:
   ```bash
   PATH="/usr/local/bin:/usr/bin:/bin"
   ```
   and call tools by full path where security-relevant (`sudo`, `rfkill`, `pkill`, `kill`).

### 3.3 Long-term (architecture)

1. **PID manager for all background services**  
   The poller already tracks its PID. Extend this pattern to `keywatcher`, `llama-server`, and `wf-recorder` so cleanup and signaling are exact.

2. **Feed directory as a single source of truth**  
   All modules should read from `$WAYBAR_HOME/feeds/`; remove reads from `/tmp/sysmon.json` and `/tmp/llama_curl.log`.

3. **Declarative module map**  
   Consider generating `modules-*.json` from a small YAML/TOML source to reduce duplication between full and compact sysmon modules.

4. **Add linting / CI**  
   - Run `shellcheck` on all scripts.
   - Validate JSON/JSONC with `python -m json.tool` or `jsonc` parser.
   - Add a pre-commit hook to prevent new `/tmp` paths or `eval` of jq output.

5. **Documentation of required permissions**  
   Document the udev/sudo/polkit rules needed for DDC/CI, `rfkill`, `/sys/class/leds`, and `kvpnc`/`wg-quick`/`shutdown`.

---

## 4. Quick Wins Checklist

- [ ] `sed -i 's|/tmp/waybar_errors.log|${XDG_STATE_HOME:-$HOME/.local/state}/waybar/errors.log|g'` + create the directory.
- [ ] `sed -i 's|/tmp/sysmon.json|$WAYBAR_HOME/feeds/sysmon.json|g'` in `netfan.sh`.
- [ ] Replace the two `health()` blocks in `llama-server.sh` with one.
- [ ] Remove the trailing comma in `config-bottom`.
- [ ] Add `set -euo pipefail` to scripts missing it.
- [ ] Quote `cat $KBD_LED`, `kill $(cat $PID_FILE)`, etc.
- [ ] Change `CONFIG_PATH="/home/alex/.vpn.conf"` to use `$HOME`.
- [ ] Replace `eval "$(jq ... )"` with `read`/`jq --arg` patterns.

---

## 5. Files Requiring Attention

| File | Main Issues |
|------|-------------|
| `scripts/utils/wg-vpn.sh` | Hardcoded `/home/alex/.vpn.conf`; commented-out logic is stale |
| `scripts/utils/shutdown-dmenu.sh` | `sudo shutdown` without terminal; missing `set -euo pipefail` |
| `scripts/utils/vpn.sh` | `sudo kvpnc` without terminal; writes to `/tmp/waybar_errors.log` |
| `scripts/utils/capturer.sh` | Predictable `/tmp/recording_temp.mkv` and `/tmp/capturer.log` |
| `scripts/utils/keylight/*.sh` | Predictable `/tmp` PID/state files; unquoted variables |
| `scripts/utils/netfan.sh` | `eval` of jq output; reads `/tmp/sysmon.json` |
| `scripts/utils/llama-server.sh` | Duplicate `health()`; `/tmp` stamp/log files |
| `scripts/sysmon/formatter.sh` | `eval` of jq output |
| `scripts/sysmon/mapper.sh` | `eval` of jq output |
| `scripts/utils/ddc.sh` | `/tmp/waybar_errors.log`; input validation gaps |
| `config-bottom` | Invalid trailing comma |
| `modules-vc.json` | Inline shell, complex `on-click` strings |
| `config-top-base.jsonc` | Inline shell in `custom/lang` |

---

*Scan completed.*

---

## 6. Mini-Shell Consolidation Opportunities

A separate scan was done for places where many small shell invocations can be replaced by a single common helper. The biggest wins are listed below.

### 6.1 The big four shared helpers

These four patterns appear so often that adding one shared `scripts/lib/common.sh` would remove a lot of duplication and improve security at the same time.

| Pattern | Count | Current shape | Proposed common helper |
|---------|-------|---------------|------------------------|
| Error logging to `/tmp/waybar_errors.log` | 42+ redirects, 11 `"Command failed"` echos | `2>>/tmp/waybar_errors.log` / `echo "..." >>/tmp/waybar_errors.log` | `log_error [TAG] [MESSAGE]` |
| Signalling Waybar to redraw | 21 calls | `pkill -SIGRTMIN+N waybar \|\| echo "Command failed..." >>/tmp/waybar_errors.log` | `signal_waybar <N>` |
| Emitting `{text, class}` JSON | 8+ in shell, many inline in JSON | `jq -nc --arg text ... --arg cls ... '{text:$text, class:$cls}'` | `emit_json <text> <class> [tooltip]` |
| Tailing a feed file | 10 modules | `tail -F ~/.config/waybar/feeds/<name>.json` | `tail-feed.sh <name>` |

A minimal `scripts/lib/common.sh` could look like:

```bash
#!/usr/bin/env bash
set -euo pipefail

WAYBAR_HOME="${WAYBAR_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/waybar}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-$STATE_DIR/run}"
ERRLOG="$STATE_DIR/errors.log"

mkdir -p "$STATE_DIR" "$RUNTIME_DIR"

log_error() {
  local tag="${1:-waybar}"
  shift || true
  printf '%s %s: %s\n' "$(date -Iseconds)" "$tag" "$*" >>"$ERRLOG"
}

signal_waybar() {
  local sig="${1:-SIGRTMIN+8}"
  if ! pkill -"$sig" waybar; then
    log_error "signal" "pkill $sig failed"
  fi
}

emit_json() {
  local text="$1" class="$2" tooltip="${3:-}"
  if [[ -n "$tooltip" ]]; then
    jq -nc --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
      '{text:$text, class:$class, tooltip:$tooltip}'
  else
    jq -nc --arg text "$text" --arg class "$class" '{text:$text, class:$class}'
  fi
}
```

Scripts would source it:

```bash
source "${WAYBAR_HOME}/scripts/lib/common.sh"
```

### 6.2 Repeated feed-tail modules

`modules-sysmon.json` contains 10 almost identical entries:

```json
"custom/qwen-gpu":   { "exec": "tail -F ~/.config/waybar/feeds/gpu.json", ... },
"custom/qwen-cpu":   { "exec": "tail -F ~/.config/waybar/feeds/cpu.json", ... },
"custom/compact-gpu": { "exec": "tail -F ~/.config/waybar/feeds/compact-gpu.json", ... },
...
```

**Consolidation options:**

1. **Common wrapper script** — replace each `exec` with:
   ```json
   "exec": "~/.config/waybar/scripts/modules/tail-feed.sh gpu"
   ```
   The wrapper simply validates the feed name and runs `tail -F "$WAYBAR_HOME/feeds/$1.json"`.

2. **Generate the JSON** — keep a small list of resources and generate both the icon and the tail modules from a template. This also removes the duplicated `group/qwen-*` and `group/compact-*` definitions.

### 6.3 Repeated group definitions

The pattern:

```json
"custom/qwen-gpu-icon": { "format": " 󰢮 " },
"group/qwen-gpu": {
  "orientation": "horizontal",
  "modules": ["custom/qwen-gpu-icon", "custom/qwen-gpu"]
},
"custom/qwen-gpu": { ... "exec": "tail -F .../gpu.json", "on-click": "gpustat", "on-right-click": "nvtop" }
```

is repeated for gpu, cpu, ram, ssd, netfan, plus 5 compact variants. That is ~100 lines of boilerplate.

**Consolidation:** generate `modules-sysmon.json` from a JSON/YAML descriptor:

```yaml
sysmon_modules:
  - name: gpu
    icon: "󰢮"
    click: gpustat
    right: nvtop
  - name: cpu
    icon: "󰍛"
    click: htop
    right: gnome-system-monitor
  ...
```

A 30-line Python/Jinja script could render the final JSON and keep the configs DRY.

### 6.4 DDC brightness handlers

`modules-peripherals.json` has 4 handlers that are the same command with a different argument:

```json
"on-scroll-up":   "~/.config/waybar/scripts/utils/ddc.sh combo up   && pkill -SIGRTMIN+11 waybar",
"on-scroll-down": "~/.config/waybar/scripts/utils/ddc.sh combo down && pkill -SIGRTMIN+11 waybar",
"on-click":       "~/.config/waybar/scripts/utils/ddc.sh combo set 50 && pkill -SIGRTMIN+11 waybar",
"on-click-right": "~/.config/waybar/scripts/utils/ddc.sh combo set 100 && pkill -SIGRTMIN+11 waybar",
"on-click-middle":"~/.config/waybar/scripts/utils/ddc.sh combo set 0  && pkill -SIGRTMIN+11 waybar"
```

**Consolidation:** make `ddc.sh` signal Waybar itself after a change, or introduce `ddc-signal.sh <op> [value]`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$WAYBAR_HOME/scripts/lib/common.sh"
"$WAYBAR_HOME/scripts/utils/ddc.sh" "combo" "$@"
signal_waybar SIGRTMIN+11
```

Then the config becomes:

```json
"on-scroll-up":   "~/.config/waybar/scripts/modules/ddc-signal.sh up",
"on-scroll-down": "~/.config/waybar/scripts/modules/ddc-signal.sh down",
"on-click":       "~/.config/waybar/scripts/modules/ddc-signal.sh set 50",
...
```

### 6.5 Status / indicator modules

These scripts all do the same thing: query a subsystem and emit `{text, class, tooltip}`:

- `scripts/utils/wifi-indicator.sh`
- `scripts/utils/bt-indicator.sh`
- `scripts/utils/mic-status.sh`
- `scripts/utils/dunst.sh refresh`
- `scripts/utils/ext-display.sh refresh`
- `scripts/utils/fn-lock.sh refresh`
- `scripts/utils/keylight/kbd_status_json.sh`
- `scripts/utils/profile-indicator.sh`

**Consolidation:** a shared `emit_json` helper removes the duplicated `jq -nc ...` calls. A shared `log_error` removes the duplicated error redirects. Beyond that, each script is small enough that a common framework would be overkill, but the helpers would make them ~30% shorter and uniform.

### 6.6 Toggle / menu-action scripts

These follow the pattern: *run a privileged/stateful command, then signal Waybar*:

- `scripts/utils/wifi-toggle.sh`
- `scripts/utils/bt-toggle.sh`
- `scripts/utils/mic-toggle.sh`
- `scripts/utils/vpn.sh`
- menu actions in `modules-peripherals.json` and `modules-vc.json`

**Consolidation:** a generic `run-and-signal.sh <signal> <command> [args...]`:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$WAYBAR_HOME/scripts/lib/common.sh"
sig="$1"; shift
"$@" || log_error "${1:-cmd}" "failed: $?"
signal_waybar "$sig"
```

Usage in config:

```json
"on-click": "~/.config/waybar/scripts/modules/run-and-signal.sh SIGRTMIN+13 ~/.config/waybar/scripts/utils/mic-toggle.sh"
```

This also removes the `"Command failed"` error-logging duplication.

### 6.7 Inline shell in JSON configs

These currently spawn their own shell directly from Waybar:

- `config-top-base.jsonc` → `custom/lang` (swaymsg + grep + awk)
- `modules-vc.json` → `custom/recorder` (pgrep + echo JSON)
- `modules-vc.json` → `custom/ollama` (curl + ollama + awk + jq)
- `modules-vc.json` → `custom/powerbtn` (uptime + sed + awk)
- `modules-vc.json` → `custom/checkupdates` `on-click` (yay chain)

**Consolidation:** move each into its own script under `scripts/modules/` so the JSON only references a path. Benefits:

- Configs become declarative and lintable as JSON.
- Shell code can be checked with `shellcheck`.
- Common helpers (`log_error`, `signal_waybar`, `emit_json`) can be reused.

### 6.8 Sysmon formatter: full vs compact modules

`scripts/sysmon/formatter.sh` defines `mod_gpu` and `mod_compact_gpu`, `mod_cpu` and `mod_compact_cpu`, etc. The compact versions are just smaller-bar versions of the full versions.

**Consolidation:** parameterize the drawing function by `width`, `height`, and `icon set`, then call it twice:

```bash
draw_gpu() { local compact="$1"; ... }
safe_mod gpu            draw_gpu 0
safe_mod compact-gpu    draw_gpu 1
```

This roughly halves the formatter size.

### 6.9 Summary table: what to consolidate first

| Opportunity | Effort | Impact | Suggested file(s) |
|-------------|--------|--------|-------------------|
| Shared `log_error` / `signal_waybar` / `emit_json` | Low | High (security + dedup) | `scripts/lib/common.sh` |
| Common `tail-feed.sh` wrapper | Low | Medium | `scripts/modules/tail-feed.sh` |
| Generate `modules-sysmon.json` from a list | Medium | High (removes ~100 LOC) | `scripts/generate-config.py` |
| `run-and-signal.sh` for toggles | Low | Medium | `scripts/modules/run-and-signal.sh` |
| `ddc-signal.sh` wrapper | Low | Low | `scripts/modules/ddc-signal.sh` |
| Move inline shell out of JSON | Medium | High (maintainability) | `scripts/modules/lang-indicator.sh`, `ollama-status.sh`, etc. |
| Parameterize compact/full sysmon draws | Medium | Medium | `scripts/sysmon/formatter.sh` |

---

*Mini-shell consolidation scan completed.*
