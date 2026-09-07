#!/usr/bin/env bash
# Revive the ASUS VG27V after S3 resume. Post-suspend the HDMI link won't
# train at 165Hz from a cold state (panel says "HDMI no signal" while the GPU
# claims the output is live), but it syncs at 60Hz — so wake, sync low, then
# step back up. Verified 2026-07-12: connector cycling alone leaves the panel
# half-awake; this bounce is what brings the picture back.
# Lua config: `hyprctl keyword` is gone, so the mode is re-issued with hl.monitor.
ASUS='desc:ASUSTek COMPUTER INC ASUS VG27V 0x0003ABEC'
hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
sleep 1
hyprctl eval "hl.monitor({ output = '$ASUS', mode = '1920x1080@60', position = '0x0', scale = 1 })"
sleep 2
# Restore the 120Hz config default (165Hz is opt-in via Super+Shift+F /
# refresh-toggle.sh; re-toggle after resume if you were at 165).
hyprctl eval "hl.monitor({ output = '$ASUS', mode = '1920x1080@120', position = '0x0', scale = 1, vrr = 1 })"
