#!/usr/bin/env bash
# The profile config arrives on rebuild. Keep working during a checkout update
# before that rebuild, and on older generations that don't have profiles yet.
if [[ -r /etc/dotfiles/hypridle.conf ]]; then
    exec hypridle --config /etc/dotfiles/hypridle.conf
fi
exec hypridle
