# App configuration sources: immutable store copies and live checkout links.
{ config, ... }:
let
  # Absolute path required by mkOutOfStoreSymlink.
  dotfiles = "/home/blewf/dotfiles";
in
{
  # ── Phase 2: Simple configs (stable, rarely edited) ──────────────────
  # These use `source` (copied to Nix store, immutable).
  # Requires rebuild to update, but fully reproducible.

  xdg.configFile = {
    # Cava — audio visualizer
    "cava/config".source = ../../cava/.config/cava/config;
    "cava/shaders" = {
      source = ../../cava/.config/cava/shaders;
      recursive = true;
    };
    "cava/themes" = {
      source = ../../cava/.config/cava/themes;
      recursive = true;
    };

    # Wob — volume/brightness overlay bar
    "wob/wob.ini".source = ../../wob/.config/wob/wob.ini;

    # Helix — modal editor
    "helix/config.toml".source = ../../helix/.config/helix/config.toml;

    # Lazygit — git TUI
    "lazygit/config.yml".source = ../../lazygit/.config/lazygit/config.yml;

    # Wlogout — power menu
    "wlogout/layout".source = ../../wlogout/.config/wlogout/layout;
    "wlogout/style.css".source = ../../wlogout/.config/wlogout/style.css;

    # Rofi — app launcher
    "rofi/config.rasi".source = ../../rofi/.config/rofi/config.rasi;
    "rofi/catppuccin.rasi".source = ../../rofi/.config/rofi/catppuccin.rasi;

    # Mako — notification daemon
    "mako/config".source = ../../mako/.config/mako/config;

    # aerc — keybindings (defaults + helix tweaks; aerc replaces its built-in
    # binds when this file exists, so it carries the full set)
    "aerc/binds.conf".source = ../../aerc/binds.conf;

    # ── Phase 3: Active configs (edited + reloaded live) ─────────────────
    # Whole-dir out-of-store symlinks: ~/.config/<x> points straight at the repo,
    # so edits apply on reload without a rebuild, and HM does NOT manage the
    # runtime-mutable inner files (the opacity toggle writes into hypr/, waybar
    # style variants, ags needs its gitignored node_modules).
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hypr/.config/hypr";
    "waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/waybar/.config/waybar";
    "kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/kitty/.config/kitty";
    # niri: alternative compositor session (config.kdl auto-reloads on save).
    "niri".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/niri/.config/niri";
    # hyprwhspr-rs: single-source the dictation config. The live copy used to be
    # a hand-synced real file that could drift from the repo; vocab-add.sh also
    # edits this file in place and needs the repo path to BE the live path.
    "hyprwhspr-rs".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hyprwhspr/.config/hyprwhspr-rs";

    # ── Phase 5: remaining app configs (symlinked, not programs.* modules) ──
    # nvim: lazy.nvim manages plugins under ~/.local/share, config stays live.
    # ags: whole-dir symlink so the gitignored node_modules/@girs stay reachable.
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim/.config/nvim";
    "ags".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ags/.config/ags";
  };

}
