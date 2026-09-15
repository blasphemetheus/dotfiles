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
HDMI_SINK='alsa_output.pci-0000_01_00.1.hdmi-stereo'   # NVIDIA HDMI audio (pw-cli ls Node)
HDMI_CARD='alsa_card.pci-0000_01_00.1'                  # WirePlumber keeps its profile "off" (configuration.nix)
SINK_STATE="$HOME/.local/state/hypr/mirror-prev-sink"

# PipeWire-only (no pactl here): names are stable, ids are not.
default_sink() { wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -oP 'node\.name = "\K[^"]+'; }
set_sink() {   # $1 = node.name
    local id
    id=$(pw-dump 2>/dev/null | jq -r --arg n "$1" '.[] | select(.info.props["node.name"] == $n) | .id' | head -1)
    [[ -n $id ]] && wpctl set-default "$id"
}
hdmi_profile() {   # $1 = profile name (off / output:hdmi-stereo); waits for the sink on enable
    local id idx
    id=$(pw-dump 2>/dev/null | jq -r --arg n "$HDMI_CARD" '.[] | select(.info.props["device.name"] == $n) | .id' | head -1)
    [[ -n $id ]] || return 1
    idx=$(pw-dump "$id" | jq -r --arg p "$1" '.[0].info.params.EnumProfile[] | select(.name == $p) | .index')
    wpctl set-profile "$id" "$idx"
    if [[ $1 != off ]]; then
        for _ in $(seq 20); do
            pw-dump 2>/dev/null | jq -e --arg n "$HDMI_SINK" '.[] | select(.info.props["node.name"] == $n)' >/dev/null && return 0
            sleep 0.1
        done
    fi
}

mons=$(hyprctl monitors all -j)
tv=$(jq -r --arg d "$TV_DESC" '.[] | select(.description == $d) | .name' <<<"$mons")
if [[ -z $tv ]]; then
    # TV unplugged while mirroring: still hand audio back, or every app that
    # follows the default sink stays silent on the dead HDMI output.
    if [[ -s $SINK_STATE ]]; then
        set_sink "$(cat "$SINK_STATE")"; rm -f "$SINK_STATE"; hdmi_profile off
        notify-send "Mirror" "TV not connected, audio restored" -t 3000
        exit 0
    fi
    notify-send "Mirror" "TV not connected (HDMI)" -t 3000
    exit 1
fi
mirror_of=$(jq -r --arg n "$tv" '.[] | select(.name == $n) | .mirrorOf' <<<"$mons")

rule() {  # $1 = mirror target ('none' to extend)
    hyprctl eval "hl.monitor({ output = 'desc:$TV_DESC', mode = '$TV_MODE', position = '$TV_POS', scale = 1, mirror = '$1' })" >/dev/null
}

if [[ $mirror_of != none ]]; then
    rule none
    # audio back to whatever was default before mirroring
    if [[ -s $SINK_STATE ]]; then set_sink "$(cat "$SINK_STATE")"; rm -f "$SINK_STATE"; fi
    hdmi_profile off
    notify-send "Mirror" "TV back to extended desktop, audio restored" -t 3000
else
    src=$(jq -r '.[] | select(.focused == true) | .name' <<<"$mons")
    if [[ -z $src || $src == "$tv" ]]; then
        src=$(jq -r --arg n "$tv" '[.[] | select(.name != $n and .disabled == false)][0].name // empty' <<<"$mons")
    fi
    [[ -n $src ]] || { notify-send "Mirror" "No monitor to mirror" -t 3000; exit 1; }
    rule "$src"
    # audio to the TV, remembering the current default sink for the way back
    mkdir -p "$(dirname "$SINK_STATE")"
    default_sink > "$SINK_STATE"
    hdmi_profile output:hdmi-stereo
    set_sink "$HDMI_SINK"
    notify-send "Mirror" "TV mirroring $src, audio via HDMI" -t 3000
fi
