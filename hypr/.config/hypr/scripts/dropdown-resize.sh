#!/usr/bin/env bash
# Toggle dropdown terminal - spawns or shows/hides a floating kitty at the top

ADDR=$(hyprctl clients -j | grep -B5 '"class":"dropdown"' | grep -o '"address":"[^"]*"' | tail -1 | cut -d'"' -f4)

if [ -z "$ADDR" ]; then
    # No dropdown exists, spawn one
    kitty --class dropdown &
    sleep 0.5
    ADDR=$(hyprctl clients -j | grep -B5 '"class":"dropdown"' | grep -o '"address":"[^"]*"' | tail -1 | cut -d'"' -f4)
fi

if [ -n "$ADDR" ]; then
    W=$(hyprctl monitors -j | grep -o '"width":[0-9]*' | head -1 | cut -d: -f2)
    H=$(hyprctl monitors -j | grep -o '"height":[0-9]*' | head -1 | cut -d: -f2)
    DH=$((H * 40 / 100))
    hyprctl --batch "\
        dispatch resizewindowpixel exact ${W} ${DH},address:${ADDR} ;\
        dispatch movewindowpixel exact 0 0,address:${ADDR}"
fi
