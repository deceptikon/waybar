#!/bin/bash
profile=$(powerprofilesctl get 2>>/tmp/waybar_errors.log | awk -F': ' '/Active profile:/{print $2}' | tr '[:upper:]' '[:lower:]')
case "$profile" in
  *quiet*)       icon=""; cls="good" ;;
  *balanced*)    icon=" "; cls="medium" ;;
  *performance*) icon=" "; cls="warning" ;;
  *)             icon=" "; cls="good" ;;
esac
jq -nc --arg icon "$icon" --arg cls "$cls" '{text: $icon, class: $cls}'
