#!/usr/bin/env bash
# vocab-add.sh "wrong hearing" "correct term" — teach the dictation daemon a word.
#
# Appends one entry to word_overrides in hyprwhspr-rs' config.jsonc (the repo
# file, which is ALSO the live file via home.nix's mkOutOfStoreSymlink) and
# restarts the daemon — it has no CLI/socket, so config only reloads on restart
# (see the config's own header comment).
#
# The replacement is case-insensitive whole-word at injection time. It is the
# ONLY post-processing allowed on transcripts (2026-09-21): a fixed mapping you
# can read and audit, never an LLM rewrite — verbatim dictation or bust.
#
# JSONC append is the weak link here (comments make jq useless for writing), so:
# double anchor (word_overrides closer must be followed by "transcription"),
# pre-edit .bak, post-edit check that the diff is EXACTLY our one added line,
# restore on ANY failure.

set -euo pipefail

CONFIG="$HOME/dotfiles/hyprwhspr/.config/hyprwhspr-rs/config.jsonc"

die() { notify-send -a vocab -u critical "✕ vocab-add" "$1" -t 4000 2>/dev/null || true; echo "vocab-add: $1" >&2; exit 1; }

from="${1:-}"; to="${2:-}"
[ -n "$from" ] && [ -n "$to" ] || die "usage: vocab-add.sh \"wrong hearing\" \"correct term\""
[ "$from" = "$(printf '%s' "$from" | tr 'A-Z' 'a-z')" ] || die "the misheard term must be lowercase (matching is case-insensitive anyway)"
[ -f "$CONFIG" ] || die "config not found at $CONFIG"
grep -qF "\"$from\":" "$CONFIG" && die "\"$from\" is already in word_overrides"

# JSON-escape both terms (jq -R reads raw, emits a quoted JSON string).
from_json=$(printf '%s' "$from" | jq -R .)
to_json=$(printf '%s' "$to" | jq -R .)

cp "$CONFIG" "$CONFIG.bak"

# Insert "from": "to", before the closing brace of word_overrides. The closer
# is the first `  },` after the block opens, and the next non-blank line after
# it MUST be "transcription" — otherwise the file shape changed and we abort
# rather than corrupt it.
awk -v entry="    $from_json: $to_json," '
  /^  "word_overrides": \{/ { inblock=1 }
  inblock && /^  \},/ && !done {
    # peek: next non-blank line must be "transcription" (replay any blanks)
    skipped = ""
    ok = 0
    while ((getline nextline) > 0) {
      if (nextline ~ /^[[:space:]]*$/) { skipped = skipped nextline ORS; continue }
      if (nextline ~ /^  "transcription": \{/) ok = 1
      break
    }
    if (!ok) exit 42
    print entry
    print "  },"
    printf "%s", skipped
    print nextline
    done=1
    inblock=0
    next
  }
  { print }
  END { if (!done) exit 42 }
' "$CONFIG.bak" > "$CONFIG" || { mv "$CONFIG.bak" "$CONFIG"; die "could not find the word_overrides block anchor — file unchanged"; }

# Integrity check: the edit must be EXACTLY one added line — our entry, nothing
# removed or reordered. (A full JSONC parse check would need a real JSONC
# parser; the diff check is stricter about what matters here.)
# NB: capture diff's output first — under `set -o pipefail`, `diff | grep`
# always fails because diff exits 1 when files differ, even when grep matches.
d=$(diff "$CONFIG.bak" "$CONFIG" || true)
ok=1
grep -q "^> .*$from_json: $to_json," <<< "$d" || ok=0
[ "$(grep -c '^> ' <<< "$d")" = "1" ] || ok=0
[ "$(grep -c '^< ' <<< "$d")" = "0" ] || ok=0
if [ "$ok" != "1" ]; then
  mv "$CONFIG.bak" "$CONFIG"
  die "edit was not a clean one-line insertion — restored backup, file unchanged"
fi
rm -f "$CONFIG.bak"

systemctl --user restart hyprwhspr-rs || die "entry added, but daemon restart failed — run: systemctl --user restart hyprwhspr-rs"

notify-send -a vocab -h string:x-canonical-private-synchronous:vocab \
  "✓ vocabulary" "\"$from\" → $to (daemon restarted)" -t 2500 2>/dev/null || true
echo "added: \"$from\" → \"$to\""
