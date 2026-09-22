#!/usr/bin/env bash
# agent-watchers.sh — local-LLM triage of Hyprland errors + post-resume health.
#
# OPT-IN ONLY: this runs under the agent-watchers user service, which has no
# Install section — it's enabled/disabled by agent-watchers-toggle.sh (systemctl
# enable --now), and that enablement IS the persistence across reboots.
#
# Two watchers:
#   1. tail the LIVE tmpfs hyprland.log for [ERR]/[CRITICAL]/crash lines
#      (debounced: <=1 report per 15min, flock against double-report on restart)
#   2. inotify on ~/.local/state/hyprland/last-resume → post-resume health check
#      (hyprctl / pipewire / network), report only on failure
#
# Reports: context is pre-gathered into a file, then `claude -p` writes prose
# with NO tools (empty --allowedTools) against the LOCAL ollama — nothing
# shell-arbitrary runs unattended (same justification as nixos-setup-advisor).
# Quiet-skip when ollama or claude is unavailable: the state log says why.
#
# `set -uo pipefail` but NOT -e: a watcher must not die on one bad command.

set -uo pipefail

STATE_DIR="$HOME/.local/state/agent-watchers"
REPORTS="$STATE_DIR/reports"
LOG="$STATE_DIR/agent-watchers.log"
LAST_REPORT="$STATE_DIR/last-report"
LOCKFILE="$STATE_DIR/report.lock"
DEBOUNCE=900   # seconds between reports, per process + persisted across restarts
mkdir -p "$REPORTS"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$1" >> "$LOG"; }

# --- report job -------------------------------------------------------------
# Owns the ctx file: reads it into memory and deletes it up front, so callers
# can background us without racing our cleanup.
report() {
  local title="$1" ctx="$2"
  (
    flock -n 9 || { rm -f "$ctx"; exit 0; }
    local ctxdata
    ctxdata=$(cat "$ctx" 2>/dev/null) || true
    rm -f "$ctx"
    now=$(date +%s)
    last=0
    [ -f "$LAST_REPORT" ] && last=$(cat "$LAST_REPORT")
    if [ $((now - last)) -lt $DEBOUNCE ]; then
      log "debounced: $title"
      exit 0
    fi

    if ! curl -sf --max-time 2 http://localhost:11434/api/version >/dev/null; then
      log "ollama down — skipped report: $title"
      exit 0
    fi
    claude="$HOME/.nix-profile/bin/claude"
    if [ ! -x "$claude" ]; then
      log "no claude binary — skipped report: $title"
      exit 0
    fi

    date +%s > "$LAST_REPORT"
    tmp=$(mktemp)
    {
      printf 'You are a NixOS/Hyprland triage assistant. A watcher fired: %s\n\n' "$title"
      printf 'Write: (1) one-line summary of what is wrong, (2) most likely cause,\n'
      printf '(3) whether it needs action now or is noise, (4) suggested fix or command.\n'
      printf 'Be terse. Context below.\n\n'
      printf '%s\n' "$ctxdata"
    } > "$tmp"

    ts=$(date '+%Y%m%d-%H%M%S')
    out="$REPORTS/$ts.md"
    timeout 300 env -u ANTHROPIC_API_KEY \
      CLAUDE_CONFIG_DIR="$HOME/.claude-local" \
      ANTHROPIC_BASE_URL="http://localhost:11434" \
      ANTHROPIC_AUTH_TOKEN="ollama" \
      ANTHROPIC_MODEL="qwen3-coder:30b" \
      ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3-coder:30b" \
      ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3-coder:30b" \
      ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3-coder:30b" \
      CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536 \
      DISABLE_TELEMETRY=1 \
      "$claude" -p --allowedTools "" < "$tmp" > "$out" 2>&1 || true
    rm -f "$tmp"

    if [ -s "$out" ]; then
      summary=$(head -1 "$out" | cut -c1-120)
      log "report: $out"
      notify-send -u critical -a agent-watchers "⚠ $title" \
        "$summary
→ ~/.local/state/agent-watchers/reports/$ts.md" 2>/dev/null || true
    else
      rm -f "$out"
      log "empty report for: $title"
    fi
  ) 9> "$LOCKFILE"
}

# --- watcher 1: hyprland log tailer ------------------------------------------
# NB: tail the tmpfs original via `hyprctl instances` — the latest.log symlink
# in ~/.local/state/hyprland is stale whenever hyprland-log-persist.sh isn't
# running (it wasn't, 2026-09-21). Re-resolve the instance on tail EOF so a
# compositor restart doesn't kill us.
watch_log() {
  while true; do
    sig=$(hyprctl instances 2>/dev/null | sed -n 's/^instance \(.*\):$/\1/p' | head -n1)
    logfile="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/hyprland.log"
    if [ -z "$sig" ] || [ ! -f "$logfile" ]; then
      sleep 10
      continue
    fi
    tail -n0 -F "$logfile" 2>/dev/null \
      | grep --line-buffered -E '^\[(ERR|CRITICAL)\]|Segmentation fault|aborting' \
      | while read -r line; do
          log "hit: $line"
          ctx=$(mktemp)
          {
            echo "=== last 200 lines of hyprland.log (instance $sig) ==="
            tail -200 "$logfile"
            echo
            echo "=== journalctl --user -n 100 ==="
            journalctl --user -n 100 --no-pager 2>/dev/null
          } > "$ctx"
          report "Hyprland error detected" "$ctx" &
        done
    sleep 5   # tail -F exited (log vanished / compositor restart) — re-resolve
  done
}

# --- watcher 2: post-resume health -------------------------------------------
# hypridle's after_sleep_cmd stamps last-resume, then hdmi-wake/dp-wake/
# discord-recover run — give them 20s to settle before judging.
watch_resume() {
  local stamp="$HOME/.local/state/hyprland/last-resume"
  while true; do
    # --include: the state dir also gets hyprland logs + lock-start writes.
    inotifywait -q -e close_write -e moved_to --include 'last-resume$' "$(dirname "$stamp")" 2>/dev/null
    sleep 20
    problems=""
    timeout 3 hyprctl monitors -j >/dev/null 2>&1 || problems="$problems hyprctl-unresponsive"
    wpctl status >/dev/null 2>&1 || problems="$problems pipewire-down"
    nmcli -t -f GENERAL.STATE g 2>/dev/null | grep -q connected || problems="$problems network-down"
    if [ -z "$problems" ]; then
      log "post-resume health: OK"
    else
      ctx=$(mktemp)
      {
        echo "=== post-resume health check FAILED:$problems ==="
        echo "=== hyprctl monitors ==="; timeout 3 hyprctl monitors 2>&1
        echo "=== wpctl status ==="; wpctl status 2>&1 | head -30
        echo "=== nmcli g ==="; nmcli g 2>&1
        echo "=== journalctl -b -n 100 ==="; journalctl -b -n 100 --no-pager 2>&1
      } > "$ctx"
      report "post-resume health:$problems" "$ctx" &
    fi
  done
}

log "agent-watchers started (pid $$)"
watch_log &
watch_resume &
wait
