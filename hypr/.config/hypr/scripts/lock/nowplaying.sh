#!/usr/bin/env bash
# "▶ Artist — Title" for the lock screen (cmd[update:2000]); nothing when idle.
set -u
m=$(playerctl metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null) || exit 0
IFS='|' read -r st ar ti <<<"$m"
[[ -n $ti ]] || exit 0
case $st in Playing) i="󰐊" ;; Paused) i="󰏤" ;; *) exit 0 ;; esac
printf '%s  %s%s\n' "$i" "${ar:+$ar — }" "${ti:0:60}"
