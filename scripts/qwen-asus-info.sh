#!/bin/bash
# Asus profile info tile

profile=$(asusctl profile get | awk '/Active profile/ {print $NF}')

case "$profile" in
    Quiet)
        text=$(printf "<b>ECO</b>\n<span size='smaller'>Quiet</span>")
        class="good"
        ;;
    Balanced)
        text=$(printf "<b>BAL</b>\n<span size='smaller'>Balanced</span>")
        class="medium"
        ;;
    Performance)
        text=$(printf "<b>PERF</b>\n<span size='smaller'>Performance</span>")
        class="warning"
        ;;
    *)
        text="<b>$profile</b>"
        class="good"
        ;;
esac

jq -n --compact-output \
    --arg text "$text" \
    --arg class "$class" \
    '{text: $text, class: $class}'