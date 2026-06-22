#!/bin/bash
set -euo pipefail
# ~/.config/waybar/scripts/ddc.sh [brightness|contrast|combo] [get|up|down]

FEATURE=${1:-}
ACTION=${2:-}

CACHE_DIR="$HOME/.cache/waybar-ddc"
mkdir -p "$CACHE_DIR"

draw_slider() {
    local val=$1
    local width=12
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    local body=""
    for i in $(seq 1 $filled); do body="${body}█"; done
    for i in $(seq 1 $empty); do body="${body}░"; done
    local cap_size='font_size="120%"'
    if [ $filled -gt 0 ]; then
        local filled_part="${body:0:$filled}"
        local empty_part="${body:$filled}"
        if [ $empty -gt 0 ]; then
            echo "<span letter_spacing='-2'><span color='$COLOR'><span $cap_size>◖</span>$filled_part</span><span color='#45475a'>${empty_part}<span $cap_size>◗</span></span></span>"
        else
            echo "<span letter_spacing='-2'><span color='$COLOR'><span $cap_size>◖</span>$filled_part<span $cap_size>◗</span></span></span>"
        fi
    else
        echo "<span letter_spacing='-2'><span color='#45475a'><span $cap_size>◖</span>${body}<span $cap_size>◗</span></span></span>"
    fi
}

apply_vcp() {
    local vcp=$1 lock=$2 target=$3
    (
        exec 200>"$lock"
        flock 200
        if [ -f "$target" ]; then
            sleep 0.2
            T=$(cat "$target" 2>/dev/null)
            if [ -n "$T" ]; then
                rm -f "$target"
                ddcutil setvcp "$vcp" "$T" --noverify
            fi
        fi
    ) &
}

# ── Combined brightness+contrast mode ──
if [ "$FEATURE" = "combo" ]; then
    COLOR="#fab387"
    BRIGHTNESS_CACHE="$CACHE_DIR/brightness"
    BRIGHTNESS_LOCK="$CACHE_DIR/brightness.lock"
    BRIGHTNESS_TARGET="$CACHE_DIR/brightness.target"

    # Sync from hardware only when cache missing (first run). Never on 'get',
    # otherwise a pending apply_vcp worker hasn't flushed yet and we'd re-read
    # the stale hardware value, overwriting the updated cache.
    if [ ! -f "$BRIGHTNESS_CACHE" ]; then
        (
            exec 200>"$BRIGHTNESS_LOCK"
            if flock -n 200; then
                VAL=$(ddcutil getvcp 10 -t 2>/dev/null | awk '{print $4}')
                [ -n "$VAL" ] && echo "$VAL" > "$BRIGHTNESS_CACHE"
            fi
        )
    fi

    CURRENT=$(cat "$BRIGHTNESS_CACHE" 2>/dev/null || echo 50)

    if [ "$ACTION" = "up" ]; then
        CURRENT=$((CURRENT + 1))
        [ $CURRENT -gt 100 ] && CURRENT=100
    elif [ "$ACTION" = "down" ]; then
        CURRENT=$((CURRENT - 1))
        [ $CURRENT -lt 0 ] && CURRENT=0
    elif [ "$ACTION" = "set" ]; then
        CURRENT=${3:-50}
        [ $CURRENT -gt 100 ] && CURRENT=100
        [ $CURRENT -lt 0 ] && CURRENT=0
    fi

    # Contrast is always derived from brightness — never cached independently
    # Linear: brightness 0 → contrast 25, brightness 100 → contrast 100
    CONTRAST=$(( 25 + CURRENT * 75 / 100 ))

    SLIDER=$(draw_slider "$CURRENT")
    echo "{\"text\": \"<span color='$COLOR'>$SLIDER</span>\", \"tooltip\": \"brightness: $CURRENT%  contrast: $CONTRAST%\", \"percentage\": $CURRENT}"

    if [ "$ACTION" = "up" ] || [ "$ACTION" = "down" ] || [ "$ACTION" = "set" ]; then
        echo "$CURRENT" > "$BRIGHTNESS_CACHE"
        echo "$CURRENT" > "$BRIGHTNESS_TARGET"
        apply_vcp 10 "$BRIGHTNESS_LOCK" "$BRIGHTNESS_TARGET"
        # Apply derived contrast in its own background worker
        echo "$CONTRAST" > "$CACHE_DIR/contrast.target"
        apply_vcp 12 "$CACHE_DIR/contrast.lock" "$CACHE_DIR/contrast.target"
    fi
    exit 0
fi

# ── Existing individual modes ──
if [ "$FEATURE" = "brightness" ]; then
    VCP=10
    ICON="󰃠"
    COLOR="#fab387"
    CACHE_FILE="$CACHE_DIR/brightness"
    LOCK_FILE="$CACHE_DIR/brightness.lock"
    TARGET_FILE="$CACHE_DIR/brightness.target"
elif [ "$FEATURE" = "contrast" ]; then
    VCP=12
    ICON="󰆈"
    COLOR="#cba6f7"
    CACHE_FILE="$CACHE_DIR/contrast"
    LOCK_FILE="$CACHE_DIR/contrast.lock"
    TARGET_FILE="$CACHE_DIR/contrast.target"
else
    exit 1
fi

# If it's a 'get' action, or cache is missing, try to sync from monitor
if [ ! -f "$CACHE_FILE" ] || [ "$ACTION" = "get" ]; then
    (
        exec 200>"$LOCK_FILE"
        if flock -n 200; then
            VAL=$(ddcutil getvcp $VCP -t 2>/dev/null | awk '{print $4}')
            if [ -n "$VAL" ]; then
                echo "$VAL" > "$CACHE_FILE"
            fi
        fi
    )
fi

CURRENT=$(cat "$CACHE_FILE" 2>/dev/null)
if [ -z "$CURRENT" ]; then
    CURRENT=50
fi

if [ "$ACTION" = "up" ]; then
    CURRENT=$((CURRENT + 5))
    [ $CURRENT -gt 100 ] && CURRENT=100
    echo "$CURRENT" > "$CACHE_FILE"
    echo "$CURRENT" > "$TARGET_FILE"
elif [ "$ACTION" = "down" ]; then
    CURRENT=$((CURRENT - 5))
    [ $CURRENT -lt 0 ] && CURRENT=0
    echo "$CURRENT" > "$CACHE_FILE"
    echo "$CURRENT" > "$TARGET_FILE"
fi

SLIDER=$(draw_slider "$CURRENT")
TEXT="<span color='$COLOR'>$SLIDER</span>"
echo "{\"text\": \"$TEXT\", \"class\": \"ddc-slider\", \"tooltip\": \"$FEATURE: $CURRENT%\", \"percentage\": $CURRENT}"
echo "{\"text\": \"<span color='$COLOR'>$SLIDER</span>\", \"class\": \"ddc-slider\",\"tooltip\": \"brightness: $CURRENT%  contrast: $CONTRAST%\", \"percentage\": $CURRENT}"

if [ "$ACTION" = "up" ] || [ "$ACTION" = "down" ]; then
    apply_vcp "$VCP" "$LOCK_FILE" "$TARGET_FILE"
fi
