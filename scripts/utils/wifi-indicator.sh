#!/bin/bash
# Top-bar Wi-Fi icon: radio/SSID state plus the WireGuard tunnel state.
#
# The tunnel is detected through the link wg-quick creates for VPN_CONF.
# wg-quick names that link after the config basename (~/vpn.conf -> "vpn"),
# so this stays a plain sysfs read: no root and no wg-show needed.

ERRLOG=/tmp/waybar_errors.log
VPN_CONF="${VPN_CONF:-$HOME/vpn.conf}"
VPN_IF="${VPN_IF:-$(basename "$VPN_CONF" .conf)}"
VPN_IF="${VPN_IF:0:15}"
# nf-md-vpn (U+F0582). Export VPN_GLYPH to swap it if the font renders tofu.
VPN_GLYPH="${VPN_GLYPH:-󰖂}"
# Written by wg-vpn.sh while a toggle is in flight.
VPN_STATE_FILE="${VPN_STATE_FILE:-/tmp/waybar_vpn_state}"

# A toggle in progress outranks the sysfs read: the bar should react the moment
# the menu item is clicked, not only when the kernel link appears.
vpn_state() {
    local dir="/sys/class/net/$VPN_IF" state="" age
    if [ -f "$VPN_STATE_FILE" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$VPN_STATE_FILE") ))
        if [ "$age" -lt 180 ]; then
            printf busy
            return
        fi
        printf '%s vpn-indicator: stale toggle state (%ss old) ignored: %s\n' "$(date -Iseconds)" "$age" "$VPN_STATE_FILE" >>"$ERRLOG"
    fi
    if [ ! -d "$dir" ]; then
        printf off
        return
    fi
    if [ -r "$dir/operstate" ]; then
        state=$(cat "$dir/operstate" 2>>"$ERRLOG")
    fi
    # Check for connected state - include 'up' and 'unknown' which are both valid connected states
    case "$state" in
        up|unknown) 
            # Additional check: verify the interface has an IP address and carrier to confirm it's truly connected
            if [ -f "$dir/carrier" ] && [ "$(cat "$dir/carrier" 2>>"$ERRLOG")" = "1" ]; then
                printf on
            else
                printf pending
            fi
            ;;
        *) printf pending ;;     
    esac
}

if rfkill list wifi 2>>"$ERRLOG" | grep -q "Soft blocked: yes"; then
    wifi_icon=󰤮
    wifi_class="disabled"
    wifi_tip="WiFi disabled"
else
    ssid=$(iwgetid -r 2>>"$ERRLOG")
    wifi_icon=󰤨
    if [ -n "$ssid" ]; then
        wifi_class="connected"
        wifi_tip="Connected to $ssid"
    else
        wifi_class="enabled"
        wifi_tip="WiFi on (no connection)"
    fi
fi

# The tunnel glyph is full-size, not <sup>: superscript at 15px rendered too
# small to notice, so an active VPN looked like a plain wifi icon.
vstate=$(vpn_state)
text="$wifi_icon"
case "$vstate" in
    busy)    vpn_class="vpn-connecting"; text="$wifi_icon$VPN_GLYPH"; vpn_tip="VPN toggle in progress ($VPN_IF)" ;;
    on)      vpn_class="vpn-on";      text="$wifi_icon$VPN_GLYPH"; vpn_tip="VPN up ($VPN_IF)" ;;
    pending) vpn_class="vpn-pending"; text="$wifi_icon$VPN_GLYPH"; vpn_tip="VPN link $VPN_IF exists but has no carrier" ;;
    *)       vpn_class="vpn-off";     vpn_tip="VPN down" ;;
esac

jq -cn --arg text "$text" --arg tooltip "$wifi_tip · $vpn_tip" --arg wifi "$wifi_class" --arg vpn "$vpn_class" '{text: $text, class: [$wifi, $vpn], tooltip: $tooltip}'
