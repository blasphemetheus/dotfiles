# Testing Checklist

Track what's been implemented and whether it works after `nixos-rebuild switch`.

## How to apply

```fish
# Builds the system and all Home Manager dotfiles in one step (`nrs` is an abbr for this)
sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka
# Then reload Hyprland: Super+Shift+R
```

## Test in a VM before you switch

The safe way to try a risky change (new compositor, display manager, boot, dbus,
kernel, service) is to boot **this exact config** in a throwaway QEMU VM first.
No sudo, no risk to the running system.

```fish
# 1. Build a VM from the current config
nixos-rebuild build-vm --flake ~/dotfiles#nixos_slanka

# 2. Boot it (opens a QEMU window; log in as your normal user)
./result/bin/run-nixos_slanka-vm

# 3. Clean up — the VM's disk image and the GC root
rm -f nixos.qcow2 result
```

`virtualisation.vmVariant` in `configuration.nix` gives the VM 8 GB / 8 cores /
16 GB disk (the defaults are 1 core + 1 GB and are unusably slow).

**What it's good for:** config evaluation, boot, systemd services, display-manager
and session changes, testing a new compositor (niri/river/dwl) without logging out,
package upgrades, `stateVersion` bumps.

**What it can't test:** anything GPU-real. The VM has no RTX 5090 — it's virtio/software
rendering, so Hyprland will be slow and NVIDIA/Vulkan/rwing behavior is meaningless there.
The VM also uses a fresh empty disk, not your real `/home`.

**Gotchas**
- It writes `nixos.qcow2` in the current directory and **reuses it** across runs. Delete it
  to get a clean boot.
- `result` is a GC root — remove it, or `nix.gc` can't collect the old system.
- Your user's password in the VM is whatever `configuration.nix` declares; if you use
  `hashedPassword`, set a known one temporarily or log in as root.
- Use `build-vm-with-bootloader` instead if the change touches systemd-boot/grub.

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
- [x] **wlogout styling** — Gold-to-rose hover effects, unique color per button
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
- [x] **Rofi glass** — Launcher has dark glass look with transparency (blur blocked by overlay layer)
- [x] **Mako glass** — Notifications styled dark glass (blur only works on bottom layer, overlay needed for stacking)
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

- [x] **Lua config** — `hyprland.lua` + `lua/*.lua` replace `hyprland.conf` (hyprlang is dropped in 0.57). Nested test: `HYPR_NO_AUTOSTART=1 Hyprland --config ~/dotfiles/hypr/.config/hypr/hyprland.lua`; live switch needs a relogin. Runtime tweaks are `hyprctl eval 'hl.config{…}'` / `hyprctl dispatch 'hl.dsp.…'` — `hyprctl keyword` is gone. hyprsplit is now a Lua library (`/etc/hypr/hyprsplit/init.lua`), hyprexpo still a .so.
- [x] **Hyprlock theme** — `Super+L`: gold-to-rose over the blurred current wallpaper; greeter banner + random quote, keybind tip, notifications-since-lock, health warnings + live GPU/CPU/RAM/disk panel, now-playing + art, clickable suspend/reboot/poweroff/LED/mute/blue-light (`hyprlock.conf`, `scripts/lock/*.sh`)
- [x] **Waybar GPU temp** — Shows RTX 5090 temp on right side of bar
- [x] **Waybar media** — Shows currently playing song, click to pause, scroll for next/prev
- [x] **Waybar window title** — Shows focused window title/directory in bar
- [x] **Waybar power button** — Power icon opens wlogout
- [x] **Mako DND** — `Super+Shift+D` toggles DND, bell icon in waybar
- [x] **Emoji picker** — `Super+.` opens rofimoji, types emoji via wtype
- [ ] **Bibata cursor** — Modern cursor theme (needs rebuild — bibata-cursors not installed yet)
- [x] **Wallpaper on login** — Random wallpaper from ~/Pictures/Wallpapers on each login (exec-once, shebang fixed)
- [ ] **Wallpaper controls** — `Super+W` picker, `Super+Shift+W` random (needs wallpapers in ~/Pictures/Wallpapers)
- [x] **Floating window glass** — Floating kitty windows more transparent than tiled
- [x] **Dropdown terminal** — `Super+`` toggles quake-style dropdown pinned to top

## Needs `sudo cp ~/dotfiles/configuration.nix /etc/nixos/configuration.nix && sudo nixos-rebuild switch`

- libnotify (notify-send)
- rofimoji (emoji picker)
- bibata-cursors (cursor theme)

## Not Yet Implemented (from ENHANCEMENTS.md)

- [ ] Hyprland animation tuning — test and fine-tune bounce/elastic curves
- [x] greetd theme — boot autologs into Hyprland which locks immediately, so hyprlock IS the login screen; tuigreet (banner + quote from /etc/greeter) is the fallback after logout
- [ ] hyprbars — window title bars (version mismatch with Hyprland 0.54, needs flake)
- [ ] Hyprspace — BLOCKED: plugin 0.53 doesn't build on Hyprland 0.54, wait for nixpkgs update
- [ ] Hyprtrails — BLOCKED: plugin 0.53 doesn't build on Hyprland 0.54, wait for nixpkgs update
- [ ] Hyprexpo — BLOCKED: plugin 0.53 doesn't build on Hyprland 0.54, wait for nixpkgs update
- [ ] Pyprland — scratchpads: Super+` term, Super+X volume, Super+Shift+X cava, Super+= zoom
- [ ] hypr-dynamic-cursors — cursor rotation + shake-to-find (plugin via nixpkgs)
- [ ] mpvpaper — video wallpapers
- [ ] Hyprshade config — blue-light-filter auto-scheduled 7pm–6am (hyprshade.toml + exec-once)
- [ ] wob — volume/brightness overlay bar
- [ ] Walker — modern launcher on Super+D (rofi stays on Super+R)
- [ ] wl-kbptr — keyboard mouse control (Super+;)
- [ ] HyprPanel — all-in-one panel (installed, commented out in exec-once, uncomment to try)
- [ ] Hyprwinwrap — app-as-wallpaper

## New Tools (needs rebuild + testing)

### Terminals & Shells
- [ ] **ghostty** — launch `ghostty`, compare feel vs kitty
- [ ] **wezterm** — launch `wezterm`, try built-in multiplexer (Ctrl+Shift+T tabs)
- [ ] **nushell** — launch `nu`, try `ls | where size > 1mb`, `sys host`, `ps | where cpu > 5`

### Editors
- [ ] **zed** — `zed .` in a project, check LSP, try AI assistant (Ctrl+Enter)

### Launchers & Bars
- [ ] **anyrun** — launch `anyrun`, compare vs rofi/walker
- [ ] **ironbar** — launch `ironbar`, compare vs waybar

### Hyprland Plugins (need rebuild first)
- [ ] **hypr-dynamic-cursors** — shake mouse fast to enlarge cursor, drag windows to see rotation
- [ ] ~~**hyprtrails**~~ — BLOCKED on 0.54
- [ ] ~~**hyprexpo**~~ — BLOCKED on 0.54
- [ ] ~~**hyprspace**~~ — BLOCKED on 0.54

### Pyprland Scratchpads
- [ ] **dropdown term** — `Super+\`` slides kitty from top
- [ ] **volume** — `Super+X` slides pavucontrol from right
- [ ] **cava** — `Super+Shift+X` slides cava from bottom
- [ ] **zoom** — `Super+=` magnifier

### CLI Tools
- [ ] **sd** — `echo 'hello world' | sd 'world' 'nix'`
- [ ] **tokei** — `tokei` in dotfiles repo
- [ ] **just** — create a `justfile`, run `just`
- [ ] **tldr** — `tldr tar` (run `tldr --update` first)
- [ ] **xh** — `xh httpbin.org/get`
- [ ] **bandwhich** — `sudo bandwhich` (needs root for packet inspection)
- [ ] **hyperfine** — `hyperfine 'ls' 'eza'`
- [ ] **ouch** — `ouch decompress some-archive.tar.gz`
- [ ] **doggo** — `doggo example.com`
- [ ] **duf** — `duf` for disk overview
- [ ] **broot** — `broot` for fuzzy tree explorer (press `/` to search)
- [ ] **navi** — `navi` for interactive cheatsheets
- [ ] **choose** — `echo 'one two three' | choose 1`
- [ ] **serpl** — `serpl` in a project dir for TUI search/replace
- [ ] **felix** — `fx` for Rust file manager
- [ ] **bob** — `bob install stable` for neovim version management

### New Features (needs rebuild + Hyprland reload)
- [ ] **Window grouping** — `Super+G` on two tiled windows to group them into tabs. `Super+Tab` to cycle tabs. `Super+Ctrl+G` to ungroup
- [ ] **Yazi scratchpad** — `Super+Y` slides yazi file browser from right (60%x80%, 0.9 opacity)
- [ ] **Per-workspace wallpapers** — Create `~/Pictures/Wallpapers/ws-1/`, `ws-2/` etc. with images, switch workspaces to see wallpaper change
- [ ] **Window swallowing** — From kitty, run `mpv somefile` or `firefox` — kitty should hide, reappear when app closes
- [ ] **Power profiles** — `Super+F6` cycles performance/balanced/power-saver, `Super+Shift+F6` for rofi picker
- [ ] **Session save/restore** — `Super+Ctrl+S` to save, `Super+Ctrl+R` to restore (rofi pickers)
- [ ] **Copilot key** — Press Copilot/Assistant key to launch Claude Code

### Other
- [ ] **walker** — `Super+D` launches walker
- [ ] **wl-kbptr** — `Super+;` keyboard mouse grid
- [ ] **hyprshade** — check blue-light-filter activates after 7pm
- [ ] **claude-code-upgrade timer** — `systemctl --user status claude-code-upgrade.timer`
