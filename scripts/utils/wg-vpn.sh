#!/bin/bash

# Configuration
CONFIG_PATH="/home/alex/.vpn.conf"

# Extract interface name from the file path (e.g., /home/user/myvpn.conf -> myvpn)
INTERFACE=$(basename "$CONFIG_PATH" .conf)

# Check if the interface is active in 'wg show'
if ip a | grep ".vpn"; then
    sudo /usr/bin/wg-quick down "$CONFIG_PATH"
else
    sudo /usr/bin/wg-quick up "$CONFIG_PATH"
fi
pkill -SIGRTMIN+12 waybar



# Connect / disconnect the WireGuard tunnel defined by VPN_CONF (default
# ~/vpn.conf) with wg-quick up|down.
#
# Two facts shape this script:
#   - wg-quick re-execs itself through sudo when it is not root (auto_su in
#     wireguard-tools src/wg-quick/linux.bash), so the toggle must start as root;
#   - a waybar menu action has no controlling terminal, so pkexec cannot ask for a
#     password there: it prints "Error creating textual authentication agent: Error
#     opening current controlling terminal for the process (/dev/tty)" and exits 127
#     (polkit src/programs/pkexec.c:864-868, ret = 127 set at :502).
# So the waybar-side call only opens a terminal window and re-runs itself inside it,
# where pkexec can prompt. Set VPN_TERM=none to skip the window (useful with
# VPN_PRIV=sudo plus a NOPASSWD rule, or once a polkit agent is registered).
##  set -euo pipefail
##  
##  SELF="$(readlink -f "$0")"
##  LOG=/tmp/waybar_vpn.log
##  VPN_CONF="${VPN_CONF:-$HOME/.vpn.conf}"
##  # sudo authenticates as the invoking user, so it asks for one password. pkexec
##  # authenticates as any admin (polkit returns every admin identity when the
##  # action needs auth_admin), which is why it listed "myeel" and "alex" and asked
##  # "Choose identity to authenticate as". Keep VPN_PRIV=pkexec only if you want that.
##  VPN_PRIV="${VPN_PRIV:-sudo}"
##  STATE_FILE="${VPN_STATE_FILE:-/tmp/waybar_vpn_state}"
##  VPN_TERM="${VPN_TERM:-auto}"
##  IFACE="${VPN_IF:-$(basename "$VPN_CONF" .conf)}"
##  IFACE="${IFACE:0:15}"
##  
##  log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }
##  
##  # Notifications are advisory: a failure is logged, never fatal to the toggle.
##  notify() {
##      local rc=0
##      if command -v notify-send >/dev/null; then
##          notify-send "$@" || rc=$?
##      else
##          rc=127
##      fi
##      if [ "$rc" -ne 0 ]; then
##          log "notify-send rc=$rc, message dropped: $*"
##      fi
##      return 0
##  }
##  
##  run_wg() {
##      case "$VPN_PRIV" in
##          sudo) sudo wg-quick "$@" ;;
##          pkexec) pkexec wg-quick "$@" ;;
##          direct) wg-quick "$@" ;;
##          *)
##              log "unknown VPN_PRIV=$VPN_PRIV (expected pkexec|sudo|direct)"
##              return 2
##              ;;
##      esac
##  }
##  
##  # First available terminal emulator; prints nothing when there is none.
##  pick_terminal() {
##      local t
##      for t in ghostty foot alacritty kitty wezterm xterm; do
##          if command -v "$t" >/dev/null; then
##              printf '%s' "$t"
##              break
##          fi
##      done
##      return 0
##  }
##  
##  open_terminal() {
##      local term="$1"
##      shift
##      case "$term" in
##          foot) exec foot --wait -- "$@" ;;
##          alacritty) exec alacritty -e "$@" ;;
##          ghostty) exec ghostty -e "$@" ;;
##          kitty) exec kitty -e "$@" ;;
##          wezterm) exec wezterm start -- "$@" ;;
##          xterm) exec xterm -e "$@" ;;
##          *)
##              log "no launcher known for terminal '$term' - add it to open_terminal()"
##              return 1
##              ;;
##      esac
##  }
##  
##  checks() {
##      if [ ! -f "$VPN_CONF" ]; then
##          log "config $VPN_CONF not found - nothing to do"
##          notify "WireGuard" "Config not found: $VPN_CONF"
##          exit 1
##      fi
##      if [ "$VPN_PRIV" != "direct" ] && ! command -v "$VPN_PRIV" >/dev/null; then
##          log "privilege helper $VPN_PRIV not installed"
##          notify "WireGuard" "$VPN_PRIV not available - set VPN_PRIV in $SELF"
##          exit 1
##      fi
##  }
##  
##  # The real work. Run where a terminal is attached so authentication can happen.
##  mode_run() {
##      local action step out rc
##      checks
##  
##      if [ -d "/sys/class/net/$IFACE" ]; then
##          action="down"
##          step="Disconnecting $IFACE"
##      else
##          action="up"
##          step="Connecting $IFACE"
##      fi
##      log "toggling: $VPN_PRIV wg-quick $action $VPN_CONF (iface $IFACE)"
##      printf '==> %s: %s wg-quick %s %s\n' "$step" "$VPN_PRIV" "$action" "$VPN_CONF"
##  
##      # Publish the in-progress state and redraw now, so the icon changes colour
##      # while authenticating/connecting instead of only once the tunnel exists.
##      # wifi-indicator.sh ages this out if we die before removing it.
##      printf '%s %s\n' "$action" "$IFACE" > "$STATE_FILE"
##      trap 'rm -f "$STATE_FILE"' EXIT
##      if ! pkill -SIGRTMIN+12 waybar; then
##          log "no waybar process matched SIGRTMIN+12 - connecting state not drawn"
##      fi
##  
##      out=""
##      rc=0
##      out=$(run_wg "$action" "$VPN_CONF" 2>&1) || rc=$?
##      rm -f "$STATE_FILE"
##      trap - EXIT
##      if [ -n "$out" ]; then
##          printf '%s\n' "$out"
##          printf '%s\n' "$out" >>"$LOG"
##      fi
##      if [ "$rc" -eq 0 ]; then
##          log "wg-quick $action succeeded"
##          printf '==> wg-quick %s succeeded\n' "$action"
##          notify "WireGuard" "$IFACE $action ok"
##      else
##          log "wg-quick $action failed rc=$rc"
##          printf '==> wg-quick %s FAILED (rc=%s), log: %s\n' "$action" "$rc" "$LOG"
##          notify "WireGuard" "$IFACE $action failed rc=$rc, see $LOG"
##      fi
##  
##      if ! pkill -SIGRTMIN+12 waybar; then
##          log "no waybar process matched SIGRTMIN+12 - icon not refreshed"
##      fi
##  
##      # stdin is the terminal window: only pause when one is really attached, and a
##      # closed stdin is fine either way - the window goes away regardless.
##      if [ -t 0 ]; then
##          printf '\nPress Enter to close this window. '
##          read -r _ || printf 'stdin closed\n'
##      fi
##  
##      exit "$rc"
##  }
##  
##  # What waybar calls: no tty here, so hand everything to a terminal window.
##  mode_launch() {
##      local term
##      checks
##  
##      if [ "$VPN_TERM" = "none" ]; then
##          log "VPN_TERM=none - authenticating without a terminal window"
##          mode_run
##      fi
##  
##      if [ "$VPN_TERM" = "auto" ]; then
##          term=$(pick_terminal)
##      elif command -v "$VPN_TERM" >/dev/null; then
##          term="$VPN_TERM"
##      else
##          term=""
##      fi
##  
##      if [ -z "$term" ]; then
##          log "no terminal emulator found (tried ghostty foot alacritty kitty wezterm xterm) - set VPN_TERM"
##          notify "WireGuard" "No terminal to authenticate in - set VPN_TERM"
##          exit 1
##      fi
##  
##      log "opening $term to authenticate the wg-quick toggle"
##      open_terminal "$term" "$SELF" run
##  }
##  
##  case "${1:-launch}" in
##      run) mode_run ;;
##      launch) mode_launch ;;
##      *)
##          printf 'usage: %s [launch|run]\n' "$SELF" >&2
##          exit 2
##          ;;
##  esac
