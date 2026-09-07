#!/usr/bin/env bash
# One random quote, same pipeline as the tuigreet launcher (configuration.nix
# greeterLaunch), so the lock screen and the greeter draw from one file.
# /etc/greeter/quotes.txt is installed by environment.etc; the dotfiles copy
# is the fallback until the next rebuild.
set -u
f=/etc/greeter/quotes.txt
[[ -r $f ]] || f="$HOME/dotfiles/greeter/quotes.txt"
[[ -r $f ]] || exit 0
grep -Ev '^[[:space:]]*(#|$)' "$f" | shuf -n 1 | fold -s -w 72
