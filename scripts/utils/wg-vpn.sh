#!/bin/bash
# Connect / disconnect the WireGuard tunnel defined by VPN_CONF (default ~/vpn.conf)
# with wg-quick up|down.
#
# wg-quick re-execs itself through sudo when it is not root (auto_su in
# wireguard-tools src/wg-quick/linux.bash), and a waybar menu action has no
# terminal to answer that prompt with. Running it under pkexec makes it root,
# so wg-quick skips auto_su and pkexec performs the authorisation itself.
# Set VPN_PRIV=sudo for a NOPASSWD setup, VPN_PRIV=direct when already root.
set -euo pipefail

LOG=/tmp/waybar_vpn.log
VPN_CONF="${VPN_CONF:-$HOME/vpn.conf}"
VPN_PRIV="${VPN_PRIV:-pkexec}"
IFACE="${VPN_IF:-$(basename "$VPN_CONF" .conf)}"
IFACE="${IFACE:0:15}"

log() { printf "%s %s\n" "$(date -Iseconds)" "$*" >>"$LOG"; }

# Notifications are advisory: a failure is logged, never fatal to the toggle.
notify() {
    local rc=0
    if command -v notify-send >/dev/null; then
        notify-send "$@" || rc=$?
    else
        rc=127
    fi
    if [ "$rc" -ne 0 ]; then
        log "notify-send rc=$rc, message dropped: $*"
    fi
    return 0
}

run_wg() {
    case "$VPN_PRIV" in
        pkexec) pkexec wg-quick "$@" ;;
        sudo) sudo wg-quick "$@" ;;
        direct) wg-quick "$@" ;;
        *)
            log "unknown VPN_PRIV=$VPN_PRIV (expected pkexec|sudo|direct)"
            return 2
            ;;
    esac
}

if [ ! -f "$VPN_CONF" ]; then
    log "config $VPN_CONF not found - nothing to do"
    notify "WireGuard" "Config not found: $VPN_CONF"
    exit 1
fi

if [ "$VPN_PRIV" != "direct" ] && ! command -v "$VPN_PRIV" >/dev/null; then
    log "privilege helper $VPN_PRIV not installed"
    notify "WireGuard" "$VPN_PRIV not available - set VPN_PRIV in wg-vpn.sh"
    exit 1
fi

if [ -d "/sys/class/net/$IFACE" ]; then
    action="down"
    step="Disconnecting $IFACE"
else
    action="up"
    step="Connecting $IFACE"
fi
log "toggling: $VPN_PRIV wg-quick $action $VPN_CONF (iface $IFACE)"
notify "WireGuard" "$step"

rc=0
run_wg "$action" "$VPN_CONF" 2>>"$LOG" || rc=$?

if [ "$rc" -eq 0 ]; then
    log "wg-quick $action succeeded"
else
    log "wg-quick $action failed rc=$rc - last lines in $LOG"
    notify "WireGuard" "wg-quick $action failed (rc=$rc), see $LOG"
fi

if ! pkill -SIGRTMIN+12 waybar; then
    log "no waybar process matched SIGRTMIN+12 - icon not refreshed"
fi

exit "$rc"
