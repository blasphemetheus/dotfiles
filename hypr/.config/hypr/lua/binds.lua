-- Keybinds are per machine role: binds-desktop.lua and binds-laptop.lua are
-- each a complete set, so edits on one machine (by hand or with hyprbinds)
-- never change the other's keys. The role is the host's NixOS profile
-- (profiles/<role>.nix), published in /etc/dotfiles/power.json; without
-- that file (older generation) this falls back to the desktop set.
local profile = "desktop"
local f = io.open("/etc/dotfiles/power.json", "r")
if f then
    profile = f:read("a"):match('"profile":"(%w+)"') or profile
    f:close()
end
require("./lua/binds-" .. profile .. ".lua")
