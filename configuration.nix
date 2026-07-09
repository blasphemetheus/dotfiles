# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # limit stored generations (optional, 2 GB)
  boot.loader.systemd-boot.configurationLimit = 10;

  # Resume device for hibernate
  boot.resumeDevice = "/dev/nvme0n1p6";

  # Fix MT7925 WiFi PCIe link training (card not enumerating without this)
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  networking.networkmanager.dns = "none";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  
  networking.hostName = "nixos_slanka"; # Define your hostname.
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

  # IMPORTANT - NVIDIA RTX 5090 Drivers
  services.xserver.videoDrivers = [ "nvidia" ];

   hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    open = true;  # open kernel modules (required for RTX 5090 / Blackwell)
    powerManagement.enable = true;  # clean GPU state on suspend/session switch
  };
  hardware.graphics.enable = true;

  # Workaround for DIFR soft lockup (nvDIFRPrefetchSurfaces stuck kthread)
  # observed 2026-04-27 on Blackwell + 595.45.04-beta open modules.
  # DIFR has no direct toggle; disabling RTD3 broadens the GPU's stay-awake
  # window. Effectiveness uncertain — being monitored via difr-monitor.sh.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Allow dynamically linked binaries (Bazel hermetic toolchains, etc.)
  programs.nix-ld.enable = true;

  # Bazel toolchain wrappers use #!/bin/bash shebangs
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Docker
  virtualisation.docker.enable = true;

  # Enable flakes and the new nix command
  nix.settings.experimental-features = ["nix-command" "flakes" ];

  # trust devenv's binary cache and allow blewf to manage caches
  nix.settings.trusted-users = [ "root" "blewf" ];

  # Display manager — greetd + tuigreet (GDM core-dumps with NVIDIA open modules)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --time-format '%I:%M %p  |  %A, %B %d' --remember --remember-session --user-menu --width 50 --greeting '✦ NixOS  ✦  Hyprland' --theme 'border=yellow;title=yellow;greet=magenta;time=white;prompt=yellow;input=white;action=magenta;button=yellow;container=black' --sessions ${pkgs.hyprland}/share/wayland-sessions";
      user = "greeter";
    };
  };

  # Keep GNOME as a fallback desktop environment
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.blewf = {
    isNormalUser = true;
    description = "Bradley Lewis Fargo";
    shell = pkgs.fish;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
    #  thunderbird
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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    firefox
    btop
    elixir
    erlang
    inotify-tools
    nodejs
    devenv
    cachix
    google-chrome
    chromium
    helix
    discord
    openssl
    mosh
        
    # Dotfile management
    stow

    # Hyprland ecosystem
    waybar
    ironbar        # Rust Wayland bar (alongside waybar)
    swww
    hyprlock
    hypridle
    hyprpicker
    xdg-desktop-portal-hyprland
    pyprland       # Scratchpads, magnify, and more

    # Launcher and notifications
    rofi
    wofi
    anyrun         # Rust Wayland-native launcher
    mako

    # Terminal
    kitty
    ghostty        # Zig GPU-accelerated terminal
    wezterm        # Rust GPU-accelerated terminal + multiplexer
    fish
    nushell        # Structured data shell
    zoxide

    # Clipboard
    wl-clipboard
    cliphist

    # Screenshot / recording
    grim
    slurp
    satty      # screenshot annotation tool
    wf-recorder

    # System utilities
    jq         # JSON processor (used by session save/restore)
    socat      # Socket relay (used by per-workspace wallpaper listener)
    bubblewrap # OS-level sandboxing (used by Claude Code)
    power-profiles-daemon  # CPU power profile switching
    libnotify  # notify-send
    networkmanagerapplet
    brightnessctl
    playerctl
    pavucontrol
    blueman
    wob            # Volume/brightness overlay bar
    hyprshade      # Blue light filter

    # File manager
    kdePackages.dolphin

    # Dev tools
    neovim
    helix
    lazygit
    vscode
    direnv
    gh             # GitHub CLI
    zed-editor     # Rust GPU-accelerated editor

    # Modern CLI tools (Rust/Go replacements)
    bat        # cat with syntax highlighting
    eza        # ls with icons and git status
    fd         # find replacement
    ripgrep    # grep replacement
    delta      # git diff viewer
    dust       # du replacement (disk usage)
    procs      # ps replacement
    sd         # sed replacement
    tokei      # code line counter (cloc replacement)
    just       # task runner (make replacement)
    tealdeer   # tldr pages (simplified man pages)
    xh         # HTTP client (curl/httpie replacement)
    bandwhich  # network bandwidth monitor
    hyperfine  # benchmarking tool
    ouch       # compression (tar/zip/7z auto-detect)
    doggo      # DNS lookup (dig replacement)
    duf        # disk usage overview (df replacement)
    broot      # tree explorer with fuzzy search
    navi       # interactive CLI cheatsheet
    choose     # cut/awk replacement
    serpl      # TUI search and replace across files
    felix-fm   # Rust TUI file manager
    fastfetch  # system info splash
    starship   # cross-shell prompt
    yazi       # TUI file manager with image preview
    zellij     # terminal multiplexer
    glow       # terminal markdown renderer

    # Audio visualizer
    cava

    # Power menu
    wlogout

    # GTK theme editor (make Firefox/Dolphin match the rice)
    nwg-look

    # Emoji picker for rofi
    rofimoji
    wtype      # Wayland keyboard input (for rofimoji typing)
    wl-kbptr   # Keyboard-driven mouse control
    walker     # Wayland app launcher
    hyprpanel  # All-in-one panel (alongside waybar)

    # Theme / icons / cursor
    papirus-icon-theme
    bibata-cursors

    # Polkit agent (needed for privilege escalation prompts)
    polkit_gnome

    # rwing — Super Smash Bros. Melee replay viewer (Patreon, closed-source binary).
    # Packaged from the prebuilt Linux binary; see pkgs/rwing.nix. The binary itself is
    # non-redistributable and NOT in git — add it once with:
    #   nix-store --add-fixed sha256 rwing-linux-a2.3
    (callPackage ./pkgs/rwing.nix { })
  ];

  # Cursor theme
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

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

  # Polkit authentication agent (for privilege escalation prompts in Hyprland)
  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # Auto-upgrade claude-code daily
  systemd.user.services.claude-code-upgrade = {
    description = "Upgrade claude-code-nix Nix profile";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix profile upgrade claude-code-nix";
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

  # Re-evaluate hyprshade schedule on resume from suspend/hibernate.
  # `exec-once = hyprshade auto` only fires at Hyprland startup, so a wake
  # that crosses 19:00 / 07:00 leaves the filter stuck in its pre-sleep state.
  systemd.services.hyprshade-resume = {
    description = "Re-apply hyprshade schedule after wake from suspend/hibernate";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "blewf";
      Environment = [ "XDG_RUNTIME_DIR=/run/user/1000" ];
      ExecStart = pkgs.writeShellScript "hyprshade-resume" ''
        sig=$(ls -t /run/user/1000/hypr/ 2>/dev/null | head -n1)
        [ -z "$sig" ] && exit 0
        export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        exec ${pkgs.hyprshade}/bin/hyprshade auto
      '';
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
