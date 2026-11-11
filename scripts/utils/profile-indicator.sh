#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

profile=$(powerprofilesctl get 2>>"$ERRLOG" | awk -F': ' '/Active profile:/{print $2}' | tr '[:upper:]' '[:lower:]')
case "$profile" in
    *quiet*)       icon=""; cls="good" ;;
    *balanced*)    icon=" "; cls="medium" ;;
    *performance*) icon=" "; cls="warning" ;;
    *)             icon=" "; cls="good" ;;
esac
emit_json "$icon" "$cls"
