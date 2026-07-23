#!/usr/bin/env bash
# Wallpaper changer script for swww
# Usage: wallpaper.sh [next|prev|random|set /path/to/image]

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CURRENT_FILE="$HOME/.cache/current_wallpaper"

# Transition effects (randomly picked)
TRANSITIONS=("grow" "wave" "wipe" "center" "outer" "random")
TRANSITION=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

get_wallpapers() {
    find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" \) 2>/dev/null | sort
}

set_wallpaper() {
    local img="$1"
    if [ -f "$img" ]; then
        swww img "$img" \
            --transition-type "$TRANSITION" \
            --transition-duration 1 \
            --transition-pos center \
            --transition-fps 60
        echo "$img" > "$CURRENT_FILE"
        notify-send "Wallpaper Changed" "$(basename "$img")" -t 2000
        # If RGB LEDs are in wallpaper-sync mode, recolor them to match
        "$HOME/.config/hypr/scripts/led-ctl.sh" wallsync-refresh &

    fi
}

case "$1" in
    next)
        mapfile -t wallpapers < <(get_wallpapers)
        current=$(cat "$CURRENT_FILE" 2>/dev/null)
        idx=0
        for i in "${!wallpapers[@]}"; do
            if [ "${wallpapers[$i]}" = "$current" ]; then
                idx=$(( (i + 1) % ${#wallpapers[@]} ))
                break
            fi
        done
        set_wallpaper "${wallpapers[$idx]}"
        ;;
    prev)
        mapfile -t wallpapers < <(get_wallpapers)
        current=$(cat "$CURRENT_FILE" 2>/dev/null)
        idx=$((${#wallpapers[@]} - 1))
        for i in "${!wallpapers[@]}"; do
            if [ "${wallpapers[$i]}" = "$current" ]; then
                idx=$(( (i - 1 + ${#wallpapers[@]}) % ${#wallpapers[@]} ))
                break
            fi
        done
        set_wallpaper "${wallpapers[$idx]}"
        ;;
    random)
        mapfile -t wallpapers < <(get_wallpapers)
        if [ ${#wallpapers[@]} -gt 0 ]; then
            set_wallpaper "${wallpapers[$RANDOM % ${#wallpapers[@]}]}"
        fi
        ;;
    set)
        if [ -n "$2" ]; then
            set_wallpaper "$2"
        fi
        ;;
    picker)
        # Use rofi to pick wallpaper
        mapfile -t wallpapers < <(get_wallpapers)
        if [ ${#wallpapers[@]} -gt 0 ]; then
            selected=$(printf '%s\n' "${wallpapers[@]}" | xargs -I{} basename {} | rofi -dmenu -p "Wallpaper")
            if [ -n "$selected" ]; then
                for wp in "${wallpapers[@]}"; do
                    if [ "$(basename "$wp")" = "$selected" ]; then
                        set_wallpaper "$wp"
                        break
                    fi
                done
            fi
        fi
        ;;
    *)
        echo "Usage: $0 [next|prev|random|set /path/to/image|picker]"
        ;;
esac
