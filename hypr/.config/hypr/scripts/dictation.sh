#!/usr/bin/env bash
# dictation.sh — surface hyprwhspr-rs state as notifications + waybar refresh.
# hyprwhspr-rs 0.3.23 has no CLI/socket control: its evdev listener owns the
# shortcuts (F12 toggle, Super+Space hold). The Hyprland binds that call this
# script exist to consume those keys from apps (e.g. F12 = Firefox devtools)
# and to narrate results. Live state (listening/transcribing) is shown by the
# AGS pill (widget/DictationPill.tsx) + waybar; notifications only announce
# the outcome: "✓ <inserted text>", no-speech, or errors.
set -u
STATUS_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hyprwhspr-rs/status.json"

# x-canonical-private-synchronous makes mako replace the previous dictation
# notification instead of stacking them
notify() {  # notify <body> [extra notify-send opts...]
    local body="$1"; shift
    notify-send -h string:x-canonical-private-synchronous:dictation "$@" "Dictation" "$body"
}

state() { jq -r '.class // "unknown"' "$STATUS_FILE" 2>/dev/null; }

if ! systemctl --user is-active --quiet hyprwhspr-rs.service; then
    notify "Daemon not running — systemctl --user start hyprwhspr-rs" -u critical
    exit 1
fi

# auto_copy_clipboard is on, so a changed clipboard == text was inserted
clip_before=$(timeout 1 wl-paste 2>/dev/null | head -c 200 || true)

sleep 0.25  # let the daemon handle the keypress and settle status.json
cls=$(state)
pkill -RTMIN+8 waybar

case "$cls" in
    active)
        exit 0  # mic hot — the pulsing pill + waybar show it
        ;;
    error)
        notify "Error — check: journalctl --user -u hyprwhspr-rs" -u critical
        exit 1
        ;;
    processing|inactive)
        # stop press: follow transcription to completion (poll up to 30s)
        for _ in $(seq 1 300); do
            [ "$cls" = "inactive" ] && break
            [ "$cls" = "error" ] && { notify "Error — check: journalctl --user -u hyprwhspr-rs" -u critical; exit 1; }
            sleep 0.1
            cls=$(state)
        done
        pkill -RTMIN+8 waybar
        # success is shown by the pill's "✓ <text>" flash; only failures toast
        clip_now=$(timeout 1 wl-paste 2>/dev/null | head -c 200 || true)
        if [ -z "$clip_now" ] || [ "$clip_now" = "$clip_before" ]; then
            # daemon never left inactive (keypress not seen?) or VAD found no speech
            notify "No speech detected (if the mic never went hot: relog/reboot for input-group access)" -t 3000
        fi
        ;;
esac
