# aspire — the laptop (Acer Aspire Go 15 AG15-21PT: Ryzen 5 7520U, Radeon 610M
# iGPU, 16 GB). Shared system config lives in ../../configuration.nix; this
# file only adds what a battery-powered, integrated-graphics machine needs.
# No NVIDIA, no local LLM (ollama), no OpenRGB, no monitor-link heal units —
# the scripts that drive those all no-op when the hardware is absent.
{ config, pkgs, ... }:

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
    ../../profiles/laptop.nix
  ];

  networking.hostName = "aspire";

  # Whose machine this is (modules/system/user.nix). To hand the laptop to
  # someone else: change name/description here, leave fullName/email/mailbox
  # unset (git identity then comes from their ~/.gitconfig), keep
  # personalTools off, and reinstall or `nrs` + create the account's password.
  dotfiles.user = {
    name = "blewf";
    description = "Bradley Lewis Fargo";
    fullName = "Bradley Lewis Fargo";
    email = "blewfargs@gmail.com";
  };

  boot.extraModulePackages = [ acp6xMachAspire ];

  # amdgpu loads on its own and hardware.graphics (shared) brings Mesa/RADV,
  # so there is no GPU driver block here.

  # Resume uses this machine's disk swap, never its zram device.
  boot.resumeDevice = if config.swapDevices == [ ] then ""
    else (builtins.head config.swapDevices).device;

  # This APU cannot reliably roll back a hibernation freeze when a wake event
  # arrives. Power off after writing the image instead of using platform mode.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";
}
