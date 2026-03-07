#!/bin/bash
# Moon phase calculator

# Lunar cycle is ~29.53 days
# Known new moon: Jan 11, 2024
known_new_moon=1704931200  # epoch timestamp

now=$(date +%s)
days_since=$(echo "scale=2; ($now - $known_new_moon) / 86400" | bc)
phase=$(echo "scale=2; $days_since % 29.53" | bc)
phase_int=$(echo "$phase / 1" | bc)

# Moon phase emojis (8 phases)
if [ $phase_int -lt 2 ]; then
    echo "🌑"  # New moon
elif [ $phase_int -lt 6 ]; then
    echo "🌒"  # Waxing crescent
elif [ $phase_int -lt 9 ]; then
    echo "🌓"  # First quarter
elif [ $phase_int -lt 13 ]; then
    echo "🌔"  # Waxing gibbous
elif [ $phase_int -lt 16 ]; then
    echo "🌕"  # Full moon
elif [ $phase_int -lt 20 ]; then
    echo "🌖"  # Waning gibbous
elif [ $phase_int -lt 24 ]; then
    echo "🌗"  # Last quarter
else
    echo "🌘"  # Waning crescent
fi
