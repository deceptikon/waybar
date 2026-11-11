#!/usr/bin/env bash
source "${WAYBAR_HOME:-$HOME/.config/waybar}/scripts/lib/common.sh"
set +e
# ddc.sh [brightness|contrast|combo] [get|up|down|set N]

FEATURE=${1:-}
ACTION=${2:-}

CACHE_DIR="$HOME/.cache/waybar-ddc"
mkdir -p "$CACHE_DIR"

draw_slider() {
    local val=$1 width=17 filled empty body
    filled=$(( val * width / 100 ))
    empty=$(( width - filled ))
    body=""
    for i in $(seq 1 $filled); do body="${body}█"; done
    for i in $(seq 1 $empty);  do body="${body}░"; done
    if [[ $filled -gt 0 ]]; then
        local fp="${body:0:$filled}" ep="${body:$filled}"
        if [[ $empty -gt 0 ]]; then
            echo "<span color='$COLOR'>$fp</span><span color='#45475a'>${ep}</span>"
        else
            echo "<span color='$COLOR'>${fp}</span>"
        fi
    else
        echo "<span color='#45475a'>${body}</span>"
    fi
}

apply_vcp() {
    local vcp=$1 lock=$2 target=$3
    (
        exec 200>"$lock"
        flock 200
        if [[ -f "$target" ]]; then
            sleep 0.2
            local T
            T=$(cat "$target" 2>>"$ERRLOG")
            if [[ -n "$T" ]]; then
                rm -f "$target"
                ddcutil setvcp "$vcp" "$T" --noverify
            fi
        fi
    ) &
}

# ── Combined brightness+contrast mode ──
if [[ "$FEATURE" = "combo" ]]; then
    COLOR="#fab387"
    BRIGHTNESS_CACHE="$CACHE_DIR/brightness"
    BRIGHTNESS_LOCK="$CACHE_DIR/brightness.lock"
    BRIGHTNESS_TARGET="$CACHE_DIR/brightness.target"

    if [[ ! -f "$BRIGHTNESS_CACHE" ]]; then
        (
            exec 200>"$BRIGHTNESS_LOCK"
            if flock -n 200; then
                VAL=$(ddcutil getvcp 10 -t 2>>"$ERRLOG" | awk '{print $4}')
                [[ -n "$VAL" ]] && echo "$VAL" > "$BRIGHTNESS_CACHE"
            fi
        )
    fi

    CURRENT=$(cat "$BRIGHTNESS_CACHE" 2>>"$ERRLOG" || echo 50)

    case "$ACTION" in
        up)
            CURRENT=$((CURRENT + 1))
            [[ $CURRENT -gt 100 ]] && CURRENT=100
            ;;
        down)
            CURRENT=$((CURRENT - 1))
            [[ $CURRENT -lt 0 ]] && CURRENT=0
            ;;
        set)
            CURRENT=${3:-50}
            [[ $CURRENT -gt 100 ]] && CURRENT=100
            [[ $CURRENT -lt 0 ]] && CURRENT=0
            ;;
    esac

    CONTRAST=$(( 25 + CURRENT * 75 / 100 ))
    SLIDER=$(draw_slider "$CURRENT")
    echo "{\"text\": \"<span color='$COLOR'>$SLIDER</span>\", \"tooltip\": \"brightness: $CURRENT%  contrast: $CONTRAST%\", \"percentage\": $CURRENT}"

    if [[ "$ACTION" =~ ^(up|down|set)$ ]]; then
        echo "$CURRENT" > "$BRIGHTNESS_CACHE"
        echo "$CURRENT" > "$BRIGHTNESS_TARGET"
        apply_vcp 10 "$BRIGHTNESS_LOCK" "$BRIGHTNESS_TARGET"
        echo "$CONTRAST" > "$CACHE_DIR/contrast.target"
        apply_vcp 12 "$CACHE_DIR/contrast.lock" "$CACHE_DIR/contrast.target"
    fi
    exit 0
fi

# ── Individual modes ──
if [[ "$FEATURE" = "brightness" ]]; then
    VCP=10
    ICON="󰃠"
    COLOR="#fab387"
    CACHE_FILE="$CACHE_DIR/brightness"
    LOCK_FILE="$CACHE_DIR/brightness.lock"
    TARGET_FILE="$CACHE_DIR/brightness.target"
elif [[ "$FEATURE" = "contrast" ]]; then
    VCP=12
    ICON="󰆈"
    COLOR="#cba6f7"
    CACHE_FILE="$CACHE_DIR/contrast"
    LOCK_FILE="$CACHE_DIR/contrast.lock"
    TARGET_FILE="$CACHE_DIR/contrast.target"
else
    exit 1
fi

if [[ ! -f "$CACHE_FILE" ]] || [[ "$ACTION" = "get" ]]; then
    (
        exec 200>"$LOCK_FILE"
        if flock -n 200; then
            VAL=$(ddcutil getvcp $VCP -t 2>>"$ERRLOG" | awk '{print $4}')
            if [[ -n "$VAL" ]]; then
                echo "$VAL" > "$CACHE_FILE"
            fi
        fi
    )
fi

CURRENT=$(cat "$CACHE_FILE" 2>>"$ERRLOG" || true)
if [[ -z "$CURRENT" ]]; then
    CURRENT=50
fi

case "$ACTION" in
    up)
        CURRENT=$((CURRENT + 5))
        [[ $CURRENT -gt 100 ]] && CURRENT=100
        echo "$CURRENT" > "$CACHE_FILE"
        echo "$CURRENT" > "$TARGET_FILE"
        ;;
    down)
        CURRENT=$((CURRENT - 5))
        [[ $CURRENT -lt 0 ]] && CURRENT=0
        echo "$CURRENT" > "$CACHE_FILE"
        echo "$CURRENT" > "$TARGET_FILE"
        ;;
    set)
        CURRENT=${3:-50}
        [[ $CURRENT -gt 100 ]] && CURRENT=100
        [[ $CURRENT -lt 0 ]] && CURRENT=0
        echo "$CURRENT" > "$CACHE_FILE"
        echo "$CURRENT" > "$TARGET_FILE"
        ;;
esac

SLIDER=$(draw_slider "$CURRENT")
TEXT="<span color='$COLOR'>$SLIDER</span>"
echo "{\"text\": \"$TEXT\", \"class\": \"ddc-slider\", \"tooltip\": \"$FEATURE: $CURRENT%\", \"percentage\": $CURRENT}"

if [[ "$ACTION" =~ ^(up|down|set)$ ]]; then
    apply_vcp "$VCP" "$LOCK_FILE" "$TARGET_FILE"
fi
