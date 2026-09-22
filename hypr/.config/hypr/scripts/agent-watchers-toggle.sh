#!/usr/bin/env bash
# agent-watchers-toggle.sh — the on/off switch for the LLM watchers.
# systemctl enable/disable --now: enablement IS the persistence across reboots
# (the service has no Install section, so without this it never starts).
notify() { notify-send -a agent-watchers -h string:x-canonical-private-synchronous:agent-watchers "$1" "$2" -t 2500 2>/dev/null || true; }

if systemctl --user is-enabled agent-watchers.service >/dev/null 2>&1; then
  systemctl --user disable --now agent-watchers.service
  notify "󰒍 Agent watchers" "OFF — no more LLM triage"
else
  systemctl --user enable --now agent-watchers.service
  notify "󰒌 Agent watchers" "ON — hyprland log + resume health (qwen3-coder:30b)"
fi
