#!/usr/bin/env bash
# Pick a saved session to restore via rofi
# Usage: session-picker.sh [save|restore]

SESSION_DIR="$HOME/.local/share/hypr-sessions"
SCRIPT_DIR="$(dirname "$0")"
ACTION="${1:-restore}"

mkdir -p "$SESSION_DIR"

if [[ "$ACTION" == "save" ]]; then
    # Prompt for session name
    NAME=$(echo -e "default\nwork\ncoding\nbrowsing" | rofi -dmenu -p "Save session as:" -theme-str 'listview {lines: 4;}')
    [[ -z "$NAME" ]] && exit 0
    "$SCRIPT_DIR/session-save.sh" "$NAME"
elif [[ "$ACTION" == "restore" ]]; then
    # List saved sessions
    SESSIONS=$(ls "$SESSION_DIR"/*.json 2>/dev/null | xargs -I{} basename {} .json)
    if [[ -z "$SESSIONS" ]]; then
        notify-send "Session Restore" "No saved sessions found" -u critical -t 3000
        exit 1
    fi

    # Show session details in rofi
    CHOICES=""
    for session in $SESSIONS; do
        count=$(jq 'length' "$SESSION_DIR/$session.json")
        mod_time=$(stat -c '%y' "$SESSION_DIR/$session.json" | cut -d'.' -f1)
        CHOICES+="$session ($count windows, $mod_time)\n"
    done

    PICK=$(echo -e "$CHOICES" | rofi -dmenu -p "Restore session:" -theme-str 'listview {lines: 6;}')
    [[ -z "$PICK" ]] && exit 0

    # Extract session name (first word before the paren)
    NAME=$(echo "$PICK" | awk '{print $1}')
    "$SCRIPT_DIR/session-restore.sh" "$NAME"
fi
