# Hyprland Freaky Setup Summary

This documents all the customizations made to your Hyprland setup.

---

## Visual Effects

### RGB Animated Borders
Your active window border cycles through rainbow colors!
- Location: `~/.config/hypr/hyprland.conf` (line ~95)
- Colors: Red -> Orange -> Yellow -> Green -> Blue -> Indigo -> Violet
- Animation: Continuously rotating gradient

### Bouncy Window Animations
Windows pop, slide, and bounce when opening/closing/moving.
- Custom bezier curves: `bounce`, `overshot`, `elastic`
- Effects: popin, slide, slidevert for different contexts
- Workspace switching has overshoot slide effect

### Dim Inactive Windows
Unfocused windows are dimmed 15% to help you focus.
- `dim_inactive = true`
- `dim_strength = 0.15`

### Blur & Transparency
- Kitty terminals: 92% opacity (88% when inactive)
- Background blur: 8px size, 3 passes
- Blur on popups enabled

### Enhanced Shadows
- Larger shadow range (8px)
- Subtle offset for depth

---

## Workspaces

### Workspace 2 - Chill Mode
- Wider gaps (8px inner, 30px outer)
- Perfect for casual browsing

### Workspace 3 - Focus Mode
- Tight gaps (2px inner, 5px outer)
- VSCode automatically opens here
- Maximum screen real estate

### Dropdown Terminal (Special Workspace)
- Press `Super+\`` to toggle
- Slides from top of screen
- 40% screen height, semi-transparent
- Auto-spawns kitty when first opened

---

## Keybinds Added

| Shortcut | Action |
|----------|--------|
| Super+\` | Dropdown terminal |
| Super+F | Fullscreen toggle |
| Super+L | Lock screen |
| Super+Shift+R | Screen recording toggle |
| Super+Shift+C | Color picker (needs upgrade) |
| Super+Shift+P | Pin window |
| Super+Shift+Space | Center floating window |
| Super+Shift+Arrows | Move window |
| Super+Ctrl+Arrows | Resize window |
| Alt+Tab | Cycle windows |
| Print | Full screenshot |
| F9 | Area screenshot |
| F10 | Clipboard history |
| F11 | Fullscreen |
| Super+N | Notification history |

---

## Themed Components

### Waybar (`~/.config/waybar/`)
- **Theme**: Catppuccin Mocha
- **Style**: Floating bar with pill-shaped module groups
- **Colors**:
  - CPU: Green (#a6e3a1)
  - Memory: Purple (#cba6f7)
  - Network: Blue (#89b4fa)
  - Battery: Green/Yellow/Red based on level
  - Active workspace: Pink gradient

### Rofi (`~/.config/rofi/`)
- **Theme**: Catppuccin Mocha
- **Style**: Centered floating window with rounded corners
- **Border**: Purple accent (#cba6f7)
- **Icons**: Papirus theme
- **Modes**: Apps, Run, Windows, Files

### Mako Notifications (`~/.config/mako/`)
- **Style**: Rounded corners (15px), colored borders
- **Position**: Top-right
- **Colors by urgency**:
  - Low: Gray border
  - Normal: Purple border
  - Critical: Red border, no timeout
- **App-specific colors**: Spotify (green), Discord (blue), Firefox (orange)

---

## Window Rules

### Auto-Float
- Firefox Picture-in-Picture (also pins)
- File open/save dialogs

### Transparency
- Kitty: 92% active, 88% inactive
- Dropdown terminal: 90%

### Animations
- Wofi/Rofi: slide animation
- Dropdown terminal: slidevert animation

---

## Files Modified/Created

```
~/.config/hypr/
├── hyprland.conf      # Main config (heavily modified)
├── keybinds.md        # Keybind cheatsheet
└── FREAKY-SETUP.md    # This file

~/.config/waybar/
├── config.jsonc       # Waybar modules (unchanged)
└── style.css          # Catppuccin theme (replaced)

~/.config/rofi/
├── config.rasi        # Rofi configuration (new)
└── catppuccin.rasi    # Rofi theme (new)

~/.config/mako/
└── config             # Notification styling (new)

~/Pictures/Screenshots/ # Screenshot storage (created)
~/Videos/               # Recording storage (created)
```

---

## Still Pending (After System Upgrade)

### Fix npm conflicts first:
```bash
sudo rm -rf /usr/lib/node_modules/npm/node_modules
sudo pacman -Syu
```

### Then install:
```bash
# Animated wallpapers
sudo pacman -S swww

# Color picker (already bound to Super+Shift+C)
# Should work after upgrade - hyprpicker is installed

# Optional AUR packages
yay -S hyprshade    # Blue light filter, CRT effects
yay -S eww          # Desktop widgets
```

### Hyprland Plugins (after upgrade):
```bash
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable hyprtrails   # Cursor trails
hyprpm enable hyprexpo     # Window overview (like macOS)
```

---

## Quick Reference

**Dropdown terminal**: `Super+\``
**App launcher**: `Super+R`
**Screenshot area**: `F9`
**Clipboard history**: `F10`
**Notification history**: `Super+N`
**Lock screen**: `Super+L`

**Cheatsheet**: `cat ~/.config/hypr/keybinds.md`
**This file**: `cat ~/.config/hypr/FREAKY-SETUP.md`
