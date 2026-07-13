#!/usr/bin/env bash
# Manual revive for the ASUS (Super+Shift+H) — same 60→165Hz bounce as the
# hypridle after_sleep hook. For the rarer boot-time wedge (no compositor
# yet), the root-level hdmi-link-retrain.service handles it before greetd;
# it can also be fired in-session without a password (polkit rule):
#   systemctl restart hdmi-link-retrain.service
~/.config/hypr/scripts/hdmi-wake.sh
notify-send "HDMI" "ASUS re-synced (60→165Hz bounce)" -t 3000
