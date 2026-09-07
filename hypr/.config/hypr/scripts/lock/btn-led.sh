#!/usr/bin/env bash
# LED button label; state from led-ctl.sh (state file "<power> <spec> <bright>").
read -r p _ < "$HOME/.local/state/leds/state" 2>/dev/null || p=on
[[ $p == off ]] && echo "󰌶  LEDs off" || echo "󰌵  LEDs on"
