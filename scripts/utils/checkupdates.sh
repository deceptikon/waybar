#!/usr/bin/env bash

set -u

readonly LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-updates.log"

mkdir -p "$(dirname "$LOG_FILE")"

tmp_dir="$(mktemp -d)"
tmp_cleanup_status=$?

if [ "$tmp_cleanup_status" -ne 0 ]; then
    jq -nc '
        {
            text: "󰀪",
            tooltip: "Unable to create temporary directory",
            class: "error"
        }
    '
    exit 1
fi

cleanup() {
    rm -rf "$tmp_dir"
}

trap cleanup EXIT

official_output="$tmp_dir/official-output"
official_error="$tmp_dir/official-error"
aur_output="$tmp_dir/aur-output"
aur_error="$tmp_dir/aur-error"

checkupdates >"$official_output" 2>"$official_error"
official_status=$?

yay -Quy >"$aur_output" 2>"$aur_error"
aur_status=$?

official_failure=0
aur_failure=0

case "$official_status" in
    0|1|2)
        ;;
    *)
        official_failure=1
        ;;
esac

if [ $aur_status -gt 1 ]; then
    aur_failure=1
fi

if [ "$official_failure" -ne 0 ] || [ "$aur_failure" -ne 0 ]; then
    {
        printf '[%s] update check failed\n' "$(date --iso-8601=seconds)"

        if [ "$official_failure" -ne 0 ]; then
            printf '\nCommand: checkupdates\n'
            printf 'Exit status: %s\n' "$official_status"
            printf 'stderr:\n'
            cat "$official_error"
        fi

        if [ "$aur_failure" -ne 0 ]; then
            printf '\nCommand: yay -Qua\n'
            printf 'Exit status: %s\n' "$aur_status"
            printf 'stderr:\n'
            cat "$aur_error"
        fi

        printf '\n'
    } >>"$LOG_FILE"

    error_details=""

    if [ "$official_failure" -ne 0 ]; then
        error_details="official repository check failed"
    fi

    if [ "$aur_failure" -ne 0 ]; then
        if [ -n "$error_details" ]; then
            error_details="$error_details; AUR check failed"
        else
            error_details="AUR check failed"
        fi
    fi

    jq -nc --arg details "$error_details" '
        {
            text: "󰀪",
            tooltip: ("Update check error: " + $details),
            class: "error"
        }
    '

    exit 1
fi

official_count="$(
    awk '
        NF && $0 !~ /\[ignored\]/ {
            count++
        }
        END {
            print count + 0
        }
    ' "$official_output"
)"

aur_count="$(
    awk '
        NF && $0 !~ /\[ignored\]/ {
            count++
        }
        END {
            print count + 0
        }
    ' "$aur_output"
)"

total_count=$((official_count + aur_count))

if [ "$total_count" -eq 0 ]; then
    jq -nc '
        {
            text: "  ",
            tooltip: "System is up-to-date",
            class: "good"
        }
    '
else
    jq -nc \
        --arg total "$total_count" \
        --arg official "$official_count" \
        --arg aur "$aur_count" '
        {
            text: (" <sup>" + $total + "</sup>"),
            tooltip: (
                $total + " updates pending: " +
                $official + " official, " +
                $aur + " AUR"
            ),
            class: "notify"
        }
    '
fi


#!/bin/bash
#set -euo pipefail

# count=$(checkupdates 2>>/tmp/waybar_errors.log | grep -cv "\[ignored\]")
#
# if [ "$count" -ne 0 ]; then
#     jq -nc --arg c "$count" '{"text":" <sup>\($c)</sup>","tooltip":"\($c) updates pending","class":"notify"}'
# else
#     jq -nc '{"text":"  ","tooltip":"System is up-to-date","class":"good"}'
# fi
