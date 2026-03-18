{ config, pkgs, lib, ... }:

{
  home.username = "blewf";
  home.homeDirectory = "/home/blewf";

  # Match your NixOS system.stateVersion
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
