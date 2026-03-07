#!/bin/bash
# Pomodoro timer for waybar

STATE_FILE="/tmp/pomodoro_state"
WORK_MINS=25
BREAK_MINS=5

get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "idle|0"
    fi
}

# If called with "toggle", start/stop timer
if [ "$1" = "toggle" ]; then
    state=$(get_state | cut -d'|' -f1)
    if [ "$state" = "idle" ]; then
        end_time=$(($(date +%s) + WORK_MINS * 60))
        echo "work|$end_time" > "$STATE_FILE"
        notify-send "Pomodoro" "Work session started (${WORK_MINS}min)"
    elif [ "$state" = "work" ]; then
        echo "idle|0" > "$STATE_FILE"
        notify-send "Pomodoro" "Session cancelled"
    elif [ "$state" = "break" ]; then
        echo "idle|0" > "$STATE_FILE"
        notify-send "Pomodoro" "Break cancelled"
    fi
    exit 0
fi

# Display current state
state_data=$(get_state)
state=$(echo "$state_data" | cut -d'|' -f1)
end_time=$(echo "$state_data" | cut -d'|' -f2)
now=$(date +%s)

if [ "$state" = "idle" ]; then
    echo "🍅"
elif [ "$state" = "work" ]; then
    remaining=$((end_time - now))
    if [ $remaining -le 0 ]; then
        # Work done, start break
        end_time=$((now + BREAK_MINS * 60))
        echo "break|$end_time" > "$STATE_FILE"
        notify-send "Pomodoro" "Work done! Take a ${BREAK_MINS}min break"
        echo "☕ ${BREAK_MINS}:00"
    else
        mins=$((remaining / 60))
        secs=$((remaining % 60))
        printf "🍅 %d:%02d\n" $mins $secs
    fi
elif [ "$state" = "break" ]; then
    remaining=$((end_time - now))
    if [ $remaining -le 0 ]; then
        echo "idle|0" > "$STATE_FILE"
        notify-send "Pomodoro" "Break over! Ready for another session?"
        echo "🍅"
    else
        mins=$((remaining / 60))
        secs=$((remaining % 60))
        printf "☕ %d:%02d\n" $mins $secs
    fi
fi
