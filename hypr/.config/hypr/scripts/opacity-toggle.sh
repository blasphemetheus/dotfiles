#!/usr/bin/env bash
# Toggle between transparent and fully opaque mode.
# Hyprland side: lua/opacity.lua declares the six window rules from a mode
# name; we persist the mode and re-apply it live via `hyprctl eval` (the
# legacy version swapped a `source =` symlink and reloaded the whole config).
STATE_DIR="$HOME/.local/state/hypr"
STATE_FILE="$STATE_DIR/opacity"
WAYBAR_DIR="$HOME/.config/waybar"
KITTY_OVERRIDE="$HOME/.config/kitty/opacity-override.conf"
mkdir -p "$STATE_DIR"

current=$(cat "$STATE_FILE" 2>/dev/null || echo opaque)
if [ "$current" = "opaque" ]; then
    mode=transparent; label="Transparent mode"; kitty_op=0.82; css=style-transparent.css
else
    mode=opaque; label="Opaque mode"; kitty_op=1.0; css=style-opaque.css
fi

echo "$mode" > "$STATE_FILE"
cp "$WAYBAR_DIR/$css" "$WAYBAR_DIR/style.css"
echo "background_opacity $kitty_op" > "$KITTY_OVERRIDE"
for sock in /tmp/kitty-*; do
    kitty @ --to "unix:${sock}" set-background-opacity "$kitty_op" 2>/dev/null
done
pkill waybar; sleep 0.3; waybar &disown
hyprctl eval "opacity.apply('$mode')"
notify-send "Opacity" "$label" -t 1500
