#!/usr/bin/env bash
# uptime-widget.sh — power button uptime display
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

uptime -p 2>>"$ERRLOG" \
    | sed 's/up //' \
    | awk '
    {
        d = 0; h = 0; m = 0
        if ($0 ~ /(day)/)    { match($0, /([0-9]+)[[:space:]]*day/, a);    d = a[1] + 0 }
        if ($0 ~ /(hour)/)   { match($0, /([0-9]+)[[:space:]]*hour/, a);   h = a[1] + 0 }
        if ($0 ~ /(min)/)    { match($0, /([0-9]+)[[:space:]]*min/, a);    m = a[1] + 0 }
        t = d * 24 * 60 + h * 60 + m
        printf " <sub>%3dh</sub>  ⏻  <sub>%3dm</sub> ", int(t / 60), t % 60
    }'
