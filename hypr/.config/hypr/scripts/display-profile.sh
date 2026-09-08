#!/usr/bin/env bash
# rofi picker over hyprdisplays profiles (Super+Ctrl+D). Profiles are saved
# from the hyprdisplays GUI (Super+Shift+M) or `hyprdisplays --save-profile NAME`.
set -u
command -v hyprdisplays >/dev/null || { notify-send "Displays" "hyprdisplays not installed (rebuild NixOS)" -t 3000; exit 1; }
list=$(hyprdisplays --list-profiles)
[[ -n $list ]] || { notify-send "Displays" "no profiles saved yet" -t 3000; exit 0; }
choice=$(printf '%s\n' "$list" | rofi -dmenu -i -p "Display profile")
[[ -n $choice ]] || exit 0
if out=$(hyprdisplays --apply "$choice" 2>&1); then
    notify-send "Displays" "$out" -t 3000
else
    notify-send "Displays" "failed: $out" -t 5000
fi
