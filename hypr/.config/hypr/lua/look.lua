-- Look and feel + input + misc. https://wiki.hypr.land/Configuring/Variables/

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 3,
        col = {
            -- Gold to Rose gradient border
            active_border   = { colors = { "rgba(f5a623ff)", "rgba(e8a854ff)", "rgba(d4848cff)", "rgba(e875a1ff)" }, angle = 45 },
            inactive_border = "rgba(6b8caebb)",
        },
        resize_on_border = false,
        -- Tearing is only used by the slippi-tearing window rule (no VRR over
        -- HDMI on NVIDIA, so immediate presentation is the low-latency option).
        allow_tearing = true,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,
        dim_inactive   = false,
        dim_strength   = 0.15,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled        = true,
            range          = 15,
            render_power   = 3,
            color          = "rgba(e8a85450)",
            color_inactive = "rgba(00000000)",
            offset         = "0 0",
        },
        -- Liquid metal blur
        blur = {
            enabled           = true,
            size              = 4,
            passes            = 1,
            new_optimizations = true,
            xray              = false,
            noise             = 0.01,
            contrast          = 1.1,
            brightness        = 0.95,
            vibrancy          = 0.3,
            vibrancy_darkness = 0.3,
            popups            = true,
            special           = true,
        },
    },

    dwindle = { preserve_split = true },
    master  = { new_status = "master" },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
        -- Window swallowing — terminal hides when it spawns a GUI app
        enable_swallow = true,
        swallow_regex  = [[^(kitty)$]],
        -- Never swallow a Claude Code terminal. Matched (RE2 FullMatch) against
        -- the PARENT TERMINAL's title: "✳ session" idle, and the working marker
        -- (braille U+2800-U+28FF, later the ◐◓◑◒ spinners — 2026-08-22
        -- regression), so cover Geometric Shapes U+25A0-U+25FF plus braille.
        -- Codex has no marker glyph, so ~/.codex/config.toml sets
        -- tui.terminal_title = ["activity", "app-name", "project-name"] and
        -- we match the literal "Codex" the app-name item puts in the title.
        swallow_exception_regex = [=[([✳\x{25A0}-\x{25FF}\x{2800}-\x{28FF}].*|.*\bCodex\b.*)]=],
        -- hyprlock 0.9.2 SEGV'd on teardown and orphaned the session lock;
        -- with this on, a respawned hyprlock (lock-wrapper.sh / `lockfix`)
        -- re-attaches instead of the "oopsie daisy" screen.
        allow_session_lock_restore = true,
    },

    -- Window grouping (tabs)
    group = {
        col = {
            border_active   = { colors = { "rgba(f5a623ff)", "rgba(e875a1ff)" }, angle = 45 },
            border_inactive = "rgba(6b8cae88)",
        },
        groupbar = {
            enabled     = true,
            font_family = "FiraCode Nerd Font",
            font_size   = 10,
            height      = 18,
            col = {
                active   = "rgba(f5a623dd)",
                inactive = "rgba(1e1c23cc)",
            },
            text_color = "rgba(e8e0d6ff)",
            rounding   = 6,
            gaps_in    = 3,
            gaps_out   = 3,
        },
    },

    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = false },
    },

    -- Warp the cursor to the monitor of the workspace you switch to. Without
    -- this, follow_mouse=1 + a cursor parked on the other monitor steals focus
    -- right back after Super+N (an empty workspace has no window to hold it).
    cursor = { warp_on_change_workspace = 1 },
})
