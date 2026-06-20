#!/bin/bash
# ~/.config/waybar/scripts/ddc.sh [brightness|contrast] [get|up|down]

FEATURE=$1
ACTION=$2

CACHE_DIR="$HOME/.cache/waybar-ddc"
mkdir -p "$CACHE_DIR"

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

draw_slider() {
    local val=$1
    local width=10
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    local bar_filled=""
    local bar_empty=""
    for i in $(seq 1 $filled); do bar_filled="${bar_filled}█"; done
    for i in $(seq 1 $empty); do bar_empty="${bar_empty}█"; done
    echo "<span color='$COLOR'>$bar_filled</span><span color='#45475a'>$bar_empty</span>"
}

# If it's a 'get' action, or cache is missing, try to sync from monitor
if [ ! -f "$CACHE_FILE" ] || [ "$ACTION" = "get" ]; then
    # Try to grab the lock to ensure we aren't interrupting a scroll update
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
# Output json for Waybar. The UI updates instantly using the cached CURRENT value!
TEXT="<span color='$COLOR'>$SLIDER</span>"
echo "{\"text\": \"$TEXT\", \"tooltip\": \"$FEATURE: $CURRENT%\", \"percentage\": $CURRENT}"

# If action was up/down, spawn background worker to apply the change
if [ "$ACTION" = "up" ] || [ "$ACTION" = "down" ]; then
    (
        exec 200>"$LOCK_FILE"
        # Wait for any ongoing apply to finish
        flock 200
        
        # Once we have the lock, verify if there's still a pending target
        if [ -f "$TARGET_FILE" ]; then
            # Debounce delay - wait 0.2s to see if more scrolls happen
            sleep 0.2
            TARGET=$(cat "$TARGET_FILE" 2>/dev/null)
            if [ -n "$TARGET" ]; then
                # Consume the target
                rm -f "$TARGET_FILE"
                ddcutil setvcp $VCP $TARGET --noverify
            fi
        fi
    ) &
fi
