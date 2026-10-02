# Home Manager config for calbert (Cole) on the laptop.
#
# Same look as blewf's desktop — Hyprland default, niri and GNOME at the
# greeter — but none of blewf's personal stuff (email, LLM timers, git
# identity, API-key shell wrappers). The compositor/bar/terminal configs are
# store copies of the repo dirs rather than home.nix's out-of-store symlinks:
# those point into /home/blewf, which calbert can't read. Repo edits reach
# this account on the next `nrs`; toggles that write into ~/.config/hypr at
# runtime (opacity etc.) don't stick here, since the copy is read-only.
{ ... }:

{
  home.username = "calbert";
  home.homeDirectory = "/home/calbert";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  xdg.configFile = {
    "hypr".source = ../../hypr/.config/hypr;
    "waybar".source = ../../waybar/.config/waybar;
    "kitty".source = ../../kitty/.config/kitty;
    "niri".source = ../../niri/.config/niri;
    "ags".source = ../../ags/.config/ags;

    "rofi/config.rasi".source = ../../rofi/.config/rofi/config.rasi;
    "rofi/catppuccin.rasi".source = ../../rofi/.config/rofi/catppuccin.rasi;
    "mako/config".source = ../../mako/.config/mako/config;
    "wob/wob.ini".source = ../../wob/.config/wob/wob.ini;
    "wlogout/layout".source = ../../wlogout/.config/wlogout/layout;
    "wlogout/style.css".source = ../../wlogout/.config/wlogout/style.css;
  };

  home.sessionPath = [ "/home/calbert/.local/bin" ];

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../starship/.config/starship.toml);
  };
  programs.zoxide.enable = true;
  programs.fzf.enable = true;
  programs.fish.enable = true;
}
