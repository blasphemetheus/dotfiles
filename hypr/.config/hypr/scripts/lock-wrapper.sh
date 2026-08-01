#!/usr/bin/env bash
# Lock the screen and KEEP it locked until a clean unlock.
#
# Two failure modes this absorbs:
#
# 1. Concurrent launch. `loginctl lock-session` is session-wide, so every
#    hypridle answering it races on "is hyprlock running yet?". The flock
#    serialises that check-then-act so only one manager ever runs.
#
# 2. hyprlock 0.9.2 crashing on teardown (CShader dtor vs. the async asset
#    thread — six coredumps on 2026-07-17/18). Hyprland keeps the session
#    lock; with misc:allow_session_lock_restore = true (hyprland.conf) a
#    respawned hyprlock attaches to it, so we just relaunch. Without the
#    respawn you get the "oopsie daisy" screen and a trip to another TTY.
#
# Exit 0 from hyprlock means the user typed their password — done. Anything
# else is a crash; retry a few times, then give up and leave it to `lockfix`.

# Per-compositor lock file: with two Hyprland instances up (the tty2-escape
# scenario), a global one would let instance A's lockscreen block instance B's.
exec 9>"/tmp/hyprlock-${HYPRLAND_INSTANCE_SIGNATURE:-global}.lock"
flock -n 9 || exit 0            # another wrapper already owns the lockscreen
# Only bail if THIS instance's hyprlock is up — a global pidof lets another
# instance's lock block our respawn (two-instance scenario, 2026-08-01).
for p in $(pgrep -x hyprlock); do
    grep -qz "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" \
        "/proc/$p/environ" 2>/dev/null && exit 0
done

LEDCTL=~/.config/hypr/scripts/led-ctl.sh
"$LEDCTL" lock-off              # LEDs dark while locked; saved state untouched

for _ in 1 2 3 4 5; do
    hyprlock && { "$LEDCTL" apply; exit 0; }    # clean unlock — restore LEDs
    sleep 0.5                   # crashed — let the compositor settle, respawn
done
"$LEDCTL" apply
exit 1
