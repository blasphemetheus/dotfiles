#!/bin/bash
# Toggle screen recording with wf-recorder

RECORDINGS_DIR="$HOME/Videos/Recordings"
mkdir -p "$RECORDINGS_DIR"

# State shared with recording-pill.sh (the floating AGS indicator):
#   state → start epoch (drives the pill + its timer)
#   file  → path of the in-progress recording (so stop knows what to rename)
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/screen-record"
STATE="$STATE_DIR/state"
FILEREF="$STATE_DIR/file"
mkdir -p "$STATE_DIR"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    # Stop recording
    pkill -SIGINT wf-recorder
    : > "$STATE"                       # clear stamp → pill hides immediately
    REC=$(cat "$FILEREF" 2>/dev/null)
    : > "$FILEREF"
    # wf-recorder writes the mp4 trailer on SIGINT then exits — wait (≤5s) for it
    # to fully release the file before renaming, or we'd move a truncated clip.
    for _ in $(seq 1 25); do pgrep -x wf-recorder >/dev/null 2>&1 || break; sleep 0.2; done
    if [ -n "$REC" ] && [ -f "$REC" ]; then
        # Ask for a name; Esc / empty keeps the timestamped filename.
        NAME=$(printf '' | rofi -dmenu -l 0 -p "Name recording (Esc = keep timestamp)" 2>/dev/null)
        SAFE=$(printf '%s' "$NAME" | tr -cd '[:alnum:] ._-' | tr ' ' '_')
        if [ -n "$SAFE" ]; then
            DEST="$RECORDINGS_DIR/$SAFE.mp4"
            mv -n "$REC" "$DEST" && REC="$DEST"
        fi
        notify-send "Recording Saved" "$(basename "$REC")"
    else
        notify-send "Recording Stopped" "Saved to $RECORDINGS_DIR"
    fi
else
    # Start recording on the focused monitor. wf-recorder records ONE output;
    # with multiple monitors and no -o it prompts interactively and dies when
    # launched from a button, so we resolve the focused output explicitly.
    OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    if [ -z "$OUTPUT" ]; then
        notify-send "Recording Failed" "Could not determine focused monitor"
        exit 1
    fi
    FILENAME="$RECORDINGS_DIR/recording_$(date +%Y%m%d_%H%M%S).mp4"
    # --audio with no device = the default sink's monitor (what you hear)
    wf-recorder --audio -o "$OUTPUT" -f "$FILENAME" &
    date +%s > "$STATE"                # stamp start → pill appears + times
    printf '%s' "$FILENAME" > "$FILEREF"   # remember what to rename on stop
    # Only claim success if wf-recorder actually stayed alive.
    sleep 0.5
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        notify-send "Recording Started" "$OUTPUT → $FILENAME"
    else
        : > "$STATE"                   # died → don't leave a phantom pill
        : > "$FILEREF"
        notify-send "Recording Failed" "wf-recorder exited immediately"
    fi
fi
