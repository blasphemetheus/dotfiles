# Hyprland Keybinds Cheatsheet

## Function Keys

| Key | Action |
|-----|--------|
| F9 | Screenshot area (select region) -> clipboard + ~/Pictures/Screenshots/ |
| F10 | Clipboard history (wofi picker) |
| F11 | Toggle fullscreen |
| F12 | Toggle dictation (speak → text typed into focused window) |
| Super+Space (hold) | Push-to-talk dictation (release to transcribe) |
| Fn+Space | Keyboard backlight (hardware - 3 levels) |

## Screenshots & Recording

| Shortcut | Action |
|----------|--------|
| F9 | Screenshot area -> clipboard + save |
| Print | Screenshot full screen -> clipboard + save |
| Super+Shift+R | Toggle screen recording (select area, press again to stop) |
| Super+Shift+C | Color picker (click to copy hex color) - *needs system upgrade* |

Recordings saved to: `~/Videos/recording_*.mp4`
Screenshots saved to: `~/Pictures/Screenshots/`

## Window Management

| Shortcut | Action |
|----------|--------|
| Super+C | Close window |
| Super+V | Toggle floating |
| Super+F | Toggle fullscreen |
| F11 | Toggle fullscreen |
| Super+P | Pseudo-tile (dwindle) |
| Super+J | Toggle split direction |
| Alt+Tab | Cycle windows forward |
| Alt+Shift+Tab | Cycle windows backward |
| Super+Shift+Space | Center floating window |
| Super+Shift+P | Pin window (visible on all workspaces) |

## Focus & Movement

| Shortcut | Action |
|----------|--------|
| Super+Arrow | Move focus |
| Super+Shift+Arrow | Move window |
| Super+Ctrl+Arrow | Resize window |
| Super+LMB drag | Move window (mouse) |
| Super+RMB drag | Resize window (mouse) |

## Workspaces

| Shortcut | Action |
|----------|--------|
| Super+1-0 | Switch to workspace 1-10 |
| Super+Shift+1-0 | Move window to workspace 1-10 |
| Super+Scroll | Scroll through workspaces |
| Super+S | Toggle scratchpad |
| Super+Shift+S | Move window to scratchpad |
| Super+\` | **Dropdown terminal** (quake-style!) |
| Super+N | **Notification center** (slides from right) |

## Apps & Utilities

| Shortcut | Action |
|----------|--------|
| Super+Q | Terminal (kitty) |
| Super+E | File manager (dolphin) |
| Super+R | App launcher (rofi) |
| Super+L | Lock screen (hyprlock) |
| Super+M | Exit Hyprland |
| Super+Shift+H | Retrain HDMI link (curved ASUS says "no signal") |
| Super+Shift+? | **Show this keybinds cheatsheet!** |

## Media Keys (Fn row)

| Key | Action |
|-----|--------|
| F1 | Mute speakers |
| F2 | Volume down |
| F3 | Volume up |
| F4 | Mute microphone |
| F5 | Screen brightness down |
| F6 | Screen brightness up |
| F7 | Display switch (external monitor) |
| F8 | Airplane mode |

---

## Freaky Features Installed

### Visual Effects
- **RGB Animated Borders** - Rainbow gradient borders that animate!
- **Bouncy Animations** - Windows pop and slide with bounce effects
- **Dim Inactive** - Unfocused windows are slightly dimmed
- **Blur + Transparency** - Kitty terminal is semi-transparent with blur
- **Floating Waybar** - Modern pill-shaped status bar

### Workspace Rules
- **Workspace 2** - Extra chill vibes (wider gaps)
- **Workspace 3** - Focused coding mode (tight gaps, Code opens here)

### Window Rules
- **Dropdown Terminal** - Press \` for quake-style terminal from top
- **Picture-in-Picture** - Firefox PiP auto-floats and pins
- **File Dialogs** - Open/Save dialogs auto-float

### Theme
- **Waybar** - Catppuccin Mocha with gradient accents
- **Rofi** - Catppuccin themed launcher (Super+R)
- **Mako** - Fancy rounded notifications

---

## Still Need System Upgrade For:

Run this to fix npm conflicts and enable remaining features:
```bash
sudo rm -rf /usr/lib/node_modules/npm/node_modules
sudo pacman -Syu
```

Then install:
```bash
# Animated wallpapers
sudo pacman -S swww

# AUR packages (use yay or paru)
yay -S hyprshade eww
```

### After upgrade, you can add:
- **hyprpicker** - Color picker (Super+Shift+C already bound)
- **swww** - Animated/video wallpapers
- **hyprshade** - Blue light filter & CRT effects
- **hyprpm plugins** - hyprtrails (cursor trails), hyprexpo (overview)
- **eww** - Desktop widgets

---

## Tips

- **Dropdown Terminal**: Press Super+\` for a quick terminal that slides from top
- **Scratchpad**: Hidden workspace for apps you want quick access to
- **Pin**: Pinned windows stay visible when switching workspaces
- **Pseudo-tile**: Window respects its preferred size but stays in tiled layout
- **RGB Borders**: Watch your active window border cycle through rainbow colors!
