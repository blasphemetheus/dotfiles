#!/usr/bin/env bash
# The profile config arrives on rebuild. Keep working during a checkout update
# before that rebuild, and on older generations that don't have profiles yet.
if [[ -r /etc/dotfiles/hypridle.conf ]]; then
    logger -t hypridle "starting with /etc/dotfiles/hypridle.conf"
    exec hypridle --config /etc/dotfiles/hypridle.conf
fi
logger -t hypridle "starting with ~/.config/hypr/hypridle.conf (no host profile yet)"
exec hypridle
