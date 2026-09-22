#!/usr/bin/env bash
# dnd-smart.sh — DND with a digest: everything dnd-toggle.sh does, plus
# starting/stopping the hourly notif-digest.timer with the mode. DND ON starts
# the timer; DND OFF stops it and flushes whatever accumulated into one digest
# (backgrounded, so the toggle stays instant).
#
# The timer deliberately has no Install.WantedBy (home.nix) — DND state is the
# only owner, so there's no enable-state to drift across reboots.

set -uo pipefail
S="$(dirname "$0")"

"$S/dnd-toggle.sh"

if makoctl mode | grep -q dnd; then
    systemctl --user start notif-digest.timer 2>/dev/null || true
else
    systemctl --user stop notif-digest.timer 2>/dev/null || true
    "$S/notif-digest.sh" >/dev/null 2>&1 &
fi
