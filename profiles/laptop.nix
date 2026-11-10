{ lib, ... }:
{
  dotfiles.profile = "laptop";
  dotfiles.power = {
    lockSeconds = lib.mkDefault 300;
    screenOffSeconds = lib.mkDefault 600;
    sleepSeconds = lib.mkDefault 1200;
    hibernate = lib.mkDefault true;
    hibernateDelay = lib.mkDefault "2h";
  };
  zramSwap.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;
}
