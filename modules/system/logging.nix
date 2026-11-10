# Post-mortem logging. Context: the 2026-10-17 display wedge (DP-2 lost its
# link, aquamarine looped through fallback modes down to 640x480 — the
# "frozen and zoomed in" screen) left a journal that simply stopped 13 minutes
# before the reset button, because journald only forces its files to disk every
# SyncIntervalSec (default 5 min) unless a message is CRIT or worse. The
# compositor side was only recoverable from the mirrored Hyprland log
# (hypr/.config/hypr/scripts/hyprland-log-persist.sh), which now also streams
# into the journal so both land in one timeline.
{ ... }:
{
  # Bound journal loss on a hard hang to ~10 s (a few MB/day of extra writes).
  services.journald.settings.Journal.SyncIntervalSec = "10s";
}
