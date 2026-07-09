#!/usr/bin/env bash
# Monitor for nvidia-modeset DIFR soft lockup signature.
# Logs to ~/.local/share/difr-monitor/ and notifies on hit.
set -euo pipefail

LOG_DIR="$HOME/.local/share/difr-monitor"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/monitor.log"
HITS="$LOG_DIR/hits.log"

echo "[$(date -Iseconds)] monitor started, watching journal for DIFR/soft-lockup signatures" | tee -a "$LOG"

journalctl -kf --since now | while IFS= read -r line; do
  if echo "$line" | grep -qE "nvDIFR|DifrPrefetch|soft lockup.*nvidia-modeset"; then
    ts="$(date -Iseconds)"
    echo "[$ts] HIT: $line" | tee -a "$LOG" "$HITS"
    notify-send -u critical "DIFR lockup signature detected" "$line" || true
    journalctl -k --since "5 min ago" > "$LOG_DIR/trace-$ts.txt"
  fi
done
