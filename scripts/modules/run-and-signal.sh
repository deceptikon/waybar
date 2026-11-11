#!/usr/bin/env bash
# run-and-signal.sh — run a command then signal waybar
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if [[ $# -lt 2 ]]; then
    log_error "run-and-signal" "usage: $0 <signal> <command> [args...]"
    exit 1
fi

sig="$1"
shift

if ! "$@"; then
    log_error "run-and-signal" "command failed ($sig): $*"
fi

signal_waybar "$sig"
