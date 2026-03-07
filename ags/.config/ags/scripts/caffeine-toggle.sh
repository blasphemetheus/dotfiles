#!/bin/bash
if pgrep -f "systemd-inhibit.*caffeine" >/dev/null 2>&1; then
    pkill -f "systemd-inhibit.*caffeine"
else
    systemd-inhibit --what=idle --who=caffeine --why="Caffeine mode" sleep infinity &
fi
