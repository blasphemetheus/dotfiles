# Home Manager config for blewf's helper account on the laptop (Cole's
# machine; he is dotfiles.user and gets the full home.nix).
#
# Enough to fix things in person: the shared configs (Hyprland, waybar,
# kitty, niri, ags) are linked live into blewf's own clone at
# /home/blewf/dotfiles, the same way home.nix links them, and `nrs` rebuilds
# from that checkout. None of the personal stuff (email, LLM timers, API-key
# shell wrappers) is here; git identity stays in ~/.gitconfig.
{ config, ... }:

let
  dotfiles = "/home/blewf/dotfiles";
  live = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.username = "blewf";
  home.homeDirectory = "/home/blewf";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  xdg.configFile = {
    "hypr".source = live "hypr/.config/hypr";
    "waybar".source = live "waybar/.config/waybar";
    "kitty".source = live "kitty/.config/kitty";
    "niri".source = live "niri/.config/niri";
    "ags".source = live "ags/.config/ags";

    "rofi/config.rasi".source = ../../rofi/.config/rofi/config.rasi;
    "rofi/catppuccin.rasi".source = ../../rofi/.config/rofi/catppuccin.rasi;
    "mako/config".source = ../../mako/.config/mako/config;
    "wob/wob.ini".source = ../../wob/.config/wob/wob.ini;
    "wlogout/layout".source = ../../wlogout/.config/wlogout/layout;
    "wlogout/style.css".source = ../../wlogout/.config/wlogout/style.css;
  };

  home.sessionPath = [ "/home/blewf/.local/bin" ];

  programs.git.enable = true;

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../starship/.config/starship.toml);
  };
  programs.zoxide.enable = true;
  programs.fzf.enable = true;
  programs.fish = {
    enable = true;
    shellAliases.nrs = "sudo nixos-rebuild switch --flake ~/dotfiles";
  };
}
