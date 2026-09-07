#!/usr/bin/env bash
# Toggle mirroring the FOCUSED monitor onto the TV (Super+Shift+T).
# Press once: TV shows a copy of the monitor you're on. Press again: TV goes
# back to being its own extended screen at 3840x0 (lua/monitors.lua).
# Lua config: monitor rules are re-issued with hl.monitor via `hyprctl eval`;
# `mirror = 'none'` is what clears a mirror (omitting the key keeps it).
set -u
TV_DESC='Toshiba America Info Systems Inc TOSHIBA-TV 0x00000001'
TV_MODE='1920x1080@60'
TV_POS='3840x0'

mons=$(hyprctl monitors all -j)
tv=$(jq -r --arg d "$TV_DESC" '.[] | select(.description == $d) | .name' <<<"$mons")
if [[ -z $tv ]]; then
    notify-send "Mirror" "TV not connected (HDMI)" -t 3000
    exit 1
fi
mirror_of=$(jq -r --arg n "$tv" '.[] | select(.name == $n) | .mirrorOf' <<<"$mons")

rule() {  # $1 = mirror target ('none' to extend)
    hyprctl eval "hl.monitor({ output = 'desc:$TV_DESC', mode = '$TV_MODE', position = '$TV_POS', scale = 1, mirror = '$1' })" >/dev/null
}

if [[ $mirror_of != none ]]; then
    rule none
    notify-send "Mirror" "TV back to extended desktop" -t 3000
else
    src=$(jq -r '.[] | select(.focused == true) | .name' <<<"$mons")
    if [[ -z $src || $src == "$tv" ]]; then
        src=$(jq -r --arg n "$tv" '[.[] | select(.name != $n and .disabled == false)][0].name // empty' <<<"$mons")
    fi
    [[ -n $src ]] || { notify-send "Mirror" "No monitor to mirror" -t 3000; exit 1; }
    rule "$src"
    notify-send "Mirror" "TV mirroring $src" -t 3000
fi
