#!/usr/bin/env bash
# Lock-screen battery line (cmd[update:30000]). Prints nothing on a machine
# with no battery (the desktop), so hyprlock.conf can stay shared. Reads sysfs
# only — no upower, no D-Bus — so it works before login and with WiFi dead.
#
# Time estimate is charge/current (µAh/µA) or energy/power (µWh/µW), whichever
# the firmware exposes; the Aspire exposes charge_*. Current can be 0 right
# after (un)plugging, in which case the time is simply left off.
set -u
bat=""
for b in /sys/class/power_supply/BAT*; do
    [[ -r $b/capacity ]] && { bat=$b; break; }
done
[[ -n $bat ]] || exit 0

pct=$(cat "$bat/capacity")
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

# Glyph: nf-md-battery ramp, charging bolt, or alert when low and unplugged.
if [[ $status == Charging ]]; then
    icon=󰂄
elif (( pct <= 15 )) && [[ $status == Discharging ]]; then
    icon=󰂃
else
    ramp=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
    icon=${ramp[pct / 10]}
fi

# now / full / rate in matching units, whichever family exists.
now="" full="" rate=""
if [[ -r $bat/charge_now && -r $bat/current_now ]]; then
    now=$(cat "$bat/charge_now"); full=$(cat "$bat/charge_full" 2>/dev/null); rate=$(cat "$bat/current_now")
elif [[ -r $bat/energy_now && -r $bat/power_now ]]; then
    now=$(cat "$bat/energy_now"); full=$(cat "$bat/energy_full" 2>/dev/null); rate=$(cat "$bat/power_now")
fi
rate=${rate#-}   # some firmware signs the discharge current

eta() {   # $1 = amount, $2 = rate → "Xh YYm"
    local m=$(( $1 * 60 / $2 ))
    (( m < 1 )) && m=1
    if (( m >= 60 )); then printf '%dh %02dm' $((m/60)) $((m%60)); else printf '%dm' "$m"; fi
}

case $status in
    Charging)
        if [[ -n $rate && $rate -gt 0 && -n $full ]]; then
            printf '%s  %s%% · charging · %s to full\n' "$icon" "$pct" "$(eta $((full - now)) "$rate")"
        else
            printf '%s  %s%% · charging\n' "$icon" "$pct"
        fi ;;
    Discharging)
        if [[ -n $rate && $rate -gt 0 ]]; then
            printf '%s  %s%% · %s left\n' "$icon" "$pct" "$(eta "$now" "$rate")"
        else
            printf '%s  %s%% · on battery\n' "$icon" "$pct"
        fi ;;
    Full)     printf '%s  %s%% · plugged in\n' "$icon" "$pct" ;;
    *)        printf '%s  %s%% · plugged in, not charging\n' "$icon" "$pct" ;;   # "Not charging" at a charge limit
esac
