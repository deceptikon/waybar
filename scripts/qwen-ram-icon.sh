#!/bin/bash
# RAM icon
icon=$(printf '\xf3\xb0\xa3\xb0')   # nf-mdi-memory U+F02F0  (memory chip)
jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
