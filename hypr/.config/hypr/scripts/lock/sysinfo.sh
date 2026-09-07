#!/usr/bin/env bash
# Lock-screen system panel (cmd[update:3000]). One line per resource; never
# fails, never touches the network.
set -u
gpu=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total \
      --format=csv,noheader,nounits 2>/dev/null | head -1)
if [[ -n $gpu ]]; then
    IFS=', ' read -r gt gu gm gtot <<<"$gpu"
    printf '󰢮  GPU %s°C · %s%% · %.1f/%.0f GB\n' "$gt" "$gu" "$((gm))e-3" "$((gtot))e-3" 2>/dev/null \
      || printf '󰢮  GPU %s°C · %s%% · %s/%s MiB\n' "$gt" "$gu" "$gm" "$gtot"
fi
ct=""
for h in /sys/class/hwmon/hwmon*; do
    [[ $(cat "$h/name" 2>/dev/null) == k10temp ]] || continue
    for l in "$h"/temp*_label; do
        [[ $(cat "$l" 2>/dev/null) == Tctl ]] && { ct=$(( $(cat "${l%_label}_input") / 1000 )); break; }
    done
done
read -r l1 l5 _ < /proc/loadavg
printf '  CPU %sload %s / %s\n' "${ct:+$ct°C · }" "$l1" "$l5"
read -r _ mt mu _ < <(free -m | awk '/^Mem:/')
printf '󰍛  RAM %.1f / %.0f GB\n' "$((mu))e-3" "$((mt))e-3"
printf '󰋊  Disk %s free\n' "$(df -h / | awk 'NR==2{print $4}')"
up=$(( $(cut -d. -f1 /proc/uptime) ))
printf '󰅐  Up %dd %02dh %02dm' $((up/86400)) $((up%86400/3600)) $((up%3600/60))
r="$HOME/.local/state/hyprland/last-resume"
if [[ -r $r ]]; then
    s=$(( $(date +%s) - $(cat "$r") ))
    printf ' · resumed %dh %02dm ago' $((s/3600)) $((s%3600/60))
fi
printf '\n'
