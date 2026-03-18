#!/usr/bin/env bash
# Save current Hyprland session (window classes, workspaces, positions)
# Usage: session-save.sh [session-name]

SESSION_DIR="$HOME/.local/share/hypr-sessions"
SESSION_NAME="${1:-default}"
SESSION_FILE="$SESSION_DIR/$SESSION_NAME.json"

mkdir -p "$SESSION_DIR"

# Get all clients and extract what we need for restore
hyprctl clients -j | jq '[.[] | select(.mapped == true and .hidden == false) | {
    class: .class,
    initialClass: .initialClass,
    title: .title,
    workspace: .workspace.id,
    floating: .floating,
    at: .at,
    size: .size,
    fullscreen: .fullscreen,
    pinned: .pinned,
    pid: .pid
}]' > "$SESSION_FILE"

WINDOW_COUNT=$(jq 'length' "$SESSION_FILE")
notify-send "Session Saved" "Saved $WINDOW_COUNT windows to \"$SESSION_NAME\"\n$SESSION_FILE" -t 3000
echo "Saved $WINDOW_COUNT windows to $SESSION_FILE"
