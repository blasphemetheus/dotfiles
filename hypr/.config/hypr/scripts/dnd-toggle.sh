#!/usr/bin/env bash
# dnd-toggle.sh — the dumb DND primitive: flips mako's dnd mode and toasts.
# Callers that want the hourly LLM digest while DND is on should use
# dnd-smart.sh instead (Super+Shift+D, waybar custom/dnd on-click, and the
# voice router all point there). This script stays for lock screens and
# anything that must not touch systemd.

makoctl mode -t dnd
if makoctl mode | grep -q dnd; then
    makoctl mode -r dnd
    notify-send "Notifications" "DND enabled" -t 1500
    sleep 0.5
    makoctl mode -a dnd
else
    notify-send "Notifications" "DND disabled" -t 1500
fi

# Instant waybar custom/dnd flip (signal 10; its 2s poll is the fallback for
# mako restarts and direct `makoctl mode` calls).
pkill -RTMIN+10 waybar 2>/dev/null || true
