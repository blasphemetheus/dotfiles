#!/usr/bin/env bash
makoctl mode -t dnd
if makoctl mode | grep -q dnd; then
    makoctl mode -r dnd
    notify-send "Notifications" "DND enabled" -t 1500
    sleep 0.5
    makoctl mode -a dnd
else
    notify-send "Notifications" "DND disabled" -t 1500
fi
