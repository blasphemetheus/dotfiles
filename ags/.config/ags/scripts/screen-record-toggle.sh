#!/bin/bash
# Toggle screen recording with wf-recorder

RECORDINGS_DIR="$HOME/Videos/Recordings"
mkdir -p "$RECORDINGS_DIR"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    # Stop recording
    pkill -SIGINT wf-recorder
    notify-send "Recording Stopped" "Saved to $RECORDINGS_DIR"
else
    # Start recording
    FILENAME="$RECORDINGS_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"
    wf-recorder -f "$FILENAME" &
    notify-send "Recording Started" "Saving to $FILENAME"
fi
