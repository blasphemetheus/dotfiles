#!/usr/bin/env bash
# Toggle power profiles: performance ↔ balanced ↔ power-saver
# Usage: power-profile.sh [toggle|set <profile>|rofi]

ICONS=("⚡" "⚖️" "🔋")
PROFILES=("performance" "balanced" "power-saver")

get_current() {
    powerprofilesctl get 2>/dev/null || echo "balanced"
}

set_profile() {
    local profile="$1"
    powerprofilesctl set "$profile"

    case "$profile" in
        performance) icon="⚡"; desc="Max performance" ;;
        balanced)    icon="⚖️"; desc="Balanced" ;;
        power-saver) icon="🔋"; desc="Power saver" ;;
    esac

    notify-send "Power Profile" "$icon $desc" -t 2000
}

case "${1:-toggle}" in
    toggle)
        current=$(get_current)
        case "$current" in
            performance) set_profile "balanced" ;;
            balanced)    set_profile "power-saver" ;;
            power-saver) set_profile "performance" ;;
        esac
        ;;
    set)
        if [[ -n "$2" ]]; then
            set_profile "$2"
        fi
        ;;
    rofi)
        current=$(get_current)
        selected=$(printf "⚡ performance\n⚖️ balanced\n🔋 power-saver" | \
            rofi -dmenu -p "Power ($current):" -theme-str 'listview {lines: 3;}')
        if [[ -n "$selected" ]]; then
            profile=$(echo "$selected" | awk '{print $2}')
            set_profile "$profile"
        fi
        ;;
esac
