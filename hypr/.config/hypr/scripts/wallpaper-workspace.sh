#!/usr/bin/env bash
# Set different wallpapers per workspace using swww
# Listens to Hyprland workspace events via IPC socket
#
# Setup: Create folders ~/Pictures/Wallpapers/ws-1, ws-2, etc.
# Each folder should have wallpapers for that workspace.
# Falls back to ~/Pictures/Wallpapers/ if no workspace-specific folder exists.

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/hypr-wallpapers"
TRANSITION_DURATION=1
TRANSITION_FPS=60

mkdir -p "$CACHE_DIR"

get_wallpaper_for_workspace() {
    local ws="$1"
    local ws_dir="$WALLPAPER_DIR/ws-$ws"
    local cache_file="$CACHE_DIR/ws-$ws"

    # Check if workspace-specific directory exists
    if [[ -d "$ws_dir" ]]; then
        # Use cached selection if available, otherwise pick random
        if [[ -f "$cache_file" ]] && [[ -f "$(cat "$cache_file")" ]]; then
            cat "$cache_file"
        else
            local wp
            wp=$(find "$ws_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | shuf -n1)
            if [[ -n "$wp" ]]; then
                echo "$wp" > "$cache_file"
                echo "$wp"
            fi
        fi
    fi
    # No output = no workspace-specific wallpaper, keep current
}

set_wallpaper() {
    local img="$1"
    [[ -z "$img" || ! -f "$img" ]] && return

    local current
    current=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null)
    [[ "$current" == "$img" ]] && return

    swww img "$img" \
        --transition-type fade \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS"
    echo "$img" > "$HOME/.cache/current_wallpaper"
}

# Handle current workspace on start
current_ws=$(hyprctl activeworkspace -j | jq -r '.id' 2>/dev/null)
if [[ -n "$current_ws" ]]; then
    wp=$(get_wallpaper_for_workspace "$current_ws")
    [[ -n "$wp" ]] && set_wallpaper "$wp"
fi

# Listen for workspace changes
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    case "$line" in
        workspace\>\>*)
            ws="${line#workspace>>}"
            wp=$(get_wallpaper_for_workspace "$ws")
            [[ -n "$wp" ]] && set_wallpaper "$wp"
            ;;
    esac
done
