# Shared NixOS system config — imported by every host in hosts/*/default.nix.
# Anything tied to one machine's hardware (GPU driver, disks, monitor quirks,
# RGB, host name) belongs in that host's file, not here.

{ pkgs, ... }:

{
  imports = [
    ./modules/system/power.nix
    ./modules/system/nix-maintenance.nix
    ./modules/system/packages.nix
    ./modules/system/compositors.nix
    ./modules/system/login.nix
    ./modules/system/logging.nix
    ./modules/system/virtualisation.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # limit stored generations (optional, 2 GB)
  boot.loader.systemd-boot.configurationLimit = 10;

  # Keep kernel/udev chatter off tty1 so it doesn't paint over tuigreet.
  # Errors (level <=3) still print; everything is always in the journal.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # nixpkgs default kernel (6.18.x as of the 2026-10 lock). Was pinned to 6.12
  # LTS until 2026-09-09; 6.12.77 prints "RDSEED32 is broken. Disabling the
  # corresponding CPUID bit." at boot on the 9950X3D because its Zen 5 fixup
  # table only knew two models and treated everything else as unfixed. 6.18
  # carries the full table (family 0x1a model 0x44 stepping 0 -> ucode
  # 0x0b404035, which linux-firmware already ships), so RDSEED stays enabled
  # and the line is gone. NVIDIA beta 595 + gcadapter-oc-kmod both build on it.
  boot.kernelPackages = pkgs.linuxPackages;

  # Nothing on the desktop path needs the network to be *online* at boot, and
  # this waited ~9s every boot, long enough for systemd to paint a "start job
  # is running" spinner on tty1.
  systemd.services.NetworkManager-wait-online.enable = false;

  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Allow dynamically linked binaries (Bazel hermetic toolchains, etc.)
  programs.nix-ld.enable = true;

  # Update-resilient game/AppImage support (2026-07-31): the Slippi
  # Launcher's downloaded Dolphin builds (and any future downloaded
  # binary) resolve their host libs through nix-ld instead of failing
  # after every update. This is the exact dependency chain discovered
  # empirically for the ExPhil netplay bot (asound -> EGL -> X11 ->
  # fontconfig -> harfbuzz -> drm -> gmp).
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib
    libglvnd
    libusb1
    udev
    pulseaudio
    libx11
    libxext
    libxrandr
    libxi
    libxcursor
    libxinerama
    libxxf86vm
    libxfixes
    libxrender
    libxcb
    libsm
    libice
    fontconfig
    freetype
    dbus
    zlib
    harfbuzz
    glib
    pango
    cairo
    gdk-pixbuf
    atk
    gtk3
    libpng
    expat
    libxkbcommon
    wayland
    libdrm
    mesa
    vulkan-loader
    gmp
    # Full-ldd sweep remainder (mainline beta Dolphin, 2026-07-31)
    libgpg-error
    fribidi
    e2fsprogs
  ];

  # AppImages from GUI-spawned processes (Slippi Launcher's Dolphin child,
  # 2026-07-31): skip FUSE mounting entirely — the slippi-nix launcher
  # wrapper pins FUSERMOUNT_PROG to an unprivileged nix-store fusermount
  # ("mount failed: Operation not permitted"), and its version probe fails
  # the same way (hence the eternal beta.19 redownload loop). Extraction
  # mode needs no fusermount, no setuid, and works from any spawn context.
  environment.sessionVariables.APPIMAGE_EXTRACT_AND_RUN = "1";

  # Kill the biggest memory hog BEFORE the box freezes (2026-07-31 hard
  # freeze: GPU-VRAM starvation -> memory-pressure spiral -> 30s of
  # journald cache-flushing -> hard reboot, no OOM kill ever fired).
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 4;   # % RAM
    freeSwapThreshold = 10; # % swap
  };

  # Bazel toolchain wrappers use #!/bin/bash shebangs
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  # (Docker removed 2026-09-17: virtualisation.docker was disabled and the
  # daemon never installed, yet blewf was in the docker group and the fish
  # `sandbox`/`sandbox-join` functions shelled out to it. Group + functions
  # dropped too. Resurrect from git history if container sandboxes return —
  # or use podman, which is a drop-in CLI match.)

  # `nixos-rebuild build-vm` boots this config in QEMU. These settings apply
  # ONLY to that VM variant — the defaults (1 core / 1 GB) are unusably slow.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 8;
    diskSize = 16384;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Power profiles (performance/balanced/power-saver)
  services.power-profiles-daemon.enable = true;

  # Dictation daemon (systemd user service): F12 toggle / Super+F12 push-to-talk
  # in Hyprland. Whisper runs on the GPU via Vulkan (vendor-neutral: the 5090
  # on the desktop, RADV on the laptop) — the Vulkan build is on
  # the Hydra binary cache, unlike the unfree CUDA build, and is ~as fast here.
  # Paste path fix (2026-10-17): the daemon pastes with the hyprlang-era
  # `dispatch sendshortcut ctrl shift, v, active`, which a Lua-configured
  # Hyprland evaluates as Lua and rejects — EVERY dictation then fell back to
  # a fresh virtual keyboard whose first Ctrl+Shift+V lost its modifiers and
  # typed a bare "v". The patch sends hl.dsp.send_shortcut({...}) first and
  # keeps the old form for hyprlang Hyprlands. It also drops the per-utterance
  # benchmark table to debug level (20 journal lines per dictation).
  nixpkgs.overlays = [
    (_final: prev: {
      hyprwhspr-rs = prev.hyprwhspr-rs.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./pkgs/hyprwhspr-rs-lua-dispatch.patch ];
      });
    })
  ];
  services.hyprwhspr-rs = {
    enable = true;
    package = pkgs.hyprwhspr-rs.override {
      # override arg is hyphenated `whisper-cpp` (upstream README says `whispercpp`)
      whisper-cpp = pkgs.whisper-cpp-vulkan;
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.blewf = {
    isNormalUser = true;
    description = "Bradley Lewis Fargo";
    shell = pkgs.fish;
    extraGroups = [ "networkmanager" "wheel" "input" "libvirtd" ]; # input: hyprwhspr-rs evdev listener; libvirtd: VMs without sudo
    packages = with pkgs; [
      thunderbird
    ];
  };
  programs.fish.enable = true;

  # Install firefox.
  programs.firefox.enable = true;

  # Fonts used by waybar, kitty, rofi, mako
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    font-awesome
    roboto
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Auto-upgrade the coding agents daily. Both live in the user nix profile
  # rather than systemPackages so they can move faster than the flake's
  # nixpkgs lock: claude-code from sadjow/claude-code-nix, codex installed
  # with `nix profile install github:NixOS/nixpkgs/nixos-unstable#codex`
  # (NB: not `nixpkgs#codex` — the system registry pins that alias to the
  # flake lock, so `nix profile upgrade` would never move it).
  systemd.user.services.claude-code-upgrade = {
    description = "Upgrade claude-code-nix and codex Nix profile entries";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix profile upgrade claude-code-nix codex";
    };
  };

  systemd.user.timers.claude-code-upgrade = {
    description = "Daily claude-code upgrade";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # run missed triggers after sleep/shutdown
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
