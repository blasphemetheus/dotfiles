{ lib, ... }:
{
  dotfiles.profile = "desktop";
  dotfiles.power = {
    lockSeconds = lib.mkDefault 1500;
    screenOffSeconds = lib.mkDefault 900;
    sleepSeconds = lib.mkDefault 2400;
    hibernate = lib.mkDefault false;
  };
}
