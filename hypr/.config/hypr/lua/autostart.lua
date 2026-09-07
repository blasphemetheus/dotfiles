-- Autostart (was exec-once). Runs once when the compositor starts, not on reload.
local S = "~/.config/hypr/scripts"

-- HYPR_NO_AUTOSTART=1 skips all of this (nested test sessions: `Hyprland --config …`).
if os.getenv("HYPR_NO_AUTOSTART") == "1" then return end

hl.on("hyprland.start", function()
    -- Autologin boot (greetd initial_session, configuration.nix): greetd started
    -- this session with no password, so lock it before anything else appears.
    -- hyprlock IS the login screen; --strict ends the session if it can't stay up.
    if os.getenv("HYPR_AUTOLOGIN_LOCK") == "1" then
        hl.exec_cmd(S .. "/lock-wrapper.sh --strict")
    end
    -- Export Wayland env to systemd/dbus (xdg-desktop-portal, screen sharing)
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    -- graphical-session.target never activates under greetd: start these directly
    hl.exec_cmd("systemctl --user start polkit-gnome-agent.service")
    hl.exec_cmd("systemctl --user start hyprwhspr-rs.service")   -- dictation daemon

    hl.exec_cmd("nm-applet &")
    hl.exec_cmd("waybar")
    hl.exec_cmd("wl-paste --watch cliphist store")   -- clipboard history daemon
    hl.exec_cmd("mako")                              -- notifications
    hl.exec_cmd("swww-daemon")                       -- wallpaper daemon
    hl.exec_cmd("bash -c 'sleep 5 && while true; do " .. S .. "/wallpaper.sh random; sleep 300; done'")  -- random wallpaper every 5 min
    hl.exec_cmd("cd ~/.config/ags && ags run")       -- AGS dashboard
    hl.exec_cmd(S .. "/battery-monitor.sh")
    hl.exec_cmd("hypridle")                          -- auto lock + suspend on idle
    hl.exec_cmd("sleep 3 && " .. S .. "/led-ctl.sh apply")   -- restore RGB (waits for openrgb server)
    -- ASUS won't train 165Hz from a cold link at session start (same wedge as
    -- S3 resume, seen after logout→login) — bounce once the session is up.
    hl.exec_cmd("sleep 2 && " .. S .. "/hdmi-wake.sh")
    hl.exec_cmd("hyprshade auto")                    -- blue light filter schedule
    hl.exec_cmd("pyprland")                          -- scratchpads
    hl.exec_cmd(S .. "/wallpaper-workspace.sh")      -- per-workspace wallpapers
    hl.exec_cmd(S .. "/eval-window-router.sh")       -- route exphil eval Dolphin windows
    hl.exec_cmd("rm -f /tmp/wobpipe && mkfifo /tmp/wobpipe && tail -f /tmp/wobpipe | wob")
    -- Mirror the tmpfs Hyprland log to ~/.local/state/hyprland (post-mortems)
    hl.exec_cmd(S .. "/hyprland-log-persist.sh")
end)
