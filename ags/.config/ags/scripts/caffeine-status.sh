#!/bin/bash
if pgrep -f "systemd-inhibit.*caffeine" >/dev/null 2>&1; then
    echo "☕ Caffeine ON"
else
    echo "😴 Caffeine OFF"
fi
