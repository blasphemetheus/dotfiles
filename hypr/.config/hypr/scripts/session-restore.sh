#!/usr/bin/env bash
# Restore a saved Hyprland session
# Usage: session-restore.sh [session-name]

SESSION_DIR="$HOME/.local/share/hypr-sessions"
SESSION_NAME="${1:-default}"
SESSION_FILE="$SESSION_DIR/$SESSION_NAME.json"

if [[ ! -f "$SESSION_FILE" ]]; then
    notify-send "Session Restore" "No session found: \"$SESSION_NAME\"" -u critical -t 3000
    echo "No session file: $SESSION_FILE"
    exit 1
fi

# Map window classes to launch commands
# Add your custom mappings here
declare -A LAUNCH_MAP=(
    ["firefox"]="firefox"
    ["kitty"]="kitty"
    ["claude-code"]="kitty --class claude-code --title 'Claude Code' -e claude"
    ["org.kde.dolphin"]="dolphin"
    ["dolphin"]="dolphin"
    ["Code"]="code"
    ["code-url-handler"]="code"
    ["Zed"]="zed-editor"
    ["pavucontrol"]="pavucontrol"
    ["blueman-manager"]="blueman-manager"
    ["org.gnome.Nautilus"]="nautilus"
    ["Spotify"]="spotify"
    ["discord"]="discord"
    ["steam"]="steam"
    ["obsidian"]="obsidian"
)

# Classes to skip (scratchpads, system trays, etc.)
SKIP_CLASSES="kitty-dropterm|kitty-cava|nm-applet|waybar|rofi|wofi|wlogout"

WINDOW_COUNT=$(jq 'length' "$SESSION_FILE")
LAUNCHED=0
SKIPPED=0

echo "Restoring session \"$SESSION_NAME\" ($WINDOW_COUNT windows)..."

# Process each saved window
jq -c '.[] | select(.workspace > 0)' "$SESSION_FILE" | while read -r window; do
    class=$(echo "$window" | jq -r '.class')
    workspace=$(echo "$window" | jq -r '.workspace')
    floating=$(echo "$window" | jq -r '.floating')
    pos_x=$(echo "$window" | jq -r '.at[0]')
    pos_y=$(echo "$window" | jq -r '.at[1]')
    size_w=$(echo "$window" | jq -r '.size[0]')
    size_h=$(echo "$window" | jq -r '.size[1]')
    fullscreen=$(echo "$window" | jq -r '.fullscreen')
    pinned=$(echo "$window" | jq -r '.pinned')

    # Skip scratchpad/system windows
    if echo "$class" | grep -qE "^($SKIP_CLASSES)$"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Find launch command
    launch_cmd="${LAUNCH_MAP[$class]}"
    if [[ -z "$launch_cmd" ]]; then
        echo "  SKIP: No launch command for class \"$class\" (add to LAUNCH_MAP)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check if already running (don't duplicate single-instance apps like firefox)
    if [[ "$class" == "firefox" ]] && pgrep -x firefox > /dev/null; then
        echo "  SKIP: $class already running"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "  Launching: $class → workspace $workspace"

    # Set up window rules for placement before launching
    # These are dynamic rules that apply once then expire
    # exec with a one-shot window rule (was: dispatch exec [workspace N silent] cmd)
    hyprctl dispatch "hl.dsp.exec_cmd([==[$launch_cmd]==], { workspace = '$workspace silent' })"

    LAUNCHED=$((LAUNCHED + 1))

    # Brief pause to let the window spawn
    sleep 0.5

    # If floating, move and resize after spawn
    if [[ "$floating" == "true" ]]; then
        # Find the newly spawned window by class (most recent)
        sleep 0.3
        addr=$(hyprctl clients -j | jq -r \
            --arg c "$class" \
            '[.[] | select(.class == $c)] | last | .address // empty')
        if [[ -n "$addr" ]]; then
            hyprctl eval "local w = 'address:$addr'; hl.dispatch(hl.dsp.window.float({ action = 'set', window = w })); hl.dispatch(hl.dsp.window.move({ x = $pos_x, y = $pos_y, window = w })); hl.dispatch(hl.dsp.window.resize({ x = $size_w, y = $size_h, window = w }))"
        fi
    fi

    # Apply fullscreen if needed
    if [[ "$fullscreen" == "1" || "$fullscreen" == "2" ]]; then
        sleep 0.3
        addr=$(hyprctl clients -j | jq -r \
            --arg c "$class" \
            '[.[] | select(.class == $c)] | last | .address // empty')
        if [[ -n "$addr" ]]; then
            hyprctl dispatch "hl.dsp.window.fullscreen({ mode = '$fullscreen', action = 'set', window = 'address:$addr' })"
        fi
    fi
done

notify-send "Session Restored" "Launched $LAUNCHED windows ($SKIPPED skipped)" -t 3000
echo "Done. Launched: $LAUNCHED, Skipped: $SKIPPED"
