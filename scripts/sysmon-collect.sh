#!/usr/bin/env bash
set -euo pipefail
# sysmon-collect.sh — Run raw3 + mapper in one shot, emit JSON to stdout
# Usage: bash scripts/sysmon-collect.sh        # one-shot
#        watch -n 2 bash scripts/sysmon-collect.sh   # live

DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/sysmon-raw3.sh" | "$DIR/sysmon-mapper.sh"
