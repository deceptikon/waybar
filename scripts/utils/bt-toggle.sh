#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

rfkill toggle bluetooth
signal_waybar SIGRTMIN+8
