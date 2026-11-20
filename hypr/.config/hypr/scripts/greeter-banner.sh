#!/usr/bin/env bash
# The greeter's ASCII banner with its common left indent removed, so hyprlock
# can centre the block without the tuigreet-specific padding shifting it.
#
# hyprlock ≥ 0.9.6 trims leading " \n\r\t" from every cmd[] result
# (general:text_trim, default on), which ate the first line's indent and shoved
# the top of the logo left (2026-11-20). A zero-width space (U+200B) in front
# of the first line is not in that set and renders at zero width, so the indent
# survives. Turning text_trim off instead would leave every other panel with a
# trailing blank line.
set -u
f=/etc/greeter/banner.txt
[[ -r $f ]] || f="$HOME/dotfiles/greeter/banner.txt"
[[ -r $f ]] || exit 0
awk '
  { lines[NR] = $0 }
  /[^ ]/ { match($0, /^ */); if (min == "" || RLENGTH < min) min = RLENGTH }
  END { for (i = 1; i <= NR; i++) print (i == 1 ? "\342\200\213" : "") substr(lines[i], min + 1) }
' "$f"
