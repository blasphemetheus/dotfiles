#!/usr/bin/env bash
# command-pill.sh — state source for the AGS CommandPill widget.
# Prints "<style>|<label>" for voice-command.sh's state file
# ($XDG_RUNTIME_DIR/voice-command/state, format "<style>|<label>|<epoch>").
# listening gets a m:ss timer (from the state file's epoch); done/error flash
# for 3s then go hidden. Labels must not contain "|" (the TSX splits on it).

set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voice-command/state"
[ -f "$STATE" ] || { echo "hidden|"; exit 0; }

IFS='|' read -r style label epoch < "$STATE"
now=$(date +%s)
age=$(( now - ${epoch:-$now} ))

case "$style" in
  listening)
    printf 'listening|● Listening… %d:%02d\n' $((age / 60)) $((age % 60))
    ;;
  transcribing|thinking)
    printf '%s|%s\n' "$style" "$label"
    ;;
  done|error)
    if [ "$age" -le 3 ]; then
      printf '%s|%s\n' "$style" "$label"
    else
      echo "hidden|"
    fi
    ;;
  *)
    echo "hidden|"
    ;;
esac
