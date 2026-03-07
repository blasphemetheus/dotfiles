# NixOS Setup Guide

Complete instructions for setting up this Hyprland config on NixOS with an NVIDIA 5090.

## 1. Enable Hyprland and NVIDIA in configuration.nix

```nix
{ config, pkgs, ... }:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # NVIDIA drivers (5090 - use open kernel module)
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;              # Required for 50-series GPUs
    nvidiaSettings = true;
    package = config.hardware.nvidia.package;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # Session / login manager
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

  # Audio (PipeWire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Network
  networking.networkmanager.enable = true;

  # Fonts used by waybar, kitty, rofi, mako
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    font-awesome
    roboto
  ];
}
```

## 2. Install required packages

Add these to `environment.systemPackages` or a home-manager config:

```nix
environment.systemPackages = with pkgs; [
  # Core Hyprland ecosystem
  waybar                  # Status bar
  hyprpaper               # Static wallpaper
  swww                    # Animated wallpaper daemon
  hyprlock                # Lock screen
  hypridle                # Idle manager
  hyprpicker              # Color picker
  xdg-desktop-portal-hyprland

  # Launcher and notifications
  rofi-wayland            # App launcher (use wayland fork)
  wofi                    # Backup launcher (used for clipboard)
  mako                    # Notification daemon

  # Terminal
  kitty                   # Terminal emulator
  fish                    # Fish shell
  zoxide                  # Smart cd (used in fish config)

  # Clipboard
  wl-clipboard            # Clipboard for Wayland
  cliphist                # Clipboard history

  # Screenshot / recording
  grim                    # Screenshot
  slurp                   # Region selection
  wf-recorder             # Screen recording

  # System utilities
  networkmanagerapplet    # nm-applet tray icon
  brightnessctl           # Brightness control (may not need on desktop)
  playerctl               # Media key control
  pavucontrol             # Audio control GUI (or pavucontrol-qt)
  blueman                 # Bluetooth manager GUI

  # File manager
  dolphin                 # KDE file manager (or substitute)

  # Dev tools (from your configs)
  neovim
  helix
  lazygit
  git
  stow                    # For dotfile management

  # Theme / icons
  papirus-icon-theme      # Used by rofi and mako

  # Polkit agent
  polkit_gnome

  # AGS (Aylur's GTK Shell) - for dashboard widgets
  ags
];
```

## 3. Clone dotfiles and stow

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles

# Stow all configs
stow hypr waybar mako kitty rofi fish nvim helix lazygit git ags

# Or stow everything at once
stow */
```

## 4. NVIDIA environment variables

These are critical for Hyprland on NVIDIA. Add them to your `hyprland.conf` (already included in the repo, but verify/add if missing):

```
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = NIXOS_OZONE_WL,1
```

**Important:** The repo's `hyprland.conf` was written for the Manjaro laptop. You will need to add the NVIDIA env vars above since the laptop used Intel graphics. Add them to the `ENVIRONMENT VARIABLES` section of `hyprland.conf`.

## 5. Things to adjust for desktop

The config was originally for a laptop. Here's what to review:

### Monitor config
The default `monitor=,preferred,auto,1` should auto-detect, but for a specific resolution/refresh rate:
```
monitor=DP-1,3840x2160@144,0x0,1
```
Run `hyprctl monitors` after first boot to see available outputs.

### Remove laptop-specific stuff
These can be removed or will just be harmless no-ops on a desktop:

- **Battery monitor** (`exec-once` for battery-monitor.sh) - no battery on desktop
- **Waybar battery module** - remove `"battery"` from `modules-right` in waybar config
- **Brightness keys** (`XF86MonBrightnessUp/Down`) - no laptop backlight
- **Keyboard backlight module** (`custom/kbd_backlight`) - if no kbd backlight
- **Touchpad settings** in the input section
- **TLP module** (`custom/tlp`) - laptop power management tool
- **Vocalinux** references (exec-once and F12 bind) - unless you set this up on desktop too

### Waybar updates script
The updates script uses `pacman`/`yay`. On NixOS you don't have rolling updates the same way. You can either:
- Remove the `custom/updates` module from waybar
- Replace the script with one that checks `nix-channel --update` or your flake inputs

### Power menu
The hibernate action in waybar's power_menu.xml references `/home/dori/.local/bin/hibernate`. Update this path or use `systemctl hibernate` directly.

### Polkit agent path
The Manjaro config uses `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`. On NixOS this path differs. Replace the exec-once line with:
```
exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &
```
Or find the correct path with: `find /nix/store -name "polkit-gnome-authentication-agent-1" | head -1`

### Fish config
The fish config has Manjaro-specific PATH entries (`~/.amp/bin`, `~/.opencode/bin`). Clean these up for the new machine and re-add only what you install.

## 6. AGS Dashboard

After stowing, install AGS dependencies:

```bash
cd ~/.config/ags
npm install   # or use nix-shell with nodejs
ags run       # test it
```

AGS should auto-start via the `exec-once` in hyprland.conf.

## 7. First boot checklist

1. `sudo nixos-rebuild switch` after editing configuration.nix
2. Reboot and select Hyprland session from greetd
3. Clone and stow dotfiles
4. Add NVIDIA env vars to hyprland.conf
5. Run `hyprctl reload` or reboot
6. Verify waybar appears, rofi launches (Super+R), kitty opens (Super+Q)
7. Remove laptop-specific modules from waybar config
8. Set up your wallpaper: `swww img /path/to/wallpaper.png`
9. Create `~/.config/fish/secrets.fish` for any API keys / env vars

## 8. Troubleshooting

**Black screen on boot:** NVIDIA env vars missing or wrong driver. Boot to TTY (Ctrl+Alt+F2), check `journalctl -b` for errors.

**Cursor invisible:** Add `env = WLR_NO_HARDWARE_CURSORS,1` to hyprland.conf.

**Screen tearing:** Ensure `hardware.nvidia.modesetting.enable = true` is set.

**Waybar not showing:** Check if fonts are installed. Run `waybar` from a terminal to see errors.

**Apps look huge/tiny:** Adjust the scale factor in monitor config: `monitor=DP-1,3840x2160@144,0x0,1.5` (1.5x scale).
