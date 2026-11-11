#!/usr/bin/env bash
# Minimal WireGuard toggle. Uses VPN_CONF (default ~/.vpn.conf).
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

CONFIG_PATH="${VPN_CONF:-$HOME/.vpn.conf}"
INTERFACE=$(basename "$CONFIG_PATH" .conf)
STATE_FILE="$RUNTIME_DIR/waybar_vpn_state"

if ip a | grep -q -F ".vpn"; then
    sudo /usr/bin/wg-quick down "$CONFIG_PATH"
else
    sudo /usr/bin/wg-quick up "$CONFIG_PATH"
fi

printf '%s %s\n' "${action:-toggle}" "$INTERFACE" > "$STATE_FILE" 2>/dev/null || true
signal_waybar SIGRTMIN+12
