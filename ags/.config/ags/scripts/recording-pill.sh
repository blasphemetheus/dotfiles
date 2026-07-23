#!/usr/bin/env bash
# recording-pill.sh — state source for the AGS recording pill.
# Prints "<style>|<label>":   recording|⏺  REC  0:23   or   hidden|
# Source of truth is `pgrep wf-recorder`; elapsed comes from the start-epoch
# stamp screen-record-toggle.sh writes to $STATE. Mirrors dictation-pill.sh.
set -u
ST="${XDG_RUNTIME_DIR:-/tmp}/screen-record"
STATE="$ST/state"
mkdir -p "$ST"
[ -e "$STATE" ] || : > "$STATE"

if pgrep -x wf-recorder >/dev/null 2>&1; then
    start=$(cat "$STATE" 2>/dev/null)
    now=$(date +%s)
    case "$start" in ''|*[!0-9]*) start=$now ;; esac   # missing/garbage → now
    s=$(( now - start ))
    [ "$s" -lt 0 ] && s=0
    printf 'recording|⏺  REC  %d:%02d\n' $((s/60)) $((s%60))
else
    [ -s "$STATE" ] && : > "$STATE"   # clear a stale stamp
    echo "hidden|"
fi
