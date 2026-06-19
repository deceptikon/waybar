#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
data=$("$DIR/sysmon-collect.sh" | "$DIR/sysmon-mapper.sh")
profile=$(jq -r '.asus.profile // "unknown"' <<< "$data")
case "$profile" in
  Quiet)       text=$(printf "<b>ECO</b>\n<span size='smaller'>Quiet</span>"); cls="good" ;;
  Balanced)    text=$(printf "<b>BAL</b>\n<span size='smaller'>Balanced</span>"); cls="medium" ;;
  Performance) text=$(printf "<b>PERF</b>\n<span size='smaller'>Performance</span>"); cls="warning" ;;
  *)           text="<b>$profile</b>"; cls="good" ;;
esac
jq -nc --arg text "$text" --arg cls "$cls" '{text: $text, class: $cls}'
