#!/bin/bash
# Check for package updates (Manjaro/Arch)

# Cache file to avoid hammering pacman
CACHE_FILE="/tmp/waybar_updates_cache"
CACHE_AGE=300  # 5 minutes

# Check if cache is fresh
if [ -f "$CACHE_FILE" ]; then
    cache_time=$(stat -c %Y "$CACHE_FILE")
    now=$(date +%s)
    if [ $((now - cache_time)) -lt $CACHE_AGE ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Count updates
if command -v checkupdates &>/dev/null; then
    official=$(checkupdates 2>/dev/null | wc -l)
else
    official=0
fi
aur=$(yay -Qua 2>/dev/null | wc -l)
total=$((official + aur))

if [ $total -eq 0 ]; then
    output=""
else
    output="📦 $total"
fi

echo "$output" > "$CACHE_FILE"
echo "$output"
