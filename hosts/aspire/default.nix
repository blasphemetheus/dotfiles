# aspire — the laptop (Acer Aspire Go 15 AG15-21PT: Ryzen 5 7520U, Radeon 610M
# iGPU, 16 GB). Shared system config lives in ../../configuration.nix; this
# file only adds what a battery-powered, integrated-graphics machine needs.
# No NVIDIA, no local LLM (ollama), no OpenRGB, no monitor-link heal units —
# the scripts that drive those all no-op when the hardware is absent.
{ config, pkgs, lib, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  # The internal mic is a digital mic on the AMD audio coprocessor, not on
  # the Realtek codec. Its machine driver (snd-soc-acp6x-mach) only binds on
  # boards in its DMI quirk table, and this one (board "Herbag2_MDU") isn't
  # there — upstream only has "Herbag_MDU". Rebuild just that module with
  # the board added; depmod prefers updates/ over the stock copy. Drop this
  # once upstream lists the board.
  acp6xMachAspire = pkgs.stdenv.mkDerivation {
    pname = "snd-soc-acp6x-mach-aspire";
    inherit (kernel) version src;
    nativeBuildInputs = kernel.moduleBuildDependencies;

    unpackPhase = ''
      tar -xf $src --wildcards --strip-components=5 \
        '*/sound/soc/amd/yc/*'
      echo 'obj-m := snd-soc-acp6x-mach.o' > Kbuild  # replaces the dir's own Makefile
      echo 'snd-soc-acp6x-mach-y := acp6x-mach.o' >> Kbuild
    '';

    postPatch = ''
      substituteInPlace acp6x-mach.c --replace-fail \
        'yc_acp_quirk_table[] = {' \
        'yc_acp_quirk_table[] = {
      {
        .driver_data = &acp6x_card,
        .matches = {
          DMI_MATCH(DMI_BOARD_VENDOR, "MDC"),
          DMI_MATCH(DMI_BOARD_NAME, "Herbag2_MDU"),
        }
      },'
    '';

    buildPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD modules
    '';

    installPhase = ''
      install -Dm444 snd-soc-acp6x-mach.ko \
        $out/lib/modules/${kernel.modDirVersion}/updates/snd-soc-acp6x-mach.ko
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
  ];

  networking.hostName = "aspire";

  boot.extraModulePackages = [ acp6xMachAspire ];

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
    # The default "platform" mode checks for wakeup events after the image is
    # written and, if a key/touchpad/power-button press arrived, rolls back to
    # the running session instead of powering off. amdgpu can't survive that
    # rollback on this APU (it MODE2-resets the GPU on freeze; the restore
    # leaves sdma0 hung, Hyprland dies, no compositor starts until reboot).
    # Same code in upstream master. "shutdown" powers off once the image is
    # written — no rollback path; resume from the power button is unchanged.
    HibernateMode = "shutdown";
  };
}
