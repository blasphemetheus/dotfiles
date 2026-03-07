#!/bin/bash
# Keyboard backlight indicator for waybar

DEVICE="/sys/class/leds/tpacpi::kbd_backlight"

get_brightness() {
    cat "$DEVICE/brightness"
}

get_max() {
    cat "$DEVICE/max_brightness"
}

# Toggle through brightness levels
if [ "$1" = "toggle" ]; then
    current=$(get_brightness)
    max=$(get_max)
    next=$(( (current + 1) % (max + 1) ))
    echo "$next" | tee "$DEVICE/brightness" > /dev/null 2>&1 || \
        echo "$next" | sudo tee "$DEVICE/brightness" > /dev/null
    exit 0
fi

# Display current state
brightness=$(get_brightness)
max=$(get_max)

if [ "$brightness" -eq 0 ]; then
    echo "⌨️"  # Off
elif [ "$brightness" -eq "$max" ]; then
    echo "⌨️💡"  # Max
else
    echo "⌨️🔅"  # Mid
fi
