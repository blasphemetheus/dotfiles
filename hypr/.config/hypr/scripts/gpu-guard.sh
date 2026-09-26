#!/usr/bin/env bash
# gpu-guard.sh — run a command only when the GPU is not held by someone else's
# compute job; otherwise defer the whole unit and try again later.
#
#   gpu-guard.sh UNIT [--defer 24h] -- COMMAND [ARGS...]
#
# Why (2026-09-26): an ExPhil CUDA diagnostic died on a workspace OOM fifty
# seconds after the hourly notification digest loaded a 6 GB Ollama model.
# Anything scheduled that might touch the GPU should yield to a live training
# run, not race it. "Busy" = nvidia-smi lists a compute process that is not
# Ollama's own runner (a resident model is not a job; a beam.smp is).
#
# When busy: schedule `systemctl --user start UNIT.service` after --defer
# (default 24h) via a transient timer named UNIT-deferred, replacing any
# earlier one, and exit 0 so the unit stays clean. The deferred start runs
# this guard again, so a GPU that is still busy tomorrow defers again — and
# so on. When free: exec COMMAND in place.
#
# GPU_GUARD_DRY_RUN=1 prints what it would schedule instead of scheduling.

set -uo pipefail

unit=${1:?usage: gpu-guard.sh UNIT [--defer 24h] -- COMMAND...}
shift
defer=24h
if [ "${1:-}" = "--defer" ]; then defer=$2; shift 2; fi
[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "gpu-guard: no command given" >&2; exit 2; }

busy=0
if command -v nvidia-smi >/dev/null 2>&1; then
  busy=$(nvidia-smi --query-compute-apps=process_name --format=csv,noheader 2>/dev/null \
           | grep -v -i 'ollama' | grep -c . || true)
fi

if [ "${busy:-0}" -gt 0 ]; then
  msg="GPU held by $busy compute process(es); deferring $unit by $defer"
  echo "gpu-guard: $msg" >&2
  if [ "${GPU_GUARD_DRY_RUN:-0}" = "1" ]; then
    echo "gpu-guard: DRY RUN — would: systemd-run --user --on-active=$defer --unit ${unit}-deferred systemctl --user start $unit.service" >&2
    exit 0
  fi
  systemctl --user stop "${unit}-deferred.timer" >/dev/null 2>&1 || true
  systemd-run --user --on-active="$defer" --unit "${unit}-deferred" --collect \
    --description "Deferred $unit (GPU was busy)" \
    systemctl --user start "$unit.service" >/dev/null 2>&1 \
    || echo "gpu-guard: could not schedule the deferred start" >&2
  command -v notify-send >/dev/null 2>&1 && \
    notify-send -a gpu-guard -u low "$unit deferred" "$msg" -t 6000 2>/dev/null
  exit 0
fi

exec "$@"
