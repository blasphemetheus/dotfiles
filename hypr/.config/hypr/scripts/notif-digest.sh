#!/usr/bin/env bash
# notif-digest.sh — summarize what mako swallowed into ONE notification.
#
# Reads the dbus-logged history (~/.local/state/mako/history.jsonl, written by
# the notification-logger service) since the last digest, filters OUR OWN
# scripts' feedback toasts (digesting those is noise — they're already
# one-liners), and asks the local ollama for <=5 terse bullets.
#
# Delivery is NORMAL urgency on purpose (2026-09-21): under DND mako's
# [mode=dnd] hides it and `makoctl restore` (Super+N) resurfaces it; the jsonl
# keeps it regardless. urgency=critical would defeat the DND the user
# explicitly enabled, and the drop-dnd/toast/re-add dance dnd-toggle.sh does
# for itself races a concurrent `makoctl mode` from the user. Hidden-until-
# restore IS the correct semantic for a digest.
#
# Runs hourly from notif-digest.timer ONLY while DND is on (dnd-smart.sh owns
# the timer), and once when DND turns off (flush).

set -uo pipefail

HIST="$HOME/.local/state/mako/history.jsonl"
STATE_DIR="$HOME/.local/state/notif-digest"
LAST_FILE="$STATE_DIR/last"
mkdir -p "$STATE_DIR"
[ -f "$HIST" ] || exit 0
last=0
[ -f "$LAST_FILE" ] && last=$(cat "$LAST_FILE")

# New entries, minus our own scripts' feedback toasts. Keep the filter here in
# sync with scripts that notify: led-ctl (RGB), wallpaper, dnd, dictation,
# voice-command, hyprshade, caffeine, zoom, screen-record, nixos-health.
new=$(jq -c --argjson last "$last" '
  select(.time > $last)
  | select((.app + " " + .summary
      | test("Wallpaper Changed|^RGB|^LEDs|^DND|Dictation|Voice Command|Hyprshade|Caffeine|^Zoom|^Screen|nixos-health|^Notifications$|^✓ vocabulary"; "i")) | not)
' "$HIST" 2>/dev/null)

count=$(printf '%s' "$new" | grep -c . || true)
if [ "$count" = "0" ]; then
  date +%s > "$LAST_FILE"
  exit 0
fi

# Cap the batch so a day of Discord doesn't blow the context; say so in output.
truncated=0
if [ "$count" -gt 60 ]; then
  truncated=$((count - 60))
  new=$(printf '%s\n' "$new" | tail -60)
  count=60
fi

# Ollama down? Leave `last` untouched so the next run retries the same window.
curl -sf --max-time 2 http://localhost:11434/api/version >/dev/null || exit 0

listing=$(printf '%s\n' "$new" | jq -r '"[" + (.time | tostring) + "] " + .app + " — " + .summary + ": " + .body' | cut -c1-300)
[ "$truncated" -gt 0 ] && listing="(…and $truncated earlier entries omitted)
$listing"

sys='Summarize these desktop notifications in at most 5 terse bullets. Group duplicates, drop anything trivial, keep names and facts. One line per bullet, no preamble, no closing remark.'

# qwen3:8b, not qwen3-coder:30b: this is five bullets of plain-English
# summary, not code, and the 30b spilled to CPU whenever it could not fit.
# num_ctx is pinned here rather than inherited from the service default
# (OLLAMA_CONTEXT_LENGTH=65536, sized for `claude-local`): a 64k KV cache
# costs ~6GB of VRAM to read a batch this script already caps at 60 lines.
# This is the NATIVE /api/chat endpoint, not /v1/chat/completions — the
# OpenAI-compatible layer silently drops `options`, so num_ctx only takes
# effect here. Response shape differs accordingly (.message, not .choices).
# think:false because qwen3 is a hybrid-thinking model — left on, its
# <think> block lands verbatim in the notification body.
payload=$(jq -n --arg sys "$sys" --arg user "$listing" \
  '{model:"qwen3:8b", stream:false, think:false,
    options:{num_ctx:8192, temperature:0.2, num_predict:200},
    messages:[{role:"system",content:$sys},{role:"user",content:$user}]}')

resp=$(timeout 60 curl -sf http://localhost:11434/api/chat \
         -H 'Content-Type: application/json' -d "$payload") || exit 0
bullets=$(printf '%s' "$resp" | jq -r '.message.content // empty')
[ -n "$bullets" ] || exit 0

# Update `last` only on successful delivery — a failed notify (mako down)
# shouldn't lose the window.
if notify-send -a notif-digest -h string:x-canonical-private-synchronous:notif-digest \
     "󰂚 Digest ($count)" "$bullets" -t 10000 2>/dev/null; then
  date +%s > "$LAST_FILE"
fi
