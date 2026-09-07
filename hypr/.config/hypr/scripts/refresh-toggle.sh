#!/usr/bin/env bash
# Toggle ASUS VG27V between stable 120Hz (default) and max 165Hz.
# 165Hz over HDMI is bandwidth-marginal on this link (see hdmi-wake.sh),
# so 120 is the daily driver; flip up only when you want it.
# Direction comes from the live rate, not a state file, so it can't drift
# when hyprctl reload resets the mode back to the 120Hz config default.
ASUS='desc:ASUSTek COMPUTER INC ASUS VG27V 0x0003ABEC'
rate=$(hyprctl -j monitors | jq -r '.[] | select(.name=="HDMI-A-1") | .refreshRate')
if (( $(printf '%.0f' "$rate") > 150 )); then
    hyprctl eval "hl.monitor({ output = '$ASUS', mode = '1920x1080@120', position = '0x0', scale = 1, vrr = 1 })"
    notify-send "Refresh rate" "120Hz (stable)" -t 5000
else
    hyprctl eval "hl.monitor({ output = '$ASUS', mode = '1920x1080@165', position = '0x0', scale = 1, vrr = 1 })"
    notify-send "Refresh rate" "165Hz (max)" -t 5000
fi
