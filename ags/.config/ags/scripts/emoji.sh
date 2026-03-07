#!/bin/bash
# Try various emoji pickers in order of preference
if command -v rofimoji &>/dev/null; then
    rofimoji
elif command -v bemoji &>/dev/null; then
    bemoji
elif command -v wofi &>/dev/null; then
    # Simple wofi emoji picker
    cat /usr/share/unicode/emoji/emoji-test.txt 2>/dev/null | \
        grep -E "^[0-9A-F]" | \
        sed 's/.*# //' | \
        wofi --show dmenu -p "Emoji" | \
        cut -d' ' -f1 | \
        wl-copy
else
    notify-send "No emoji picker found" "Install rofimoji: yay -S rofimoji"
fi
