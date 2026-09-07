#!/usr/bin/env bash
# Mute button label from the default PipeWire sink.
if wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED; then
    echo "󰝟  Muted"
else
    echo "󰕾  Sound"
fi
