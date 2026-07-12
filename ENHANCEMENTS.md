# Hyprland Enhancement Plan

What we're adding to the rice, why, and how.

---

## Planned Additions

### 1. Hyprspace — Workspace Overview

**What:** macOS Mission Control-style workspace overview. Press a key and see all your workspaces as miniatures with live window previews. Click to switch, drag windows between workspaces.

**Why:** Your config already has workspace keybinds (Super+1-9), but there's no visual overview. This gives you spatial awareness of everything running across all workspaces at a glance.

**Install:** `hyprlandPlugins.hyprspace` in nixpkgs, or via the Hyprland plugins flake.

**Config:**
```
plugin:overview {
  centerAligned = true
  dragAlpha = 0.5
  autoDrag = true
  exitOnClick = true
  switchOnDrop = true
  exitOnSwitch = true
}
bind = SUPER, tab, overview:toggle
```

**Note:** Hyprspace and Hyprexpo serve similar purposes. We'll bind them to different keys — Hyprspace for the full Mission Control view, Hyprexpo for a quick grid peek.

---

### 2. Hyprtrails — Window Trail Effects

**What:** Renders smooth motion trails behind windows as you drag or move them. Uses Bezier curves and OpenGL shaders. Purely aesthetic.

**Why:** Instant visual flair. Every window drag leaves a colorful streak that matches your Gold-to-Rose theme. Makes the desktop feel alive and reactive.

**Install:** `hyprlandPlugins.hyprtrails` (part of the official `hyprwm/hyprland-plugins` repo).

**Config (themed to match Gold-to-Rose):**
```
plugin:hyprtrails {
  color = rgba(e8a854ff)
  bezier_step = 0.025
  points_per_step = 2
  history_points = 20
}
```

**Performance note:** If you notice lag, increase `bezier_step` (less smooth but lighter) or decrease `history_points` (shorter trails).

---

### 3. Hyprexpo — Workspace Grid Overview

**What:** Expose-style workspace overview that displays all workspaces in a grid of live previews. Quick visual switching.

**Why:** Complements Hyprspace — Hyprexpo is a lighter, snappier grid view. Good for fast workspace switching when you know roughly where things are.

**Install:** `hyprlandPlugins.hyprexpo` (official `hyprwm/hyprland-plugins` repo).

**Config:**
```
plugin:hyprexpo {
  columns = 3
  gap_size = 5
  bg_col = rgb(1e1c23)
  workspace_method = center current
  enable_gesture = true
}
bind = SUPER, grave, hyprexpo:expo, toggle
```

**Note:** This replaces the current Super+grave dropdown terminal bind. We'll move the dropdown terminal to a different key (e.g., Super+F1).

---

### 4. Pyprland — Hyprland Companion Daemon

**What:** A Python-based daemon that extends Hyprland with a plugin system. Key features: advanced scratchpads (dropdown apps with animations), magnifier/zoom, expose (window overview), wallpaper management, layout center mode.

**Why:** Your config already has a basic dropdown terminal via special workspaces. Pyprland's scratchpad system is more polished — proper slide-in animations, per-app sizing, and you can have multiple scratchpads (terminal, volume control, music player, etc.) each with their own animation direction.

**Install:** `pkgs.pyprland` in nixpkgs.

**Config (`~/.config/hypr/pyprland.toml`):**
```toml
[pyprland]
plugins = ["scratchpads", "magnify"]

[scratchpads.term]
animation = "fromTop"
command = "kitty --class kitty-dropterm"
class = "kitty-dropterm"
size = "75% 60%"

[scratchpads.volume]
animation = "fromRight"
command = "pavucontrol"
class = "org.pulseaudio.pavucontrol"
size = "40% 90%"

[scratchpads.music]
animation = "fromBottom"
command = "kitty --class kitty-cava cava"
class = "kitty-cava"
size = "90% 30%"
```

**Hyprland binds:**
```
exec-once = pyprland
bind = SUPER, Z, exec, pypr toggle term
bind = SUPER, X, exec, pypr toggle volume
bind = SUPER, C, exec, pypr toggle music
bind = SUPER, equal, exec, pypr zoom
```

---

### 5. Wlogout — Graphical Logout/Power Menu (ADDED)

**What:** A fullscreen graphical power menu with big, styled buttons for lock, logout, suspend, shutdown, reboot, hibernate.

**Why:** Replaces the small waybar power menu dropdown with something much more visual and satisfying. Full-screen overlay with blur, themed buttons, keyboard shortcuts.

**Install:** `pkgs.wlogout` in nixpkgs.

**Config (layout JSON + CSS styled to Gold-to-Rose theme):**
```json
[
  { "label": "lock",      "action": "hyprlock",              "text": "Lock",      "keybind": "l" },
  { "label": "logout",    "action": "hyprctl dispatch exit",  "text": "Logout",    "keybind": "e" },
  { "label": "suspend",   "action": "systemctl suspend",      "text": "Suspend",   "keybind": "u" },
  { "label": "shutdown",  "action": "systemctl poweroff",     "text": "Shutdown",  "keybind": "s" },
  { "label": "reboot",    "action": "systemctl reboot",       "text": "Reboot",    "keybind": "r" },
  { "label": "hibernate", "action": "systemctl hibernate",    "text": "Hibernate", "keybind": "h" }
]
```

**CSS:**
```css
window { background-color: rgba(30, 28, 35, 0.85); }
button {
  color: #e8e0d6;
  background-color: #2a2630;
  border: 2px solid #4a4655;
  border-radius: 20px;
  margin: 10px;
}
button:hover { background: linear-gradient(45deg, #e8a854, #e875a1); color: #1e1c23; }
```

**Bind:**
```
bind = SUPER, escape, exec, wlogout -b 4
```

---

### 6. Cava — Audio Visualizer (ADDED)

**What:** Real-time bar spectrum audio visualizer in the terminal. Bars dance to whatever audio is playing.

**Why:** It looks incredible. Themed with your Gold-to-Rose gradient, it turns any terminal into a music visualizer. Can also run as a Pyprland scratchpad that slides up from the bottom.

**Install:** `pkgs.cava` in nixpkgs.

**Config (`~/.config/cava/config`, Gold-to-Rose themed):**
```ini
[general]
bars = 0
bar_width = 2
bar_spacing = 1
framerate = 60

[input]
method = pulse
source = auto

[output]
method = ncurses
channels = stereo

[color]
gradient = 1
gradient_count = 5
gradient_color_1 = '#6b8cae'
gradient_color_2 = '#e8a854'
gradient_color_3 = '#f5a623'
gradient_color_4 = '#d4848c'
gradient_color_5 = '#e875a1'
```

---

### 7. Fastfetch — System Info Splash (ADDED)

**What:** A fast, customizable system info display (neofetch successor). Shows OS, kernel, WM, CPU, GPU, memory, etc. with ASCII art.

**Why:** Quick flex every time you open a terminal. One line in fish config and you get a themed info splash with your NixOS + Hyprland + RTX 5090 specs.

**Install:** `pkgs.fastfetch` in nixpkgs.

**Fish integration (add to config.fish):**
```fish
if status is-interactive
    fastfetch
end
```

---

### 8. Btop — System Monitor (ADDED)

**What:** A beautiful terminal resource monitor with CPU, memory, disk, network graphs and process management. Like htop but far prettier.

**Why:** Replaces `htop` in your config. With terminal transparency (already set to 0.92 in kitty), btop's graphs will show through with your wallpaper behind them. Use vim keys for navigation.

**Install:** `pkgs.btop` in nixpkgs (replace `htop`).

**Config:**
```
theme_background = false
vim_keys = true
rounded_corners = true
update_ms = 1000
proc_sorting = "cpu lazy"
proc_tree = true
```

---

## More Ideas

Below are additional enhancements worth considering. Each one is independent — pick and choose.

---

### hypr-dynamic-cursors — Cursor Physics + Shake to Find

Adds realistic cursor rotation based on movement direction and a "shake to find" feature (shake your mouse and the cursor grows large so you can spot it). A small but satisfying touch.

**Install:** `hyprlandPlugins.hypr-dynamic-cursors`

**Example config:**
```
plugin:dynamic-cursors {
  enabled = true
  mode = rotate

  shake {
    enabled = true
    threshold = 4.0
    speed = 4.0
  }
}
```

---

### mpvpaper — Video Wallpapers

Use any video as your desktop wallpaper via mpv. Looping cyberpunk cityscapes, flowing lava, northern lights — whatever you want. Combine with `hyprwinwrap` to embed any app (even cava!) as a wallpaper layer.

**Install:** `pkgs.mpvpaper`

**Example:**
```bash
# Set a looping video wallpaper
mpvpaper -o "no-audio loop" '*' ~/Videos/Wallpapers/cyberpunk-rain.mp4
```

---

### Hyprshade — Screen Shader Effects

Apply GLSL shaders to your entire screen — vibrance boost, blue-light filter, grayscale, retro CRT effect. Can be scheduled (blue-light filter at sunset, vibrance during the day).

**Install:** `pkgs.hyprshade`

**Example:**
```bash
# Apply vibrance shader
hyprshade on vibrance

# Schedule blue-light filter at sunset
hyprshade auto

# Toggle on/off
hyprshade toggle blue-light-filter
```

**Config (`~/.config/hypr/hyprshade.toml`):**
```toml
[[shades]]
name = "vibrance"
default = true

[[shades]]
name = "blue-light-filter"
start_time = 19:00:00
end_time = 06:00:00
```

---

### hyprbars — macOS-Style Window Title Bars

Adds customizable title bars with close/maximize/minimize buttons to your windows. Can be styled to match your theme with custom colors and button layouts.

**Install:** `hyprlandPlugins.hyprbars`

**Example config:**
```
plugin:hyprbars {
  bar_height = 30
  bar_color = rgb(2a2630)
  col.text = rgb(e8e0d6)
  bar_text_font = JetBrains Mono Nerd Font
  bar_text_size = 11

  hyprbars-button = rgb(e85a5a), 14, 󰖭, hyprctl dispatch killactive
  hyprbars-button = rgb(e8a854), 14, , hyprctl dispatch fullscreen 1
  hyprbars-button = rgb(a8c686), 14, , hyprctl dispatch togglefloating
}
```

---

### wob — Volume/Brightness Overlay Bar

A minimal overlay progress bar that briefly appears on screen when you change volume or brightness. Cleaner than notification-based OSD.

**Install:** `pkgs.wob`

**Example (in hyprland.conf):**
```
exec-once = mkfifo /tmp/wobpipe && tail -f /tmp/wobpipe | wob --background-color '#1e1c23CC' --bar-color '#e8a854FF' --border-color '#4a4655FF'

# Volume keys pipe to wob
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}' > /tmp/wobpipe
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}' > /tmp/wobpipe
```

---

### nwg-look — GTK Theme Editor

GUI editor for GTK themes, icons, cursors, and fonts on Wayland. Essential for making GTK apps (Firefox, Dolphin, etc.) match your Hyprland rice instead of looking like default GNOME.

**Install:** `pkgs.nwg-look`

**Example usage:**
```bash
nwg-look  # opens the GUI, select your theme/icons/cursor
```

---

### Walker — Wayland Application Launcher

A highly customizable launcher with built-in modules: app launching, calculator, emoji picker, AI chat, clipboard, SSH connections, and a Hyprland keybind browser. A modern alternative to rofi.

**Install:** `pkgs.walker`

**Example config (`~/.config/walker/config.toml`):**
```toml
[search]
placeholder = "Search..."
delay = 0

[list]
max_entries = 50

[modules.applications]
weight = 5
name = "apps"

[modules.calc]
weight = 1

[modules.emojis]
weight = 1
```

---

### satty — Screenshot Annotation

A Wayland-native screenshot annotation tool. Pipe grim/slurp output into satty to draw arrows, rectangles, text, highlights on screenshots before saving or copying. Like Flameshot but for Wayland.

**Install:** `pkgs.satty`

**Example (replace your screenshot bind):**
```
bind = , F9, exec, grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png
```

---

### wl-kbptr — Keyboard Mouse Control

Control your mouse pointer entirely from the keyboard. Screen divides into a labeled grid; type a label to jump the cursor there, then refine with bisection. Ideal for keyboard-centric workflows where you rarely want to touch the mouse.

**Install:** `pkgs.wl-kbptr`

**Example (in hyprland.conf):**
```
bind = SUPER, period, exec, wl-kbptr
```

---

### Fabric — Python Widget Framework

A next-gen framework for building custom desktop widgets in Python. Native Hyprland support, extensive widget library. If you want to build truly custom widgets beyond what AGS/Eww offer, and you prefer Python over TypeScript.

**Example widget:**
```python
from fabric.widgets import Window, Label, Box
from fabric.utils import monitor_file

window = Window(
    title="my-widget",
    children=Box(children=[
        Label("Hello from Fabric!")
    ])
)
window.show_all()
```

---

### HyprPanel — All-in-One Panel

A comprehensive panel/bar built on AGS/Astal with batteries-included: notification center, media controls, dashboard, bluetooth manager, network manager, volume mixer, system tray, and automatic Material You theming from your wallpaper via matugen. Could replace both your waybar and AGS dashboard.

**Install:** `pkgs.hyprpanel`

**Why consider it:** You currently run waybar + AGS separately. HyprPanel combines both into one cohesive system with automatic color theming that adapts to your wallpaper.

---

### Hyprwinwrap — App-as-Wallpaper

An official Hyprland plugin that lets you embed any window as your wallpaper layer. Run cava, a terminal with cmatrix, a WebGL animation, or anything else *behind* all your windows as a living wallpaper.

**Install:** `hyprlandPlugins.hyprwinwrap`

**Example:**
```
plugin:hyprwinwrap {
  class = kitty-bg
}
```

Then launch: `kitty --class kitty-bg cava` — and cava becomes your wallpaper.

---

### CMatrix + Hyprwinwrap — Matrix Rain Wallpaper

Combine cmatrix (the Matrix digital rain effect) with hyprwinwrap to have Matrix-style rain running behind all your windows. Pure aesthetic overload.

```bash
kitty --class kitty-bg -o background_opacity=0.3 cmatrix -C green
```

---

## Planned Sessions (TODO)

### Expand the greeter quotes file
`greeter/quotes.txt` feeds the random login-screen quote (picked by the
tuigreet launch script in `configuration.nix`). Dedicate a future session to
growing it: more Terry Pratchett, Psalms, ancient works in translation,
Ulysses, David Foster Wallace, and whatever else fits. **Real quotes only —
verify each one before adding.** One quote per line, `Quote — Attribution`
format; `#` comments and blank lines are ignored. Changes apply on the next
`nh os switch` (the file is embedded at build time).

### dwl: keybind parity + bar (minimal config.h DONE)
`dwl/config.h` exists (v0.7 config.def.h base) and is compiled in via
`pkgs.dwl.override { configH = ./dwl/config.h; }` in configuration.nix.
Done: Super as MODKEY, kitty term, rofi launcher, hyprland border colors,
parity binds Super+Q (terminal), Super+R (launcher), Super+C (kill),
Super+Shift+Ctrl+M (quit). Stock dwl binds all still work (Super+Shift+Enter
terminal, Super+j/k focus, Super+1-9 tags, Super+Shift+Q quit, Super+t/f/m
layouts).
Also done (second pass): session stack via `dwl -s dwl/startup.sh` — swww
wallpaper (reuses hypr wallpaper.sh), mako, dwlb bar (gold/slate theme,
clock via `dwlb -status`), plus volume/media keys (wpctl/playerctl), F9/Print
screenshots mirroring Hyprland, Super+W random wallpaper.
Future session: full keybind parity with hyprland.conf (conflicts to resolve:
Super+F is fullscreen in Hyprland but float-layout in dwl; Super+M is exit in
Hyprland but monocle in dwl — dwl fullscreen is currently Super+E). Tag
*clicking* in dwlb needs dwl's ipc patch (display works without it).
Note: nixpkgs dwl 0.7 now ships its own plain dwl.desktop in the package;
the greeter uses our custom sessionPackages entry (Exec=dwl -s ...), so the
`dwl ships no wayland-session entry` comment in configuration.nix is stale
but harmless.
