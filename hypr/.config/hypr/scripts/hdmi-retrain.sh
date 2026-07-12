#!/usr/bin/env bash
# Retrain a wedged HDMI link (ASUS shows "no signal" while the GPU drives it).
# Same fix the hdmi-link-retrain boot service applies before greetd.
hyprctl dispatch dpms off HDMI-A-1
sleep 1
hyprctl dispatch dpms on HDMI-A-1
notify-send "HDMI" "Link retrained on HDMI-A-1" -t 3000
