-- Animations + gestures. https://wiki.hypr.land/Configuring/Animations/

hl.config({ animations = { enabled = true } })

hl.curve("linear",    { type = "bezier", points = { { 0, 0 },     { 1, 1 } } })
hl.curve("quick",     { type = "bezier", points = { { 0.15, 0 },  { 0.1, 1 } } })
hl.curve("snappy",    { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.0 } } })   -- fast start, clean deceleration
hl.curve("overshot",  { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } }) -- slight overshoot then settle
hl.curve("pop",       { type = "bezier", points = { { 0.1, 0.8 }, { 0.2, 1.15 } } })  -- bouncy entrance
hl.curve("smoothOut", { type = "bezier", points = { { 0.4, 0 },   { 0.2, 1 } } })     -- quick out, no lingering
hl.curve("elastic",   { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.2 } } })   -- springy

-- Windows — snappy pop-in, quick shrink-out
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3, bezier = "pop",       style = "popin 60%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "smoothOut", style = "popin 60%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "overshot" })
-- Fading — fast, barely noticeable
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "smoothOut" })
hl.animation({ leaf = "fade",    enabled = true, speed = 3, bezier = "quick" })
-- Border — slow ambient color shift
hl.animation({ leaf = "border",      enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })  -- Lua API caps speed at 100 (hyprlang took 300)
-- Layers (waybar, rofi, notifications)
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2, bezier = "pop",       style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 2, bezier = "smoothOut", style = "slide" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2, bezier = "snappy" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "smoothOut" })
-- Workspaces — fast slide with slight overshot
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3, bezier = "overshot", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "pop",      style = "slidevert" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
