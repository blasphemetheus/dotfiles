#!/bin/bash

case "$1" in
    details)
        tlp-stat -s
        echo ""
        tlp-stat -w
        echo ""
        echo "Press any key to close..."
        read -n 1
        ;;
    *)
        # Get power source and wifi power save status
        tlp_output=$(tlp-stat -s 2>/dev/null)
        power_source=$(echo "$tlp_output" | grep "Power source" | awk '{print $4}')
        profile=$(echo "$tlp_output" | grep "Power profile" | awk '{print $4}')
        wifi_ps=$(iw dev wlp0s20f3 get power_save 2>/dev/null | awk '{print $3}')

        if [[ "$power_source" == "AC" ]]; then
            icon="⚡"
        else
            icon="🔋"
        fi

        if [[ "$wifi_ps" == "on" ]]; then
            wifi_icon="🌿"
            wifi_state="on (saving)"
        else
            wifi_icon="📶"
            wifi_state="off (full power)"
        fi

        tooltip="Power: ${power_source:-unknown}\nProfile: ${profile:-unknown}\nWiFi power save: ${wifi_state}"

        echo "{\"text\": \"${icon}${wifi_icon}\", \"tooltip\": \"${tooltip}\"}"
        ;;
esac
