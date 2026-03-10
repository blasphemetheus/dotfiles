# Testing Checklist

Track what's been implemented and whether it works after `nixos-rebuild switch`.

## How to apply

```bash
sudo cp ~/dotfiles/configuration.nix /etc/nixos/configuration.nix
cd ~/dotfiles && stow wlogout cava git starship
sudo nixos-rebuild switch
# Then reload Hyprland: Super+Shift+R
```

---

## Core Fixes

- [x] **greetd/tuigreet** — Login screen works, can log out and back in without gray screen
- [x] **NVIDIA powerManagement** — No DRM errors in `journalctl -b -k | grep nvidia`
- [x] **NVIDIA env vars** — Hyprland renders properly (no blank windows)
- [x] **Polkit systemd service** — Auth prompts appear for sudo GUI apps (`systemctl --user status polkit-gnome-agent`)
- [x] **graphical-session.target** — Doesn't activate under greetd; polkit started directly via exec-once instead
- [x] **Hyprland 0.54 windowrule blocks** — No config errors on reload (`Super+Shift+R`), all named windowrule blocks parse cleanly
- [x] **hyprpaper removed** — No conflict with swww (`swww img` works, wallpaper.sh works)
- [x] **fish as default shell** — New terminals open fish, not bash

## CLI Tools

- [x] **bat** — `bat ~/.config/fish/config.fish` shows syntax highlighting
- [x] **eza** — `ls` shows icons and git status, `ll` for long listing, `lt` for tree
- [x] **fd** — `find .config` finds files fast
- [x] **ripgrep** — `grep "exec-once" ~/.config/hypr/` works
- [x] **delta** — `git diff` shows side-by-side colored diff (configured via `~/.config/git/config`)
- [x] **dust** — `du` shows visual disk usage
- [x] **procs** — `ps` shows process table with colors
- [x] **fastfetch** — Shows system info on first terminal per session
- [x] **btop** — `top` or `btop` opens resource monitor (`Super+T` keybind added)

## Terminal Upgrades

- [x] **starship** — Prompt shows git branch, language versions, cmd duration. Gold-to-Rose themed
- [x] **yazi** — `y` opens file manager with image preview. Press `q` to cd into last directory
- [x] **zellij** — `zellij` opens multiplexer. Try tabs (`Alt+t`), panes (`Alt+n`), floating (`Alt+f`)
- [x] **glow** — `md README.md` or `glow README.md` renders markdown beautifully in terminal

## New Apps

- [x] **wlogout** — `Super+Escape` opens power menu with 6 buttons
- [x] **wlogout lock** — `l` key locks screen from wlogout
- [ ] **wlogout other keys** — e=logout, u=suspend, r=reboot, s=shutdown, h=hibernate
- [ ] **wlogout styling** — Dark theme with gold hover, matches rice
- [x] **cava** — `cava` shows audio visualizer bars with Gold-to-Rose gradient
- [x] **cava audio** — Bars react to audio playing (test with music/video)
- [x] **nwg-look** — Dark GTK theme + Papirus icons set
- [x] **satty** — `Shift+F9` takes screenshot, opens annotation editor

## Claude Code Title

- [x] **Super+A launch** — Window title shows "Claude Code", has own window class
- [ ] **CLI launch** — Run `claude` from any terminal, title changes to "Claude Code: <dir>"
- [ ] **Opacity** — Claude Code windows slightly more opaque than regular kitty (0.88 vs 0.82)

## Liquid Metal Visual Pass

- [x] **Waybar glass** — Bar modules are translucent with blur behind, metallic border glow
- [ ] **Rofi glass** — Launcher has frosted glass look with blur
- [ ] **Mako glass** — Notifications are translucent with blur (needs `notify-send` — install libnotify)
- [x] **Hyprland blur** — Blur is heavier (size 12, 4 passes), supports all layers
- [x] **Layer blur** — Waybar, rofi, wofi, notifications all have blur-behind via layerrules
- [ ] **Readability** — Text is still comfortable to read at new opacity levels (adjust if too transparent)

## Dev Environment

- [x] **VS Code** — `code` command opens VS Code
- [x] **direnv** — `cd ~/git/nx-callback-refactor` auto-activates devenv (run `direnv allow` first time)
- [ ] **devenv shell** — Elixir, Erlang, CUDA all available after direnv activates
- [ ] **code from project** — `cd ~/git/nx-callback-refactor && code .` opens VS Code with devenv loaded

## Fish Shell

- [x] **Aliases work** — `cat`, `ls`, `ll`, `lt`, `find`, `grep`, `du`, `ps`, `diff`, `top`, `md` all use modern tools
- [x] **No /home/dori errors** — No broken path warnings on shell start
- [x] **fastfetch on start** — System info shows on first terminal per session
- [x] **starship prompt** — Prompt shows directory, git info, language versions (not default fish prompt)
- [x] **direnv hook** — No errors about direnv on shell start

## New This Session (needs testing)

- [x] **Hyprlock theme** — `Super+L` shows gold-to-rose lock screen with blur, time, date, password field
- [ ] **Waybar GPU temp** — Shows RTX 5090 temp on right side of bar
- [ ] **Waybar media** — Shows currently playing song, click to pause, scroll for next/prev
- [ ] **Waybar window title** — Shows focused window title/directory in bar
- [ ] **Waybar power button** — Power icon opens wlogout
- [ ] **Mako DND** — `Super+Shift+D` to toggle Do Not Disturb (needs libnotify for notify-send)
- [ ] **Emoji picker** — `Super+.` opens rofimoji (needs rebuild — rofimoji not installed yet)
- [ ] **Bibata cursor** — Modern cursor theme (needs rebuild — bibata-cursors not installed yet)
- [ ] **Wallpaper on login** — Random wallpaper from ~/Pictures/Wallpapers on each login
- [ ] **Wallpaper controls** — `Super+W` picker, `Super+Shift+W` random (needs wallpapers in ~/Pictures/Wallpapers)
- [x] **Floating window glass** — Floating kitty windows more transparent than tiled
- [x] **Dropdown terminal** — `Super+`` toggles quake-style dropdown pinned to top

## Needs `sudo cp ~/dotfiles/configuration.nix /etc/nixos/configuration.nix && sudo nixos-rebuild switch`

- libnotify (notify-send)
- rofimoji (emoji picker)
- bibata-cursors (cursor theme)

## Not Yet Implemented (from ENHANCEMENTS.md)

- [ ] Hyprland animation tuning — test and fine-tune bounce/elastic curves
- [ ] greetd theme — tuigreet is plain text, could use a visual greeter
- [ ] hyprbars — window title bars (version mismatch with Hyprland 0.54, needs flake)
- [ ] Hyprspace — workspace overview plugin
- [ ] Hyprtrails — window trail effects plugin
- [ ] Hyprexpo — workspace grid overview plugin
- [ ] Pyprland — scratchpad daemon
- [ ] hypr-dynamic-cursors — cursor physics
- [ ] mpvpaper — video wallpapers
- [ ] Hyprshade config — blue-light-filter scheduling
- [ ] wob — volume/brightness overlay bar
- [ ] Walker — modern launcher
- [ ] wl-kbptr — keyboard mouse control
- [ ] HyprPanel — all-in-one panel
- [ ] Hyprwinwrap — app-as-wallpaper
