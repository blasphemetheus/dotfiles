#!/bin/bash
# Notification Center - shows mako notification history

# Get notification history from mako
history=$(makoctl history)

# Check if there are any notifications
if [ -z "$history" ] || [ "$history" = "[]" ]; then
    echo -e "\033[1;35m╔════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;35m║       NOTIFICATION CENTER              ║\033[0m"
    echo -e "\033[1;35m╚════════════════════════════════════════╝\033[0m"
    echo ""
    echo -e "\033[90m  No notifications yet.\033[0m"
    echo ""
    echo -e "\033[90m  Press 'q' to close, 'c' to clear all.\033[0m"
else
    echo -e "\033[1;35m╔════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;35m║       NOTIFICATION CENTER              ║\033[0m"
    echo -e "\033[1;35m╚════════════════════════════════════════╝\033[0m"
    echo ""

    # Parse and display notifications
    echo "$history" | jq -r '.data[0][] | "\u001b[1;36m[\(.app-name.data // "Unknown")]\u001b[0m \u001b[1m\(.summary.data // "")\u001b[0m\n  \u001b[90m\(.body.data // "")\u001b[0m\n"' 2>/dev/null || echo "$history"

    echo ""
    echo -e "\033[90m  Press 'q' to close, 'c' to clear all.\033[0m"
fi

# Wait for input
while true; do
    read -rsn1 key
    case "$key" in
        q|Q) exit 0 ;;
        c|C)
            makoctl dismiss --all
            echo -e "\n\033[32m  All notifications cleared!\033[0m"
            sleep 1
            exit 0
            ;;
    esac
done
