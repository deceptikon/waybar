#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/sysmon-collect.sh" | "$DIR/sysmon-mapper.sh" | "$DIR/sysmon-format.sh" | grep "^SSD " | sed 's/^SSD //'
