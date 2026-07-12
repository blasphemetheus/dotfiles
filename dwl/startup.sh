#!/usr/bin/env bash
# dwl session stack. Launched via `dwl -s <this script>`: children inherit
# WAYLAND_DISPLAY, and dwl's status stream (tags/layout/title) arrives on
# stdin — the exec'd dwlb at the end consumes it (leaving stdin unread would
# eventually block dwl on a full pipe).

# wallpaper (same swww setup + script as the Hyprland session)
swww-daemon &
(sleep 0.7; "$HOME/.config/hypr/scripts/wallpaper.sh" random) &

# notifications
mako &

# clock in the bar's status area (talks to the running dwlb via its socket)
(
  sleep 1
  while true; do
    dwlb -status all " $(date '+%I:%M %p  |  %a %b %d') "
    sleep 30
  done
) &

# bar — gold/slate theme matching the Hyprland border colors
exec dwlb -font 'monospace:size=12' \
  -active-fg-color '#1a1a1a' -active-bg-color '#f5a623' \
  -occupied-fg-color '#f5a623' -occupied-bg-color '#1a1a1a' \
  -inactive-fg-color '#6b8cae' -inactive-bg-color '#1a1a1a' \
  -urgent-fg-color '#1a1a1a' -urgent-bg-color '#e875a1' \
  -middle-bg-color '#1a1a1a' -middle-bg-color-selected '#2a2a2a'
