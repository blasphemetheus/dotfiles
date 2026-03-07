# Dotfiles

Hyprland desktop config with a Gold-to-Rose theme. Uses GNU Stow for symlink management.

## Structure

Each top-level directory is a stow package that maps into `~/.config/`.

```
hypr/      - Hyprland WM config, scripts, hypridle
waybar/    - Status bar config, styling, custom scripts
mako/      - Notification daemon
kitty/     - Terminal emulator
rofi/      - App launcher + catppuccin theme
fish/      - Fish shell config
nvim/      - Neovim config
helix/     - Helix editor config
lazygit/   - Lazygit config
git/       - Global gitignore
ags/       - AGS widgets (dashboard, bar)
```

## Quick Setup

```bash
# Install stow
# Manjaro: pacman -S stow
# NixOS: add stow to environment.systemPackages

# Clone and stow everything
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
stow */
```

## NixOS Setup

See [NIXOS-SETUP.md](NIXOS-SETUP.md) for full instructions on setting up this config on NixOS with an NVIDIA GPU.
