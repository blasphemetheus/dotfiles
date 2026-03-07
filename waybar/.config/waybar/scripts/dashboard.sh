#!/bin/bash
# Toggle AGS Dashboard

# Check if AGS is running
if ags list 2>/dev/null | grep -q "ags"; then
    ags toggle dashboard
else
    cd ~/.config/ags && ags run &
    sleep 2
    ags toggle dashboard
fi
