#!/bin/bash

# CPU icon — single processor chip
icon=$(printf '\xf3\xb0\x85\x85')   # nf-mdi-chip U+F0145
jq -n --compact-output --arg t "$icon" '{text:$t,class:"icon"}'
