#!/bin/bash
#set -euo pipefail

count=$(yay -Qu 2>/dev/null | grep -cv "\[ignored\]")

if [ "$count" -ne 0 ]; then
    jq -nc --arg c "$count" '{"text":" <sup>\($c)</sup>","tooltip":"\($c) updates pending","class":"notify"}'
else
    jq -nc '{"text":"  ","tooltip":"System is up-to-date","class":"good"}'
fi
