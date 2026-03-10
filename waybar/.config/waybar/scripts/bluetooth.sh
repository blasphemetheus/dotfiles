#!/usr/bin/env bash

# Get Bluetooth controller status
power_status=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

# Get connected devices count
connected_devices=$(bluetoothctl info | grep "Connected: yes" | wc -l)

if [[ "$power_status" == "yes" ]]; then
    if [[ "$connected_devices" -gt 0 ]]; then
        echo " Connected"
    else
        echo " On"
    fi
else
    echo "󰂲 Off"
fi
