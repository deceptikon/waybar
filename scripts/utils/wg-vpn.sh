#!/usr/bin/env bash
# Minimal WireGuard toggle. Uses VPN_CONF (default ~/.vpn.conf).
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

CONFIG_PATH="${VPN_CONF:-$HOME/.vpn.conf}"
INTERFACE=$(basename "$CONFIG_PATH" .conf)
INTERFACE="${INTERFACE:0:15}"
STATE_FILE="$RUNTIME_DIR/waybar_vpn_state"

if [[ ! -f "$CONFIG_PATH" ]]; then
    log_error "wg-vpn" "config not found: $CONFIG_PATH"
    exit 1
fi

if [[ -d "/sys/class/net/$INTERFACE" ]]; then
    action="down"
else
    action="up"
fi

# Publish the in-flight state and redraw immediately.
printf '%s %s\n' "$action" "$INTERFACE" >"$STATE_FILE"
trap 'rm -f "$STATE_FILE"' EXIT
signal_waybar SIGRTMIN+12

if ! sudo /usr/bin/wg-quick "$action" "$CONFIG_PATH"; then
    log_error "wg-vpn" "wg-quick $action failed: $CONFIG_PATH"
fi

rm -f "$STATE_FILE"
trap - EXIT
signal_waybar SIGRTMIN+12
