#!/usr/bin/env bash
# Lock-screen health warnings (cmd[update:10000]). Prints nothing when all is
# well; each problem is one line. Meant to be readable before logging in.
set -u
out=()
net=$("$HOME/.config/hypr/scripts/lock-netinfo.sh" 2>/dev/null)
case $net in *"no network"*) out+=("$net") ;; esac
if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
    out+=("󰂲  Bluetooth soft-blocked")
fi
newest=$(ls -t "$HOME"/.cache/hyprland/hyprlandCrashReport*.txt 2>/dev/null | head -1)
if [[ -n $newest ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "$newest") ))
    (( age < 86400 )) && out+=("  Hyprland crashed $((age/3600))h $((age%3600/60))m ago")
fi
log="$HOME/.local/state/hyprland/latest.log"
if [[ -r $log ]]; then
    n=$(tail -n 400 "$log" 2>/dev/null | grep -c '^\[ERR\]\|ERR \]')
    (( n > 0 )) && out+=("  $n Hyprland ERR lines recently")
fi
if git -C "$HOME/dotfiles" status --porcelain -- '*.nix' 2>/dev/null | grep -q .; then
    out+=("  uncommitted .nix changes in ~/dotfiles")
fi
printf '%s\n' "${out[@]}"
