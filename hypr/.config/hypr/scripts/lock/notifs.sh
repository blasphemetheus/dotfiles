#!/usr/bin/env bash
# Notifications that arrived since the screen was locked (cmd[update:5000]).
# lock-wrapper.sh stamps ~/.local/state/hyprland/lock-start; the persistent
# mako log (home.nix notification-logger) carries epoch times.
set -u
stamp="$HOME/.local/state/hyprland/lock-start"
log="$HOME/.local/state/mako/history.jsonl"
[[ -r $stamp && -r $log ]] || exit 0
since=$(cat "$stamp")
tail -n 500 "$log" | jq -r --argjson s "$since" '
  select(.time > $s) | [.app, .summary] | @tsv' 2>/dev/null | awk -F'\t' '
  { n++; app=$1; sum=$2 }
  END {
    if (n == 0) exit
    if (length(sum) > 40) sum = substr(sum, 1, 39) "…"
    printf "󰂚  %d new · last: [%s] %s\n", n, app, sum
  }'
