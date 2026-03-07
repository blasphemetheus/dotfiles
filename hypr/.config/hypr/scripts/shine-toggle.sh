#!/bin/bash
# Toggle cursor between normal and Falco shine

STATE_FILE="/tmp/shine-cursor-active"
SHINE_THEME="falco-shine"
NORMAL_THEME="Adwaita"

# Play a sound effect (optional, comment out if annoying)
play_shine_sound() {
    # Quick beep to mimic the shine sound
    (speaker-test -t sine -f 800 -l 1 2>/dev/null & sleep 0.05; kill $! 2>/dev/null) &
}

if [ -f "$STATE_FILE" ]; then
    # Switch back to normal
    rm "$STATE_FILE"
    hyprctl setcursor "$NORMAL_THEME" 24
    notify-send -t 1000 -u low "Shine OFF" "Cursor: $NORMAL_THEME"
else
    # Switch to shine
    touch "$STATE_FILE"
    hyprctl setcursor "$SHINE_THEME" 64
    play_shine_sound
    notify-send -t 1000 -u low "SHINE!" "Blip blip!"
fi
