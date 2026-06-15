#!/bin/bash
# RAM icon — nf-md-memory (U+F035B) straight RAM stick
icon=$(printf '\xf3\xb0\x8d\x9b')
jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
