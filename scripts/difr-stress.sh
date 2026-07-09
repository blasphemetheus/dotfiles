#!/usr/bin/env bash
# Best-effort attempt to trigger DIFR-related hangs by cycling display
# between idle and active states. NOT guaranteed to reproduce.
set -euo pipefail

LOG="$HOME/.local/share/difr-monitor/stress.log"
mkdir -p "$(dirname "$LOG")"

ITERATIONS="${1:-50}"
IDLE_SECS="${2:-45}"
ACTIVE_SECS="${3:-10}"

echo "[$(date -Iseconds)] stress: $ITERATIONS iters, idle=${IDLE_SECS}s active=${ACTIVE_SECS}s" | tee -a "$LOG"

for i in $(seq 1 "$ITERATIONS"); do
  echo "[$(date -Iseconds)] iter $i: dpms off" | tee -a "$LOG"
  hyprctl dispatch dpms off >/dev/null
  sleep "$IDLE_SECS"

  echo "[$(date -Iseconds)] iter $i: dpms on" | tee -a "$LOG"
  hyprctl dispatch dpms on >/dev/null
  sleep "$ACTIVE_SECS"
done

echo "[$(date -Iseconds)] stress complete" | tee -a "$LOG"
