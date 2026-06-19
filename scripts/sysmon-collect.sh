#!/usr/bin/env bash
set -euo pipefail
# sysmon-collect.sh — Collect raw system data, emit labeled sections to stdout
# Usage: bash scripts/sysmon-collect.sh | bash scripts/sysmon-mapper.sh

exec "$(dirname "$0")/sysmon-raw3.sh"
