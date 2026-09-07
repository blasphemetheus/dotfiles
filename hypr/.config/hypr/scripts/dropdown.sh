#!/usr/bin/env bash
# Quake-style dropdown terminal toggle

INFO=$(hyprctl clients -j | node -e "
const c=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
const d=c.find(x=>x.class==='dropdown');
if(d) console.log(d.address+' '+d.workspace.id);
" 2>/dev/null)

ADDR=$(echo "$INFO" | awk '{print $1}')
WS=$(echo "$INFO" | awk '{print $2}')
ACTIVE_WS=$(hyprctl activeworkspace -j | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).id)" 2>/dev/null)

if [ -z "$ADDR" ]; then
    # No dropdown exists, create one
    kitty --class dropdown &
elif [ "$WS" = "$ACTIVE_WS" ]; then
    # Visible on current workspace, hide it
    hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:dropdown_hide', follow = false, window = 'address:${ADDR}' })"
else
    # Hidden, bring to current workspace, focus, and pin to top
    hyprctl dispatch "hl.dsp.window.move({ workspace = '${ACTIVE_WS}', follow = false, window = 'address:${ADDR}' })"
    hyprctl dispatch "hl.dsp.focus({ window = 'address:${ADDR}' })"
    sleep 0.05
    hyprctl dispatch "hl.dsp.window.move({ x = 0, y = 0, window = 'address:${ADDR}' })"
fi
