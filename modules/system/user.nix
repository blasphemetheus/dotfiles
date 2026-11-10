# The one human account on each machine. Hosts set `dotfiles.user`; every
# module that needs the login name, home path, or identity reads it from here
# (home.nix via `osConfig`), so handing a host to someone else means changing
# one block in hosts/<name>/default.nix, not grepping for a username.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles.user;
  mailbox = lib.types.submodule {
    options = {
      address = lib.mkOption { type = lib.types.str; };
      realName = lib.mkOption { type = lib.types.str; };
      imapHost = lib.mkOption { type = lib.types.str; };
      smtpHost = lib.mkOption { type = lib.types.str; };
      label = lib.mkOption {
        type = lib.types.str;
        description = "Keyring label shown by `secret-tool store`.";
      };
    };
  };
in
{
  options.dotfiles.user = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Login name. Also the Home Manager user and the greetd autologin user.";
    };
    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Fixed uid, so system units can find /run/user/<uid>.";
    };
    description = lib.mkOption {
      type = lib.types.str;
      description = "Account description (GECOS full name).";
    };
    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.name}";
      description = "Home directory. This repo must be checked out at <home>/dotfiles.";
    };
    fullName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git/jj commit identity name. null leaves the identity to ~/.gitconfig.";
    };
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git/jj commit identity email. null leaves the identity to ~/.gitconfig.";
    };
    mailbox = lib.mkOption {
      type = lib.types.nullOr mailbox;
      default = null;
      description = "IMAP/SMTP account for aerc. null disables aerc configuration.";
    };
    personalTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Shell helpers tied to one person's accounts and hardware: the
        third-party Claude Code wrappers (API keys from secrets.fish),
        Slippi/Steam GameCube aliases.
      '';
    };
  };

  config = {
    users.users.${cfg.name} = {
      isNormalUser = true;
      inherit (cfg) uid description;
      home = cfg.home;
      shell = pkgs.fish;
      extraGroups = [ "networkmanager" "wheel" "input" "libvirtd" ]; # input: hyprwhspr-rs evdev listener; libvirtd: VMs without sudo
      packages = with pkgs; [
        thunderbird
      ];
    };
  };
}
