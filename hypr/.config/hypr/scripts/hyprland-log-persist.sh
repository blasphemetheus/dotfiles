#!/usr/bin/env bash
# Mirror Hyprland's per-instance log to disk. The real log lives on tmpfs
# ($XDG_RUNTIME_DIR/hypr/<sig>/hyprland.log) and is gone after any reboot, so
# a display wedge that ends in the reset button leaves nothing to read — the
# 2026-09-07 HDMI-replug freeze was undiagnosable for exactly that reason.
# Started from hyprland.conf exec-once; keeps the last $KEEP session logs.
set -u
KEEP=10
OUT_DIR="$HOME/.local/state/hyprland"
SRC="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/hyprland.log"

mkdir -p "$OUT_DIR"
ls -1t "$OUT_DIR"/hyprland-*.log 2>/dev/null | tail -n +"$KEEP" | xargs -r rm -f --

# Wait for the file (it exists by the time exec-once runs, but be safe).
for _ in $(seq 1 50); do [[ -f $SRC ]] && break; sleep 0.2; done
[[ -f $SRC ]] || { echo "hyprland-log-persist: no log at $SRC" >&2; exit 1; }

OUT="$OUT_DIR/hyprland-$(date +%F_%H%M%S).log"
ln -sfn "$OUT" "$OUT_DIR/latest.log"
# -n +1 replays what was already written (startup, monitor/connector setup).
exec tail -n +1 -F "$SRC" >> "$OUT"
