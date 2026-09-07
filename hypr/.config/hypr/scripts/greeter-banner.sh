#!/usr/bin/env bash
# The greeter's ASCII banner with its common left indent removed, so hyprlock
# can centre the block without the tuigreet-specific padding shifting it.
set -u
f=/etc/greeter/banner.txt
[[ -r $f ]] || f="$HOME/dotfiles/greeter/banner.txt"
[[ -r $f ]] || exit 0
awk '
  { lines[NR] = $0 }
  /[^ ]/ { match($0, /^ */); if (min == "" || RLENGTH < min) min = RLENGTH }
  END { for (i = 1; i <= NR; i++) print substr(lines[i], min + 1) }
' "$f"
