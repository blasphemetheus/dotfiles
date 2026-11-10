-- Laptop keybinds (profiles/laptop.nix; lua/binds.lua picks this file).
-- https://wiki.hypr.land/Configuring/Binds/
--
-- Aspire Go 15 keyboard: the top row sends its printed action, Fn gives the
-- real F1-F12. F7 and F12 send real Super combos (Windows "project" and
-- "snip"), so those combos are bound to match the keys:
--   F1-F3 mute/vol-/vol+   F4 F15 (unbound)       F5/F6 brightness -/+
--   F7 Super+P (displays)  F8 Super+L (lock)       F9 airplane (kernel)
--   F10 XF86TouchpadOff/On (alternates itself)     F11 F11
--   F12 Super+Shift+S (region screenshot)          Copilot Super+Shift+F23
-- Flags: bindel → { repeating, locked }, bindl → { locked }, bindm → { drag },
-- bindr → { release }. Shell commands go through hl.dsp.exec_cmd as Lua long
-- strings so $(…), pipes and awk quoting survive untouched.
-- hyprsplit dispatchers when the library loaded (lua/plugins.lua); otherwise
-- Hyprland's own, restricted to the focused monitor — close enough to keep working.
local hs = HYPRSPLIT or {
    dsp = {
        focus = function(a) return hl.dsp.focus({ workspace = tostring(a.workspace), on_current_monitor = true }) end,
        window = { move = function(a) return hl.dsp.window.move({ workspace = tostring(a.workspace), follow = a.follow }) end },
        workspace = { swap_monitors = function(a) return hl.dsp.workspace.swap_monitors(a) end },
        grab_rogue_windows = function() return hl.dsp.no_op() end,
    },
}
local mod = "SUPER"
local S   = "~/.config/hypr/scripts"

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "pkill rofi || rofi -show drun"

local function exec(cmd) return hl.dsp.exec_cmd(cmd) end
local function bind(keys, d, opts) return hl.bind(keys, d, opts) end
local B = mod .. " + "

-- Basics
bind(B .. "Q", exec(terminal))
bind(B .. "C", hl.dsp.window.close())
bind(B .. "escape", exec("wlogout -b 4"))
bind(B .. "SHIFT + CTRL + M", hl.dsp.exit())   -- emergency exit (no menu)
bind(B .. "E", exec(fileManager))
bind(B .. "A", exec([[kitty --class claude-code --title "Claude Code" -e claude]]))
bind("XF86Assistant", exec([[kitty --class claude-code --title "Claude Code" -e claude]]))
bind(B .. "T", exec("kitty -e btop"))
-- Stock Dolphin (no Slippi ASM injection) — for shifted/decomp Melee builds
bind(B .. "SHIFT + G", exec("nix run nixpkgs##dolphin-emu"))
bind(B .. "V", hl.dsp.window.float({ action = "toggle" }))
bind(B .. "R", exec(menu))
bind(B .. "SHIFT + F23", exec([[kitty --class claude-code --title "Claude Code" -e claude]]))   -- Copilot key
bind(B .. "ALT + P", hl.dsp.window.pseudo())    -- dwindle (Super+P is the F7 display key)
bind(B .. "J", hl.dsp.layout("togglesplit"))    -- dwindle

-- Screenshots
bind("F9", exec([[grim -g "$(slurp)" - | tee ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png | wl-copy]]))
bind("SHIFT + F9", exec([[grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png --copy-command wl-copy]]))
bind(B .. "SHIFT + S", exec([[grim -g "$(slurp)" - | tee ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png | wl-copy]]))   -- F12 (snip key)
bind("Print", exec([[grim ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png && wl-copy < ~/Pictures/Screenshots/$(ls -t ~/Pictures/Screenshots | head -1)]]))
bind(B .. "SHIFT + C", exec("hyprpicker -a"))   -- color picker

-- Clipboard history / emoji
bind("F10", exec("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
bind(B .. "SHIFT + E", exec("rofimoji --action type --typer wtype"))

-- Fullscreen
bind("F11",    hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(B .. "F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

bind(B .. "D", exec("ags toggle dashboard"))

-- Dictation (hyprwhspr-rs): tap Fn+F12 to toggle, hold Super+Space for push-to-talk.
-- The daemon's evdev listener handles the keys itself; these binds consume the
-- keys from apps (F12 = devtools in Firefox) and run the notification script.
-- (No Super+U voice commands here: they need ollama, which the laptop lacks.)
bind("F12", exec(S .. "/dictation.sh"))
bind(B .. "SPACE", exec(S .. "/dictation.sh"))
bind(B .. "SPACE", exec(S .. "/dictation.sh"), { release = true })

-- Screen recording toggle (same script as the Super+D ⏺ Record button)
bind(B .. "SHIFT + V", exec("~/.config/ags/scripts/screen-record-toggle.sh"))

-- Reload config
bind(B .. "SHIFT + R", exec([[hyprctl reload && notify-send "Hyprland" "Config reloaded"]]))

-- Toggle idle/sleep (hypridle)
bind(B .. "F5", exec([[pkill -x hypridle && notify-send "Hypridle" "Sleep disabled - staying awake" || { ~/.config/hypr/scripts/start-idle.sh & notify-send "Hypridle" "Sleep re-enabled"; }]]))

-- Lock (via the wrapper: crash-respawn + LED handling, see lock-wrapper.sh)
bind(B .. "L", exec(S .. "/lock-wrapper.sh"))

-- Displays / hardware (the desktop's HDMI-retrain, ASUS refresh and RGB LED
-- binds are left out: none of that hardware is here)
bind(B .. "P", exec("hyprdisplays"))                       -- F7 (display key)
bind(B .. "SHIFT + T", exec(S .. "/mirror-toggle.sh"))    -- mirror focused monitor onto the TV / back to extended
bind(B .. "SHIFT + M", exec("hyprdisplays"))               -- display manager GUI (arrange/modes/mirror/audio/profiles)
bind(B .. "CTRL + V",  exec("hyprvolume"))                 -- mixer GUI (outputs incl. HDMI ports by monitor, streams, inputs)
bind(B .. "CTRL + D",  exec(S .. "/display-profile.sh"))   -- rofi: apply a saved hyprdisplays profile
bind(B .. "SHIFT + D", exec(S .. "/dnd-smart.sh"))        -- do not disturb (+ hourly digest while on)

-- Touchpad key (F10). The firmware alternates Off/On by itself; Hyprland has
-- to act on it. Device name from `hyprctl devices`.
local touchpad = "pixa3848:01-093a:3848-touchpad"
bind("XF86TouchpadOff", function() hl.device({ name = touchpad, enabled = false }); hl.exec_cmd([[notify-send "Touchpad" "Off"]]) end)
bind("XF86TouchpadOn",  function() hl.device({ name = touchpad, enabled = true });  hl.exec_cmd([[notify-send "Touchpad" "On"]]) end)

-- Num Lock on at login (the numpad starts in arrow-key mode otherwise)
hl.config({ input = { numlock_by_default = true } })
bind(B .. "SHIFT + K", exec(S .. "/discord-recover.sh"))  -- Discord splash wedge
bind(B .. "SHIFT + O", exec(S .. "/opacity-toggle.sh"))

-- Groups (tabs)
bind(B .. "G", hl.dsp.group.toggle())
bind(B .. "Tab", hl.dsp.group.next())
bind(B .. "SHIFT + Tab", hl.dsp.group.prev())
bind(B .. "CTRL + G", hl.dsp.window.move({ out_of_group = true }))

-- Cycle windows (alt-tab style)
bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }))
bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))

bind("ALT + S", exec(S .. "/shine-toggle.sh"))            -- Falco shine cursor
bind(B .. "SHIFT + space", hl.dsp.window.center())
bind(B .. "SHIFT + P", hl.dsp.window.pin())

-- Move / resize / focus with arrows
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    bind(B .. "SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
    bind(B .. key, hl.dsp.focus({ direction = dir }))
end
bind(B .. "CTRL + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }))
bind(B .. "CTRL + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }))
bind(B .. "CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }))
bind(B .. "CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }))

-- Workspaces (hyprsplit: Nth workspace of the FOCUSED monitor, dwm-style)
for i = 1, 10 do
    local key = i % 10
    bind(B .. key,              hs.dsp.focus({ workspace = i }))
    bind(B .. "SHIFT + " .. key, hs.dsp.window.move({ workspace = i, follow = true }))
end

-- Cross-monitor
bind(B .. "comma",  hl.dsp.focus({ monitor = "-1" }))
bind(B .. "period", hl.dsp.focus({ monitor = "+1" }))
bind(B .. "SHIFT + comma",  hl.dsp.window.move({ monitor = "-1" }))
bind(B .. "SHIFT + period", hl.dsp.window.move({ monitor = "+1" }))
bind(B .. "CTRL + comma",  hs.dsp.workspace.swap_monitors({ monitor1 = "current", monitor2 = "+1" }))
bind(B .. "CTRL + period", HYPRSPLIT_RESCUE or hs.dsp.grab_rogue_windows())   -- rescue workspaces after monitor unplug (plugins.lua)

-- Scratchpad
bind(B .. "S", hl.dsp.workspace.toggle_special("magic"))
bind(B .. "ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))   -- Super+Shift+S is the F12 snip key

-- Pyprland scratchpads
bind(B .. "grave", exec("pypr toggle term"))
bind(B .. "X", exec("pypr toggle volume"))
bind(B .. "SHIFT + X", exec("pypr toggle music"))
bind(B .. "Y", exec("pypr toggle files"))
bind(B .. "equal", exec("pypr zoom"))

-- Notifications
bind(B .. "N", exec("makoctl restore"))
bind(B .. "SHIFT + N", exec("notification-picker"))

-- Wallpaper
bind(B .. "W", exec(S .. "/wallpaper.sh picker"))
bind(B .. "SHIFT + W", exec(S .. "/wallpaper.sh random"))

bind(B .. "B", exec("firefox"))

-- Power profile
bind(B .. "F6", exec(S .. "/power-profile.sh toggle"))
bind(B .. "SHIFT + F6", exec(S .. "/power-profile.sh rofi"))

-- Hyprshade (NOT Shift+N: that's notification-picker)
bind(B .. "SHIFT + B", exec("hyprshade toggle blue-light-3500"))
bind(B .. "CTRL + N", exec("hyprshade off"))

-- Scroll this monitor's workspaces (m±1 stays within the focused monitor)
bind(B .. "mouse_down", hs.dsp.focus({ workspace = "m+1" }))
bind(B .. "mouse_up",   hs.dsp.focus({ workspace = "m-1" }))

-- Mouse move/resize
bind(B .. "mouse:272", hl.dsp.window.drag(),   { drag = true })
bind(B .. "mouse:273", hl.dsp.window.resize(), { drag = true })

-- Volume (wob pipe)
local vol_up   = [[wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d\n", $2*100}' > ${XDG_RUNTIME_DIR}/wobpipe]]
local vol_down = [[wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d\n", $2*100}' > ${XDG_RUNTIME_DIR}/wobpipe]]
local vol_mute = [[wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d\n", $2*100}' > ${XDG_RUNTIME_DIR}/wobpipe]]
bind(B .. "Up",   exec(vol_up),   { repeating = true, locked = true })
bind(B .. "Down", exec(vol_down), { repeating = true, locked = true })
bind(B .. "M", exec(vol_mute))
bind(B .. "CTRL + M", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- Multimedia keys
bind("XF86AudioRaiseVolume", exec(vol_up),   { repeating = true, locked = true })
bind("XF86AudioLowerVolume", exec(vol_down), { repeating = true, locked = true })
bind("XF86AudioMute",        exec(vol_mute), { repeating = true, locked = true })
bind("XF86AudioMicMute",     exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true, locked = true })
bind("XF86MonBrightnessUp",   exec([[brightnessctl -e4 -n2 set 5%+ && brightnessctl -m | awk -F, '{print substr($4, 0, length($4)-1)}' > ${XDG_RUNTIME_DIR}/wobpipe]]), { repeating = true, locked = true })
bind("XF86MonBrightnessDown", exec([[brightnessctl -e4 -n2 set 5%- && brightnessctl -m | awk -F, '{print substr($4, 0, length($4)-1)}' > ${XDG_RUNTIME_DIR}/wobpipe]]), { repeating = true, locked = true })
bind("XF86AudioNext",  exec("playerctl next"),       { locked = true })
bind("XF86AudioPause", exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay",  exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev",  exec("playerctl previous"),   { locked = true })

bind(B .. "semicolon", exec("wl-kbptr"))   -- keyboard mouse control
bind(B .. "O", exec("walker"))             -- launcher ("Open")

-- Workspace overview (hyprexpo grid)
bind(B .. "Z", function() hl.plugin.hyprexpo.expo("toggle") end)

-- Session save/restore
bind(B .. "CTRL + S", exec(S .. "/session-picker.sh save"))
bind(B .. "CTRL + R", exec(S .. "/session-picker.sh restore"))

-- Keybinds: Super+Shift+? opens hyprbinds on this file; Super+/ lists this
-- file's binds in rofi (keybinds.md describes the desktop set).
bind(B .. "SHIFT + slash", exec("hyprbinds --file ~/.config/hypr/lua/binds-laptop.lua"))  -- keybind editor GUI
bind(B .. "slash", exec([[pkill -x rofi || hyprbinds --list --file ~/.config/hypr/lua/binds-laptop.lua | rofi -dmenu -i -p "⌨ Keybinds" -theme-str 'window {width: 60%;}' -no-custom]]))   -- rofi cheatsheet

-- hyprbinds key capture: an EMPTY submap. While it is active none of the binds
-- above fire, so the combo being recorded reaches the hyprbinds window instead
-- of launching something. The app enters it (hl.dsp.submap) when you press
-- Capture and resets it after the keypress; Ctrl+Alt+Escape is the manual
-- way out if the app dies mid-capture.
hl.define_submap("hyprbinds-capture", function()
    bind("CTRL + ALT + escape", hl.dsp.submap("reset"))
end)
