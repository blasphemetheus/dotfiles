{ config, pkgs, lib, ... }:

let
  dotfiles = "/home/blewf/dotfiles";
in
{
  home.username = "blewf";
  home.homeDirectory = "/home/blewf";

  # Match your NixOS system.stateVersion
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── Phase 2: Simple configs (stable, rarely edited) ──────────────────
  # These use `source` (copied to Nix store, immutable).
  # Requires rebuild to update, but fully reproducible.

  xdg.configFile = {
    # Cava — audio visualizer
    "cava/config".source = ./cava/.config/cava/config;
    "cava/shaders" = {
      source = ./cava/.config/cava/shaders;
      recursive = true;
    };
    "cava/themes" = {
      source = ./cava/.config/cava/themes;
      recursive = true;
    };

    # Wob — volume/brightness overlay bar
    "wob/wob.ini".source = ./wob/.config/wob/wob.ini;

    # Helix — modal editor
    "helix/config.toml".source = ./helix/.config/helix/config.toml;

    # Lazygit — git TUI
    "lazygit/config.yml".source = ./lazygit/.config/lazygit/config.yml;

    # Wlogout — power menu
    "wlogout/layout".source = ./wlogout/.config/wlogout/layout;
    "wlogout/style.css".source = ./wlogout/.config/wlogout/style.css;

    # Rofi — app launcher
    "rofi/config.rasi".source = ./rofi/.config/rofi/config.rasi;
    "rofi/catppuccin.rasi".source = ./rofi/.config/rofi/catppuccin.rasi;

    # Mako — notification daemon
    "mako/config".source = ./mako/.config/mako/config;
  };
}
