-- Environment. env applies at compositor START, not on reload.
local home = os.getenv("HOME") or ""

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- NVIDIA Wayland — required for proper GPU rendering. Only when the driver is
-- actually loaded: this config is shared with the laptop (AMD iGPU), where
-- forcing these breaks VA-API and GLX.
local nvidia = io.open("/proc/driver/nvidia/version", "r")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

-- Keep SDL apps (Godot 4.5+ joypad input is SDL) from exclusively claiming
-- the GC adapter (057e:0337) via HIDAPI/libusb — it blocks Slippi Dolphin's
-- direct adapter access ("Error Opening Adapter: Resource Busy", 2026-08-06).
-- Controllers still reach SDL apps through evdev; only the raw WUP-028
-- driver is disabled.
hl.env("SDL_JOYSTICK_HIDAPI_GAMECUBE", "0")
