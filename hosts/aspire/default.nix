# aspire — the laptop (Acer Aspire Go 15 AG15-21PT: Ryzen 5 7520U, Radeon 610M
# iGPU, 16 GB). Shared system config lives in ../../configuration.nix; this
# file only adds what a battery-powered, integrated-graphics machine needs.
# No NVIDIA, no local LLM (ollama), no OpenRGB, no monitor-link heal units —
# the scripts that drive those all no-op when the hardware is absent.
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
  ];

  networking.hostName = "aspire";

  # amdgpu loads on its own and hardware.graphics (shared) brings Mesa/RADV,
  # so there is no GPU driver block here.

  # 16 GB with a browser + Hyprland + dev tools: compressed RAM swap is far
  # cheaper than hitting the SSD, and earlyoom (shared) stays as the backstop.
  zramSwap.enable = true;

  # Firmware updates (BIOS/EC/SSD) via `fwupdmgr update`.
  services.fwupd.enable = true;

  # hypridle's before_sleep_cmd locks before any suspend. power-profiles-daemon
  # (shared) covers battery/performance switching.

  # This machine only has s2idle (no S3 "deep"), which keeps draining the
  # battery while asleep. With a disk swap partition present, closing the lid
  # suspends and then hibernates after 2 h asleep; without one (swapDevices
  # empty) all of this stays off and the lid just suspends.
  boot.resumeDevice = lib.mkIf (config.swapDevices != [ ])
    (builtins.head config.swapDevices).device;
  services.logind.settings.Login = lib.mkIf (config.swapDevices != [ ]) {
    HandleLidSwitch = "suspend-then-hibernate";
  };
  systemd.sleep.settings.Sleep = lib.mkIf (config.swapDevices != [ ]) {
    HibernateDelaySec = "2h";
  };
}
