#!/usr/bin/env bash
# dictation-pill.sh — state source for the AGS dictation pill (polled ~4x/s).
# Prints "<style>|<label>". Styles map to style.scss classes.
#   listening    ●  Listening…  0:07     (timer = status.json mtime)
#   transcribing ◌  Transcribing…
#   done         ✓  <inserted text>      (flashes ~4s after insertion)
#   error / hidden
set -u
SF="${XDG_CACHE_HOME:-$HOME/.cache}/hyprwhspr-rs/status.json"
ST="${XDG_RUNTIME_DIR:-/tmp}/dictation-pill"
mkdir -p "$ST"

cls=$(jq -r '.class // "unknown"' "$SF" 2>/dev/null)
prev=$(cat "$ST/prev" 2>/dev/null || true)
echo "$cls" > "$ST/prev"
now=$(date +%s)

case "$cls" in
    active)
        # snapshot clipboard at recording start so the done-flash can tell a
        # real insertion (auto_copy_clipboard) from a VAD-discarded blip
        if [ "$prev" != "active" ]; then
            timeout 0.5 wl-paste 2>/dev/null | cksum > "$ST/clip_before" || true
        fi
        start=$(stat -c %Y "$SF" 2>/dev/null || echo "$now")
        s=$(( now - start ))
        printf 'listening|●  Listening…  %d:%02d\n' $((s/60)) $((s%60))
        ;;
    processing)
        echo "transcribing|◌  Transcribing…"
        ;;
    error)
        echo "error|✕  Dictation error"
        ;;
    *)
        if [ "$prev" = "processing" ]; then
            new=$(timeout 0.5 wl-paste 2>/dev/null || true)
            if [ -n "$new" ] && [ "$(printf '%s' "$new" | cksum)" != "$(cat "$ST/clip_before" 2>/dev/null)" ]; then
                printf '%s' "$new" | head -c 90 | tr '\n' ' ' > "$ST/flash_text"
                echo "$now" > "$ST/flash_since"
            fi
        fi
        since=$(cat "$ST/flash_since" 2>/dev/null || echo 0)
        if [ $(( now - since )) -lt 4 ] && [ -s "$ST/flash_text" ]; then
            echo "done|✓  $(cat "$ST/flash_text")"
        else
            echo "hidden|"
        fi
        ;;
esac
