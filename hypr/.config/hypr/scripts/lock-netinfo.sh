#!/usr/bin/env bash
# One-line network status for the hyprlock footer: which link is up and what
# it's connected to, so a dead WiFi card (2026-09-07: WCN7850 vanished from
# PCIe after a hard reset) is visible before logging in.
set -u
out=""
while IFS=: read -r dev type state conn; do
    [[ $state == connected ]] || continue
    case $type in
        wifi)     out+="󰖩 ${conn:-$dev}  " ;;
        ethernet) out+="󰈀 ${conn:-$dev}  " ;;
    esac
done < <(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null)
if [[ -z $out ]]; then
    if nmcli -t -f WIFI-HW general 2>/dev/null | grep -q missing; then
        out="󰖪 no network — WiFi card MISSING (cold power-off needed)"
    else
        out="󰖪 no network"
    fi
fi
printf '%s' "${out% }"
