#!/usr/bin/env bash
# voice-command.sh start|stop — push-to-talk voice command router (Super+U).
#
# NOT wake-word and NOT dictation: hold Super+U, say a command, release. The
# utterance is transcribed by whisper-cli (Vulkan build, shares hyprwhspr-rs'
# large-v3-turbo model — the ~0.5-1s model reload per utterance is the price of
# not keeping a second resident model), then qwen3-coder:30b (local ollama)
# maps it to one of the allowlisted commands below.
#
# 2026-09-21: LLM output is DATA — jq-parsed and matched against the case
# table; nothing it says is ever shelled, and unknown/unparseable answers just
# produce a "didn't catch that" toast. The allowlist is deliberately limited to
# idempotent toggles; session-restore / lock / session-save are EXCLUDED
# (destructive or one-way — never voice-reachable).

set -uo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voice-command"
SCRIPTS="$HOME/.config/hypr/scripts"
AGS_SCRIPTS="$HOME/.config/ags/scripts"
STATE="$RUNTIME/state"       # "<style>|<label>|<epoch>" — read by command-pill.sh
PIDFILE="$RUNTIME/recorder.pid"
WAV="$RUNTIME/utterance.wav"
MODEL="$HOME/.local/share/hyprwhspr-rs/models/ggml-large-v3-turbo-q8_0.bin"

# Same lexicon as the hyprwhspr-rs whisper_cpp prompt — keep them in sync.
LEXICON="Desktop voice command. Vocabulary: NixOS, Hyprland, hyprsplit, hyprwhspr, hyprshade, hypridle, hyprlock, hyprdisplays, waybar, mako, niri, atuin, Ollama, Qwen, Home Manager, nixpkgs, rofi, zellij, Slippi, Melee, Falco."

SYSTEM_PROMPT='You map spoken desktop commands to strict JSON. Reply with ONLY one JSON object, no prose, no markdown:
{"command":"<id>","args":["<arg>"]} or {"command":"none"} when nothing matches.

Commands (id → meaning → example utterances):
- dnd_toggle → toggle Do Not Disturb → "do not disturb", "dnd", "silence notifications"
- mirror_toggle → mirror/unmirror the TV → "mirror to the tv", "unmirror"
- opacity_toggle → transparent/opaque windows → "toggle opacity"
- refresh_toggle → 120Hz/165Hz → "toggle refresh rate"
- shine_toggle → joke cursor theme → "toggle shine"
- hdmi_retrain → fix a wedged monitor link → "retrain hdmi", "fix the monitor"
- dp_wake → wake the second monitor → "wake the display"
- discord_recover → restart wedged Discord → "recover discord", "discord is frozen"
- wallpaper args:["next"|"prev"|"random"] → "next wallpaper", "random wallpaper"
- power_profile_toggle → cycle power profile → "toggle power profile"
- power_profile args:["performance"|"balanced"|"power-saver"] → "performance mode", "power saver"
- led args:["on"|"off"|"toggle"] → "lights off", "toggle lights"
- led_bright args:["<5-100>"] → "set brightness to 40", "dim the lights" (use 20)
- led_mode args:["rainbow"|"thermal"|"beat"|"storm"|"focus"] → "rainbow lights"
- caffeine_toggle → keep the machine awake → "stay awake", "caffeine"
- zoom_toggle → magnifier → "toggle zoom"
- screen_record_toggle → start/stop screen recording → "record my screen"
- hyprshade_toggle → blue light filter → "blue light filter"
- hyprshade_off → disable the filter → "blue light off"'

set_state() { mkdir -p "$RUNTIME"; printf '%s|%s|%s\n' "$1" "$2" "$(date +%s)" > "$STATE"; }
notify() { notify-send -a voice-command -h string:x-canonical-private-synchronous:voice-command "$1" "$2" -t "${3:-2500}" 2>/dev/null || true; }

start() {
  mkdir -p "$RUNTIME"
  # Re-press while recording = cancel (not a second recorder).
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -INT "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE" "$WAV"
    set_state idle ""
    notify "󰜺 Voice command" "cancelled" 1000
    exit 0
  fi
  rm -f "$WAV"
  pw-record --format s16 --rate 16000 --channels 1 "$WAV" &
  echo $! > "$PIDFILE"
  set_state listening "● Listening…"
}

# Execute one allowlisted script, then flash the confirmation. The script paths
# are hardcoded here — the LLM picks WHICH line fires, never what it runs.
run() {
  local label="$1"; shift
  "$@" >/dev/null 2>&1 &
  set_state done "✓ $label"
  notify "✓ Voice command" "$label"
}

unknown() {
  set_state error "✕ didn't catch that"
  notify "🤷 Voice command" "didn't catch a command in: \"$1\"" 3000
}

process() {
  trap 'rm -f "$WAV"' EXIT

  set_state transcribing "◌ Transcribing…"
  local transcript
  transcript=$(timeout 20 whisper-cli -m "$MODEL" -f "$WAV" -l en -nt -np -t 8 \
                 --prompt "$LEXICON" 2>/dev/null \
               | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
  # Whisper's blank-audio hallucinations (same list hyprwhspr's fast_vad guards
  # against) and mic-blip one-letter results.
  case "$transcript" in
    ""|"."|"!"|"?"|"Thank you."|"[BLANK_AUDIO]"|"Subscribe"|"you"|"Bye.")
      set_state error "✕ no speech"; notify "✕ Voice command" "no speech detected"; exit 0 ;;
  esac

  set_state thinking "◌ \"$transcript\""
  if ! curl -sf --max-time 2 http://localhost:11434/api/version >/dev/null; then
    set_state error "✕ ollama down"
    notify "✕ Voice command" "ollama not answering on :11434 — sudo systemctl start ollama" 3500
    exit 0
  fi

  local payload resp content cmd arg1
  payload=$(jq -n --arg sys "$SYSTEM_PROMPT" --arg user "$transcript" \
    '{model:"qwen3-coder:30b", temperature:0, max_tokens:60, stream:false,
      messages:[{role:"system",content:$sys},{role:"user",content:$user}]}')
  if ! resp=$(timeout 30 curl -sf http://localhost:11434/v1/chat/completions \
                -H 'Content-Type: application/json' -d "$payload"); then
    set_state error "✕ router failed"
    notify "✕ Voice command" "ollama request failed" 3000
    exit 0
  fi
  content=$(printf '%s' "$resp" | jq -r '.choices[0].message.content // empty' | tr -d '\n' | sed 's/^ *//; s/ *$//')
  # Strip markdown fences if the model misbehaves (temp 0, but be safe).
  content="${content#\`\`\`json}"; content="${content#\`\`\`}"; content="${content%\`\`\`}"
  cmd=$(printf '%s' "$content" | jq -r '.command // "none"' 2>/dev/null || echo none)
  arg1=$(printf '%s' "$content" | jq -r '.args[0] // empty' 2>/dev/null)

  case "$cmd" in
    dnd_toggle)           run "DND"            "$SCRIPTS/dnd-smart.sh" ;;
    mirror_toggle)        run "mirror toggle"  "$SCRIPTS/mirror-toggle.sh" ;;
    opacity_toggle)       run "opacity"        "$SCRIPTS/opacity-toggle.sh" ;;
    refresh_toggle)       run "refresh rate"   "$SCRIPTS/refresh-toggle.sh" ;;
    shine_toggle)         run "shine"          "$SCRIPTS/shine-toggle.sh" ;;
    hdmi_retrain)         run "HDMI retrain"   "$SCRIPTS/hdmi-retrain.sh" ;;
    dp_wake)              run "display wake"   "$SCRIPTS/dp-wake.sh" ;;
    discord_recover)      run "Discord recover" "$SCRIPTS/discord-recover.sh" ;;
    caffeine_toggle)      run "caffeine"       "$AGS_SCRIPTS/caffeine-toggle.sh" ;;
    zoom_toggle)          run "zoom"           "$AGS_SCRIPTS/zoom-toggle.sh" ;;
    screen_record_toggle) run "screen record"  "$AGS_SCRIPTS/screen-record-toggle.sh" ;;
    hyprshade_toggle)     run "blue light filter" hyprshade toggle blue-light-3500 ;;
    hyprshade_off)        run "blue light off"    hyprshade off ;;
    wallpaper)
      case "$arg1" in
        next|prev|random) run "wallpaper $arg1" "$SCRIPTS/wallpaper.sh" "$arg1" ;;
        *) unknown "$transcript" ;;
      esac ;;
    power_profile_toggle) run "power profile" "$SCRIPTS/power-profile.sh" toggle ;;
    power_profile)
      case "$arg1" in
        performance|balanced|power-saver) run "power: $arg1" "$SCRIPTS/power-profile.sh" set "$arg1" ;;
        *) unknown "$transcript" ;;
      esac ;;
    led)
      case "$arg1" in
        on|off|toggle) run "lights $arg1" "$SCRIPTS/led-ctl.sh" "$arg1" ;;
        *) unknown "$transcript" ;;
      esac ;;
    led_bright)
      if [[ "$arg1" =~ ^[0-9]{1,3}$ ]] && [ "$arg1" -ge 5 ] && [ "$arg1" -le 100 ]; then
        run "brightness $arg1%" "$SCRIPTS/led-ctl.sh" bright "$arg1"
      else
        unknown "$transcript"
      fi ;;
    led_mode)
      case "$arg1" in
        rainbow|thermal|beat|storm|focus) run "lights: $arg1" "$SCRIPTS/led-ctl.sh" "$arg1" ;;
        *) unknown "$transcript" ;;
      esac ;;
    none) unknown "$transcript" ;;
    *)    unknown "$transcript" ;;
  esac
}

stop() {
  [ -f "$PIDFILE" ] || exit 0
  local pid
  pid=$(cat "$PIDFILE"); rm -f "$PIDFILE"
  kill -INT "$pid" 2>/dev/null   # SIGINT lets pw-record finalize the wav header
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$WAV" ] && break; sleep 0.1; done
  if [ ! -s "$WAV" ]; then
    set_state error "✕ no audio"
    notify "✕ Voice command" "no audio captured"
    exit 0
  fi
  process &   # detach — the keybind release must return immediately
}

case "${1:-}" in
  start) start ;;
  stop)  stop ;;
  *) echo "usage: voice-command.sh start|stop" >&2; exit 1 ;;
esac
