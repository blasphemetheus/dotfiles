#!/usr/bin/env bash
# Battery Monitor for Hyprland
# Sends notifications when battery drops below thresholds

# Configuration
# First battery, whatever the firmware calls it (BAT0 / BAT1 / …). No battery
# (desktop) → nothing to monitor.
BATTERY_PATH=""
for battery in /sys/class/power_supply/BAT*; do
    [[ -r "$battery/capacity" ]] || continue
    BATTERY_PATH=$battery
    break
done
[[ -n "$BATTERY_PATH" ]] || exit 0
WARNING_THRESHOLD=20    # First warning
LOW_THRESHOLD=10        # Low battery warning
CRITICAL_THRESHOLD=5    # Critical warning (urgent)
HIBERNATE_THRESHOLD=3   # Preserve the session before the battery is exhausted
CHECK_INTERVAL=60       # Check every 60 seconds

# Sounds for each level
WARNING_SOUND="/usr/share/sounds/freedesktop/stereo/message.oga"
LOW_SOUND="/usr/share/sounds/freedesktop/stereo/suspend-error.oga"
CRITICAL_SOUND="/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

# Track last notification level to avoid spam
last_notified=""

get_battery_level() {
    cat "$BATTERY_PATH/capacity" 2>/dev/null || echo "100"
}

get_charging_status() {
    cat "$BATTERY_PATH/status" 2>/dev/null || echo "Unknown"
}

play_sound() {
    local sound_file=$1
    [[ -f "$sound_file" ]] && paplay "$sound_file" &
}

send_notification() {
    local level=$1
    local severity=$2
    local urgency=normal
    local icon="battery-low"
    local title="Battery Low"
    local body="Battery at ${level}%"
    local sound=""

    case $severity in
        critical)
            urgency=critical
            icon="battery-empty"
            title="CRITICAL: Battery Very Low!"
            body="Battery at ${level}%! Plug in NOW or your system will shut down!"
            sound="$CRITICAL_SOUND"
            ;;
        low)
            icon="battery-caution"
            title="Battery Low"
            body="Battery at ${level}%. Please plug in your charger."
            sound="$LOW_SOUND"
            ;;
        warning)
            icon="battery-low"
            title="Battery Warning"
            body="Battery at ${level}%. Consider plugging in soon."
            sound="$WARNING_SOUND"
            ;;
    esac

    notify-send -u "$urgency" -i "$icon" "$title" "$body"
    play_sound "$sound"
}

main() {
    while true; do
        level=$(get_battery_level)
        status=$(get_charging_status)

        # Only warn if not charging
        if [[ "$status" == "Discharging" ]]; then
            if [[ $level -le $HIBERNATE_THRESHOLD ]]; then
                notify-send -u critical -i "battery-empty" "CRITICAL BATTERY" "Battery at ${level}%! Saving the session in 10 seconds..."
                sleep 10
                # Re-check in case charger was plugged in
                if [[ "$(get_charging_status)" == "Discharging" ]] &&
                   (( $(get_battery_level) <= HIBERNATE_THRESHOLD )); then
                    session-sleep critical
                fi
            elif [[ $level -le $CRITICAL_THRESHOLD && "$last_notified" != "critical" ]]; then
                send_notification "$level" "critical"
                last_notified="critical"
            elif [[ $level -le $LOW_THRESHOLD && $level -gt $CRITICAL_THRESHOLD && "$last_notified" != "low" ]]; then
                send_notification "$level" "low"
                last_notified="low"
            elif [[ $level -le $WARNING_THRESHOLD && $level -gt $LOW_THRESHOLD && "$last_notified" != "warning" ]]; then
                send_notification "$level" "warning"
                last_notified="warning"
            fi
        else
            # Reset when charging
            if [[ $level -gt $WARNING_THRESHOLD ]]; then
                last_notified=""
            fi
        fi

        sleep $CHECK_INTERVAL
    done
}

main
