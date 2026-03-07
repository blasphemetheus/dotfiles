#!/bin/bash
# Show keybinds cheatsheet in rofi (toggle)

# If rofi is running, kill it and exit
if pkill -x rofi; then
    exit 0
fi

KEYBINDS_FILE="$HOME/.config/hypr/keybinds.md"

if [[ ! -f "$KEYBINDS_FILE" ]]; then
    notify-send "Keybinds" "keybinds.md not found!"
    exit 1
fi

# Extract table rows, filter out headers and separators, format for rofi
cat "$KEYBINDS_FILE" | \
    grep -E "^\|.+\|.+\|$" | \
    grep -v "^|[-[:space:]]*|[-[:space:]]*|$" | \
    grep -v "| Key | Action |" | \
    grep -v "| Shortcut | Action |" | \
    sed 's/^| *//' | \
    sed 's/ *|$//' | \
    sed 's/ *| */ → /' | \
    rofi -dmenu -i -p "⌨ Keybinds" -theme-str 'window {width: 60%;}' -no-custom
