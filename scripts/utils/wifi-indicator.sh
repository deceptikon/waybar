#!/usr/bin/env bash
# Top-bar Wi-Fi icon: radio/SSID state plus the WireGuard tunnel state.
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"

VPN_CONF="${VPN_CONF:-$HOME/vpn.conf}"
VPN_IF="${VPN_IF:-$(basename "$VPN_CONF" .conf)}"
VPN_IF="${VPN_IF:0:15}"
VPN_GLYPH="${VPN_GLYPH:-󱚿}"
VPN_STATE_FILE="${VPN_STATE_FILE:-$RUNTIME_DIR/waybar_vpn_state}"

vpn_state() {
    local dir="/sys/class/net/$VPN_IF" state="" age
    if [[ -f "$VPN_STATE_FILE" ]]; then
        age=$(( $(date +%s) - $(stat -c %Y "$VPN_STATE_FILE") ))
        if [[ "$age" -lt 180 ]]; then
            printf busy
            return
        fi
        log_error "wifi-indicator" "stale toggle state (${age}s old) ignored: $VPN_STATE_FILE"
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
            if [[ -f "$dir/carrier" ]] && [[ "$(cat "$dir/carrier" 2>>"$ERRLOG")" = "1" ]]; then
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
    ssid=$(iwgetid -r 2>>"$ERRLOG")
    wifi_icon=󰖩
    if [[ -n "$ssid" ]]; then
        wifi_class="connected"
        wifi_tip="Connected to $ssid"
    else
        wifi_class="enabled"
        wifi_tip="WiFi on (no connection)"
    fi
fi

text="$wifi_icon"

if ip a | grep -q -F ".vpn"; then
    vpn_class="vpn-on"
    vpn_tip="VPN up"
    text="$VPN_GLYPH"
else
    vpn_class="vpn-off"
    vpn_tip=""
fi

jq -cn --arg text "$text" --arg tooltip "$wifi_tip · $vpn_tip" --arg wifi "$wifi_class" --arg vpn "$vpn_class" '{text: $text, class: [$wifi, $vpn], tooltip: $tooltip}'
