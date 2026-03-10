#!/usr/bin/env bash
# Toggle between transparent and fully opaque mode

STATE_FILE="/tmp/.hypr-opacity-mode"
HYPR_DIR="$HOME/.config/hypr"
WAYBAR_DIR="$HOME/.config/waybar"
KITTY_OVERRIDE="$HOME/.config/kitty/opacity-override.conf"

if [ -f "$STATE_FILE" ]; then
    # Currently opaque — switch back to transparent
    rm "$STATE_FILE"
    ln -sf "$HYPR_DIR/opacity-transparent.conf" "$HYPR_DIR/opacity-active.conf"
    cp "$WAYBAR_DIR/style-transparent.css" "$WAYBAR_DIR/style.css"
    # Kitty: remove override, restore existing windows
    echo "background_opacity 0.82" > "$KITTY_OVERRIDE"
    for sock in /tmp/kitty-*; do
        kitty @ --to "unix:${sock}" set-background-opacity 0.82 2>/dev/null
    done
    pkill waybar; sleep 0.3; waybar &disown
    hyprctl reload
    notify-send "Opacity" "Transparent mode" -t 1500
else
    # Currently transparent — switch to fully opaque
    touch "$STATE_FILE"
    ln -sf "$HYPR_DIR/opacity-opaque.conf" "$HYPR_DIR/opacity-active.conf"
    cp "$WAYBAR_DIR/style-opaque.css" "$WAYBAR_DIR/style.css"
    # Kitty: set override, update existing windows
    echo "background_opacity 1.0" > "$KITTY_OVERRIDE"
    for sock in /tmp/kitty-*; do
        kitty @ --to "unix:${sock}" set-background-opacity 1.0 2>/dev/null
    done
    pkill waybar; sleep 0.3; waybar &disown
    hyprctl reload
    notify-send "Opacity" "Opaque mode" -t 1500
fi
