#!/usr/bin/env bash
# Route exphil eval Dolphin windows to the workspace of the terminal that
# launched the training run, instead of the currently active workspace.
#
# Hyprland has no "open on parent's workspace" primitive — new windows always
# map on the active workspace. This daemon listens for openwindow events on
# socket2; for each Slippi/Dolphin window it walks the process ancestry to
# (a) confirm an exphil process is in the chain (manual Slippi sessions have
# none, so they are left untouched) and (b) find the nearest ancestor that
# owns a Hyprland window (the launching kitty), then moves the new window
# there with movetoworkspacesilent — no view switch, no focus steal.
#
# Known limits:
# - The window still flashes on the active workspace for a moment before the
#   move (it must map before we can act on it).
# - Evals run inside the exphil Docker container would hide the marker from
#   host /proc ancestry — the script then no-ops (today's behavior).
# - A Dolphin that daemonizes/reparents to PID 1 loses its ancestry — no-op.

EVAL_MARKER="exphil"
CLASS_RE='^(Apprun|Slippi Dolphin|dolphin-emu)$'

route_window() {
    local addr="$1" class="$2"
    [[ "$class" =~ $CLASS_RE ]] || return

    local clients pid
    clients=$(hyprctl clients -j)
    pid=$(jq -r --arg a "0x$addr" '[.[] | select(.address == $a)] | first | .pid // empty' <<<"$clients")
    if [[ -z "$pid" ]]; then
        # openwindow event can race the clients list — retry once
        sleep 0.2
        clients=$(hyprctl clients -j)
        pid=$(jq -r --arg a "0x$addr" '[.[] | select(.address == $a)] | first | .pid // empty' <<<"$clients")
        [[ -n "$pid" ]] || return
    fi

    local cur_ws
    cur_ws=$(jq -r --arg a "0x$addr" '[.[] | select(.address == $a)] | first | .workspace.id // empty' <<<"$clients")

    # Walk the PPid chain: flag any ancestor whose cmdline mentions the eval
    # marker, and take the workspace of the nearest window-owning ancestor
    # (the launching terminal). The marker process (python/exphil) sits below
    # the terminal in the tree, so one upward pass finds both.
    local p="$pid" found_marker=0 target_ws="" ws
    while [[ -n "$p" && "$p" != "1" && "$p" != "0" ]]; do
        if (( ! found_marker )) && tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q "$EVAL_MARKER"; then
            found_marker=1
        fi
        if [[ -z "$target_ws" && "$p" != "$pid" ]]; then
            ws=$(jq -r --argjson p "$p" '[.[] | select(.pid == $p)] | first | .workspace.id // empty' <<<"$clients")
            [[ -n "$ws" ]] && target_ws="$ws"
        fi
        p=$(awk '/^PPid:/{print $2}' "/proc/$p/status" 2>/dev/null) || break
    done

    (( found_marker )) || return
    [[ -n "$target_ws" && "$target_ws" != "$cur_ws" ]] || return
    hyprctl dispatch movetoworkspacesilent "$target_ws,address:0x$addr" >/dev/null
}

socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while IFS= read -r line; do
    case "$line" in
        openwindow\>\>*)
            body="${line#openwindow>>}"
            # Fields: address,workspacename,class,title — title may contain
            # commas, so only split off the first three fields.
            IFS=',' read -r addr _wsname class _title <<<"$body"
            route_window "$addr" "$class"
            ;;
    esac
done
