#!/usr/bin/env bash
# Revive the VY279HGR (DP-2) after a DPMS-off wake or S3 resume.
# Failure mode (2026-09-19): the panel's DP AUX sleeps too deep, the NVIDIA
# driver can't read its EDID on wake and drops the connector; on reconnect
# aquamarine picks the connector up before the mode list is populated and
# the output is stuck at "0x0@60" (kernel rejects the 640x480 fallback).
# Only a kernel-side off→detect bounce makes aquamarine re-read the modes,
# and that needs root: dp-link-bounce.service, allowed via polkit.
# Healthy monitors are left alone, so this is safe to run on every wake.
NAME=DP-2
SYS=$(ls -d /sys/class/drm/card*-$NAME 2>/dev/null | head -1)
[ -n "$SYS" ] || exit 0

healthy() {
    hyprctl monitors all 2>/dev/null \
        | sed -n "/^Monitor $NAME/,/^Monitor /p" \
        | grep -qE '^\s+[1-9][0-9]+x[0-9]+@'
}

# Give dpms-on / resume a moment to bring the link up on its own.
for _ in 1 2 3 4 5 6; do
    healthy && exit 0
    sleep 1
done

# Kernel has no EDID either: the panel is off or its AUX is still asleep;
# a bounce won't help (detect re-probes and still finds nothing).
if [ "$(wc -c < "$SYS/edid")" -eq 0 ]; then
    notify-send "DP-2" "VY279HGR gone and no EDID; power-cycle the monitor" -t 5000
    exit 1
fi

systemctl restart dp-link-bounce.service
for _ in 1 2 3 4 5 6 7 8; do
    sleep 1
    healthy && { notify-send "DP-2" "VY279HGR re-synced (connector bounce)" -t 3000; exit 0; }
done
notify-send "DP-2" "VY279HGR still wedged after bounce" -t 5000
exit 1
