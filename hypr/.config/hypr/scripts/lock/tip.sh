#!/usr/bin/env bash
# "Did you know" — one random keybind from keybinds.md (cmd[update:0], so one
# tip per lock). Table rows look like "| Super+L | Lock screen (hyprlock) |".
set -u
f="$HOME/.config/hypr/keybinds.md"
[[ -r $f ]] || exit 0
grep -E '^\| [^|-][^|]* \| [^|]+ \|' "$f" | grep -vE '^\| *Key *\|' | shuf -n 1 \
  | awk -F' \\| ' '{ gsub(/^\| /, "", $1); gsub(/ \|$/, "", $2); printf "󰌌  %s  →  %s\n", $1, $2 }' \
  | cut -c1-110
