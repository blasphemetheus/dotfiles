-- Plugins.
--
-- hyprsplit: dwm-style per-monitor workspace sets (Super+N = Nth workspace of
-- the FOCUSED monitor; monitor 1 owns ids 1-10, monitor 2 owns 11-20, waybar
-- relabels). Since 0.55 hyprsplit is a Lua LIBRARY, not a .so — the compiled
-- plugin refuses Lua configs. NixOS installs the pinned flake input's init.lua
-- at /etc/hypr/hyprsplit/init.lua; hyprsplit/init.lua here symlinks to it, and
-- package.path already includes <configdir>/?/init.lua.
-- Missing library (e.g. relogin before the nixos-rebuild that installs it):
-- warn loudly and fall back to plain per-monitor workspace binds in binds.lua.
local ok, hs = pcall(require, "hyprsplit")
if not ok then
    hl.notification.create({ text = "hyprsplit Lua library not found (/etc/hypr/hyprsplit/init.lua) — workspace binds degraded. Rebuild NixOS.", timeout = 15000, color = "rgb(ff5555)" })
    HYPRSPLIT = nil
    return
end
HYPRSPLIT = hs   -- global: binds.lua picks it up (require() would re-run this file's pcall otherwise)
hs.config({ num_workspaces = 10 })
-- Pin the sets to connectors by NAME rather than monitor id: Hyprland never
-- reuses a freed id mid-session, so an HDMI replug used to shift 1-10 onto a
-- fresh id (the 2026-09-07 freeze scenario). With this, HDMI-A-1 always gets
-- 1-10 and DP-2 always 11-20.
hs.monitor_priority({ "HDMI-A-1", "DP-2" })

-- hyprexpo: expo-style grid overview (Super+Z). Community fork built against
-- our Hyprland (pkgs/hyprexpo.nix), symlinked by NixOS into /etc/hypr/plugins.
hl.plugin.load("/etc/hypr/plugins/libhyprexpo.so")
-- Plugin config keys exist only once the .so is loaded; Hyprland re-runs the
-- config after loading plugins, so the second pass sets them. Guard the first.
if hl.get_config("plugin.hyprexpo.columns") ~= nil then
    hl.config({
        plugin = {
            hyprexpo = {
                columns          = 3,
                gaps_in          = 5,   -- (legacy config said gap_size, which this fork never had)
                gaps_out         = 0,
                bg_col           = "rgb(111111)",
                workspace_method = "center current",
            },
        },
    })
end
-- Hyprspace stays disabled: no 0.56-compatible release (see configuration.nix).
