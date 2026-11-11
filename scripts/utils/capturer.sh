#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

LOG_FILE="$LOG_DIR/capturer.log"
SAVE_DIR="$HOME/Media/captured/$(date +%Y-%m)"
mkdir -p "$SAVE_DIR"
TEMP_REC="$STATE_DIR/recording_temp.mkv"

log_msg() { echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"; }

update_waybar() {
    log_msg "Signaling Waybar..."
    signal_waybar SIGRTMIN+8
}

# --- STOP LOGIC ---
if pgrep -x "wf-recorder" > /dev/null; then
    log_msg "Stopping recording..."
    pkill -INT wf-recorder

    while pgrep -x "wf-recorder" > /dev/null; do sleep 0.2; done

    update_waybar

    FILENAME=$(wofi --dmenu --prompt "Name file (Enter for timestamp):") || true
    [[ -z "$FILENAME" ]] && FILENAME="rec_$(date +%H-%M-%S)"
    FULL_PATH="$SAVE_DIR/${FILENAME}.mp4"

    if [[ -f "$TEMP_REC" ]]; then
        (
            ffmpeg -nostdin -i "$TEMP_REC" -c copy -movflags +faststart "$FULL_PATH" -y >/dev/null 2>&1

            if [[ -f "$FULL_PATH" ]]; then
                wl-copy < "$FULL_PATH"
                rm "$TEMP_REC"
                notify-send -a "Capturer" "✔ Done" "Saved to $FILENAME.mp4"
            fi
        ) &
        disown
    fi
    update_waybar
    exit 0
fi

# --- START LOGIC ---
GEOM=$(slurp) || exit 1
rm -f "$TEMP_REC"

update_waybar

nohup wf-recorder -g "$GEOM" -f "$TEMP_REC" >> "$LOG_FILE" 2>&1 &
disown

sleep 0.4
update_waybar
