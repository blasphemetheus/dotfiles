-- Opacity modes, toggled by Super+Shift+O (scripts/opacity-toggle.sh).
--
-- Legacy config swapped a `source =` symlink and reloaded; in Lua the six rules
-- are declared by name and simply re-declared with new values (a named
-- hl.window_rule updates in place). The script persists the choice in
-- ~/.local/state/hypr/opacity and applies it live with
--   hyprctl eval 'opacity.apply("transparent")'
-- so `opacity` is deliberately a global.

opacity = {}

local modes = {
    opaque = {      -- solid everything, full readability
        kitty = "1.0 1.0", kitty_float = "1.0 1.0", claude = "1.0 1.0", browser = "1.0 1.0",
    },
    transparent = { -- see the wallpaper through everything
        kitty = "0.8 0.7", kitty_float = "0.45 0.35", claude = "0.85 0.75", browser = "0.75 0.6",
    },
}

local state_file = (os.getenv("HOME") or "") .. "/.local/state/hypr/opacity"

function opacity.current()
    local f = io.open(state_file, "r")
    if not f then return "opaque" end
    local mode = (f:read("*l") or ""):gsub("%s+$", "")
    f:close()
    return modes[mode] and mode or "opaque"
end

function opacity.apply(mode)
    local m = modes[mode] or modes.opaque
    hl.window_rule({ name = "kitty-opacity",     match = { class = "^(kitty)$" },               opacity = m.kitty })
    hl.window_rule({ name = "kitty-float-glass", match = { class = "^(kitty)$", float = true }, opacity = m.kitty_float })
    hl.window_rule({ name = "claude-code-class", match = { class = "^(claude-code)$" },         opacity = m.claude })
    hl.window_rule({ name = "claude-code-title", match = { title = "^(Claude Code.*)$" },       opacity = m.claude })
    hl.window_rule({ name = "firefox-opacity",   match = { class = "^(firefox)$" },             opacity = m.browser })
    hl.window_rule({ name = "chromium-opacity",  match = { class = "^(chromium-browser|google-chrome|brave-browser|vivaldi)$" }, opacity = m.browser })
end

opacity.apply(opacity.current())
