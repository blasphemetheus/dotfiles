# Home Manager config for calbert (Cole) on the laptop.
#
# Cole works from his own clone at ~/dotfiles (/home/calbert/dotfiles) and
# pushes to main like blewf does, so the shared configs (Hyprland, waybar,
# kitty, niri, ags) are linked live into that clone exactly as home.nix does
# for blewf: edits apply on reload, and `nrs` rebuilds from his checkout.
# The clone has to exist before the first switch, or those links dangle.
# None of blewf's personal stuff (email, LLM timers, git identity, API-key
# shell wrappers) is here.
{ config, ... }:

let
  dotfiles = "/home/calbert/dotfiles";
  live = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.username = "calbert";
  home.homeDirectory = "/home/calbert";
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

  home.sessionPath = [ "/home/calbert/.local/bin" ];

  # Identity (user.name/email) is his to set with `git config --global`.
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
