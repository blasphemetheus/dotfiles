-- Window, layer and workspace rules. https://wiki.hypr.land/Configuring/Window-Rules/
-- (Opacity rules live in opacity.lua — they're swapped by Super+Shift+O.)

-- Melee: present Slippi frames immediately (tear) instead of waiting for the
-- next refresh tick. Only these classes.
hl.window_rule({ name = "slippi-tearing", match = { class = "^(Slippi Dolphin|dolphin-emu)$" }, immediate = true })

-- Ignore maximize requests from apps
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drag",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({ name = "code-workspace", match = { class = "^(code)$" }, workspace = "3" })

-- Slippi Dolphin (melee bot sessions): float at native size. Tiling resized
-- Dolphin while unmapped and desynced its GL framebuffer; NO size rule (even a
-- visible at-map resize races Dolphin's GL init). Toggle fullscreen to enlarge.
hl.window_rule({ name = "slippi-dolphin-float", match = { class = "^(Apprun)$" }, float = true, center = true })

-- rwing (Melee replay viewer, winit+wgpu under XWayland): winit mis-reads the
-- geometry at map time and needs exactly ONE configure to re-sync, so plain
-- float and NEVER size/move it here (either fires a change mid-startup that
-- re-triggers the click-offset bug). Version is baked into the class.
hl.window_rule({ name = "rwing-float", match = { class = "^(rwing|rwing-linux-.*)$" }, float = true })

-- Pyprland scratchpad windows
hl.window_rule({ name = "dropterm-float", match = { class = "^(kitty-dropterm)$" }, animation = "slidevert", opacity = "0.85" })
hl.window_rule({ name = "cava-float",     match = { class = "^(kitty-cava)$" },     animation = "slide",     opacity = "0.85" })
hl.window_rule({ name = "yazi-float",     match = { class = "^(kitty-yazi)$" },     animation = "slide",     opacity = "0.9" })

-- Firefox picture-in-picture
hl.window_rule({ name = "firefox-pip", match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true, size = "400 225" })

-- File picker dialogs
hl.window_rule({ name = "file-picker-float", match = { title = "^(Open File)$|^(Save File)$|^(Open Folder)$" }, float = true })

-- wofi/rofi popups
hl.window_rule({ name = "launcher-float", match = { class = "^(wofi)$|^(rofi)$" }, animation = "slide" })

-- wlogout power menu - fullscreen overlay
hl.window_rule({ name = "wlogout-float", match = { class = "^(wlogout)$" }, float = true, fullscreen = true })

-- hyprdisplays (Rust/iced display manager, Super+Shift+M): floating, centred
hl.window_rule({ name = "hyprdisplays-float", match = { class = "^(hyprdisplays)$" }, float = true, center = true, size = "1200 720" })

-- Layer rules: blur behind rofi/notifications/wofi; waybar stays crisp
hl.layer_rule({ name = "blur-waybar",        match = { namespace = "waybar" },        blur = false })
hl.layer_rule({ name = "blur-rofi",          match = { namespace = "rofi" },          blur = true })
hl.layer_rule({ name = "blur-notifications", match = { namespace = "notifications" }, blur = true })
hl.layer_rule({ name = "blur-wofi",          match = { namespace = "wofi" },          blur = true })

-- Workspace rules (12/13 = second monitor's 2/3 under hyprsplit)
hl.workspace_rule({ workspace = "2",  gaps_in = 8, gaps_out = 30 })  -- chill vibes
hl.workspace_rule({ workspace = "12", gaps_in = 8, gaps_out = 30 })
hl.workspace_rule({ workspace = "3",  gaps_in = 2, gaps_out = 5 })   -- focused coding
hl.workspace_rule({ workspace = "13", gaps_in = 2, gaps_out = 5 })
