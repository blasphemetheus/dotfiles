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
-- Pin the sets to the PHYSICAL monitors (description), not to a connector name
-- or monitor id: Hyprland never reuses a freed id mid-session, and pinning by
-- name broke on 2026-09-20 when the TV took HDMI-A-1 (it inherited 1-10 and the
-- VG27V, now on DP-3, fell off the list). Description follows the panel to
-- whatever port it lands on. VG27V = 1-10, VY279HGR = 11-20, TV = 21-30
-- (waybar relabels all three sets to 1-10).
hs.monitor_priority({
    "ASUSTek COMPUTER INC ASUS VG27V 0x0003ABEC",
    "ASUSTek COMPUTER INC VY279HGR TCLMTR040596",
    "Toshiba America Info Systems Inc TOSHIBA-TV 0x00000001",
})

-- Recover after a monitor unplug. Hyprland dumps the dead monitor's
-- workspaces onto a survivor, where they sit outside its hyprsplit range and
-- Super+N can never reach them. hyprsplit's own grab_rogue_windows() piles
-- every stray window onto ONE workspace; this keeps the layout instead, moving
-- workspace N's windows to the host monitor's Nth slot (e.g. TV 23 -> DP-2 13).
local function rescue_rogue_workspaces()
    hs.ensure_good_workspaces()
    local n = hs.get_config("num_workspaces")
    local live = {}
    for _, m in ipairs(hl.get_monitors()) do
        if m ~= nil and not m.is_mirror and m.id ~= -1 then
            live[m.id] = m
        end
    end
    local moved = 0
    for _, ws in ipairs(hl.get_workspaces()) do
        local host = ws.monitor and live[ws.monitor.id] or nil
        if host and ws.id > 0 and not ws.special then
            local range = hs.MonitorRange:new(host)
            if not range:contains(ws.id) then
                local target = tostring(range.min + ((ws.id - 1) % n))
                for _, w in ipairs(hl.get_windows()) do
                    if w.mapped and w.workspace and w.workspace.id == ws.id then
                        hl.dispatch(hl.dsp.window.move({ workspace = target, window = w, follow = false }))
                        moved = moved + 1
                    end
                end
            end
        end
    end
    if moved > 0 then
        hl.notification.create({ text = "hyprsplit: re-homed " .. moved .. " window(s) after monitor change", timeout = 4000 })
    end
end
HYPRSPLIT_RESCUE = rescue_rogue_workspaces   -- binds.lua: Super+Ctrl+period

-- Hyprland is still reparenting the dead monitor's workspaces when
-- monitor.removed fires, so let it settle before rescuing.
hl.on("monitor.removed", function()
    hl.timer(rescue_rogue_workspaces, { timeout = 500, type = "oneshot" })
end)

-- hyprexpo: expo-style grid overview (Super+Z). sandwichfarm fork flake input,
-- built against our pinned Hyprland, linked by NixOS into /etc/hypr/plugins.
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
