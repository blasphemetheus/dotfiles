#!/bin/bash
current=$(hyprctl getoption cursor:zoom_factor -j 2>/dev/null | grep -oP '"float":\s*\K[0-9.]+' || echo "1")
if [ "$current" = "1.000000" ] || [ "$current" = "1" ]; then
    hyprctl eval 'hl.config({ cursor = { zoom_factor = 2 } })'
else
    hyprctl eval 'hl.config({ cursor = { zoom_factor = 1 } })'
fi
