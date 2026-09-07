-- Monitors. Same descriptors the scripts use (hdmi-wake.sh, refresh-toggle.sh
-- re-issue hl.monitor{} via `hyprctl eval` to bounce refresh rates).
--
-- ASUS VG27V defaults to 120Hz: the 165Hz HDMI link is bandwidth-marginal
-- (see hdmi-wake.sh / hdmi-retrain.sh); Super+Shift+F toggles up to 165Hz.
-- vrr=1 is aspirational on the HDMI-only VG27V (NVIDIA does no FreeSync over
-- HDMI); the slippi-tearing rule is the low-latency path instead.
-- Explicit positions (auto-placement flipped sides once): VG27V main at 0x0,
-- VY279HGR physically to its RIGHT so it starts at 1920x0.

-- Catch-all for anything unlisted. "preferred", NOT highrr: the Toshiba TV's
-- highest-refresh mode is 800x600@60.32, which highrr picked over 1080p@60.00.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, vrr = 1 })

-- Toshiba TV (Fire TV's screen) on the HDMI port when the ASUS is unplugged.
hl.monitor({
    output   = "desc:Toshiba America Info Systems Inc TOSHIBA-TV 0x00000001",
    mode     = "1920x1080@60",
    position = "3840x0",
    scale    = 1,
})

hl.monitor({
    output   = "desc:ASUSTek COMPUTER INC ASUS VG27V 0x0003ABEC",
    mode     = "1920x1080@120",
    position = "0x0",
    scale    = 1,
    vrr      = 1,
})

-- ASUS VY279HGR (DP-2): 100Hz is its max; Adaptive-Sync over DP.
hl.monitor({
    output   = "desc:ASUSTek COMPUTER INC VY279HGR TCLMTR040596",
    mode     = "1920x1080@100",
    position = "1920x0",
    scale    = 1,
    vrr      = 1,
})
