#!/usr/bin/env bash
# Top-bar Wi-Fi icon: radio/SSID state plus the WireGuard tunnel state.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

VPN_CONF="${VPN_CONF:-$HOME/.vpn.conf}"
VPN_IF="${VPN_IF:-$(basename "$VPN_CONF" .conf)}"
VPN_IF="${VPN_IF:0:15}"
VPN_GLYPH="${VPN_GLYPH:-󱚿}"
# Written by wg-vpn.sh while a toggle is in flight.
VPN_STATE_FILE="${VPN_STATE_FILE:-$RUNTIME_DIR/waybar_vpn_state}"

# A toggle in progress outranks the sysfs read: the bar should react the moment
# the menu item is clicked, not only when the kernel link appears.
vpn_state() {
    local dir="/sys/class/net/$VPN_IF" state="" age
    if [[ -f "$VPN_STATE_FILE" ]]; then
        age=$(( $(date +%s) - $(stat -c %Y "$VPN_STATE_FILE") ))
        if (( age < 180 )); then
            printf busy
            return
        fi
        # Stale marker from a crashed toggle: drop it and fall back to sysfs.
        rm -f "$VPN_STATE_FILE"
    fi
    if [[ ! -d "$dir" ]]; then
        printf off
        return
    fi
    if [[ -r "$dir/operstate" ]]; then
        state=$(cat "$dir/operstate" 2>>"$ERRLOG")
    fi
    case "$state" in
        up|unknown)
            if [[ -r "$dir/carrier" ]] && [[ "$(cat "$dir/carrier" 2>>"$ERRLOG")" = "1" ]]; then
                printf on
            else
                printf pending
            fi
            ;;
        *) printf pending ;;
    esac
}

if rfkill list wifi 2>>"$ERRLOG" | grep -q "Soft blocked: yes"; then
    wifi_icon=󰖪
    wifi_class="disabled"
    wifi_tip="WiFi disabled"
else
    ssid=$(iwgetid -r 2>>"$ERRLOG" || true)
    wifi_icon=󰖩
    if [[ -n "$ssid" ]]; then
        wifi_class="connected"
        wifi_tip="Connected to $ssid"
    else
        wifi_class="enabled"
        wifi_tip="WiFi on (no connection)"
    fi
fi

vstate=$(vpn_state)
case "$vstate" in
    busy)    vpn_class="vpn-connecting"; vpn_tip="VPN toggle in progress ($VPN_IF)" ;;
    on)      vpn_class="vpn-on";         vpn_tip="VPN up ($VPN_IF)" ;;
    pending) vpn_class="vpn-pending";    vpn_tip="VPN link $VPN_IF exists but has no carrier" ;;
    *)       vpn_class="vpn-off";        vpn_tip="" ;;
esac

# The tunnel glyph is full-size, not <sup>: an active VPN should be obvious.
text="$wifi_icon"
[[ "$vstate" != off ]] && text="$VPN_GLYPH"

tooltip="$wifi_tip"
[[ -n "$vpn_tip" ]] && tooltip="$wifi_tip · $vpn_tip"

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg wifi "$wifi_class" --arg vpn "$vpn_class" \
    '{text: $text, class: [$wifi, $vpn], tooltip: $tooltip}'
