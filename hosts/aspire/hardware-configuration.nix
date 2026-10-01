# PLACEHOLDER — replace with the laptop's real scan before the first install:
#   sudo nixos-generate-config --show-hardware-config > hosts/aspire/hardware-configuration.nix
# Until then this only exists so the `aspire` config evaluates and can be
# pre-built on the desktop. It assumes partitions LABELLED `nixos` (ext4 root),
# `BOOT` (vfat ESP) and `swap` (>= 16 GB, for hibernate); the generated file
# will use UUIDs and the exact initrd module list instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
