-- Hyprland config (Lua). Since 0.55 this is the native format; hyprland.conf
-- is only a legacy fallback that 0.57 removes. Keep hyprland.conf around one
-- release as the rollback: delete/rename THIS file and the old one loads.
--
-- Split by concern; order matters (plugins before binds, look before rules).
-- Runtime changes: `hyprctl keyword` no longer exists — use
--   hyprctl eval 'hl.config{ cursor = { zoom_factor = 2 } }'
--   hyprctl dispatch 'hl.dsp.dpms("on")'
-- API reference: generate stubs with meta/generateLuaStubs.py from the
-- Hyprland source (see memory note hyprland-lua-config).

require("./lua/env.lua")
require("./lua/monitors.lua")
require("./lua/look.lua")
require("./lua/animations.lua")
require("./lua/plugins.lua")
require("./lua/rules.lua")
require("./lua/opacity.lua")
require("./lua/binds.lua")
require("./lua/autostart.lua")
