#!/usr/bin/env bash
# Restart Discord when its renderer wedges on the splash spinner.
#
# Failure mode (seen 2026-08-27 after 6d18h uptime across several S3 cycles):
# the main + renderer processes stay alive and the data layer is completely
# healthy — gateway connected, Spotify syncing, module checks logging hourly —
# but the window never repaints past the loading animation. Nothing in the logs
# marks the transition, and Discord runs with no gpu-process here either way
# (true in both XWayland and Wayland mode), so there is no clean liveness probe
# to test. Only uptime correlates, hence the crude age threshold below.
#
#   (no args)      restart now — bound to Super+Shift+K
#   resume-check   restart only if the instance is older than $MAX_AGE
#                  (hypridle after_sleep_cmd; a fresh Discord is left alone)
set -u

BIN=/run/current-system/sw/bin/Discord
CFG="$HOME/.config/discord"
MAX_AGE=${DISCORD_MAX_AGE:-43200} # 12h. Only long-lived instances ever wedged;
                                  # raise if resume restarts annoy, lower if it
                                  # recurs.

# Match the executables, NOT the bare string "Discord": a plain `pkill -f
# Discord` also matches any shell, editor or env var that merely mentions it
# (DISCORD_MAX_AGE=1 killed the calling shell while this was being written).
# The wrapper is .../sw/bin/Discord; every child is .../opt/Discord/
# .Discord-wrapped or a /proc/self/exe re-exec that dies with its parent.
DPAT='sw/bin/Discord( |$)|opt/Discord/\.Discord-wrapped'

if [ "${1-}" = "resume-check" ]; then
    pid=$(pgrep -f -o "$DPAT" 2>/dev/null) || exit 0
    [ -n "$pid" ] || exit 0
    age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$age" ] || exit 0
    [ "$age" -gt "$MAX_AGE" ] || exit 0
fi

pgrep -f "$DPAT" >/dev/null 2>&1 || exit 0   # nothing running; don't relaunch

pkill -f "$DPAT" 2>/dev/null || true
for _ in $(seq 1 40); do
    pgrep -f "$DPAT" >/dev/null 2>&1 || break
    sleep 0.25
done
pkill -9 -f "$DPAT" 2>/dev/null || true
sleep 1

# These symlink to the old PID / a /tmp socket dir. Electron normally clears a
# stale lock itself, but a -9'd instance can leave one it will sit and wait on.
rm -f "$CFG/SingletonLock" "$CFG/SingletonCookie" "$CFG/SingletonSocket"

# setsid so it outlives the hypridle/keybind process that invoked us.
setsid "$BIN" </dev/null >/dev/null 2>&1 &
