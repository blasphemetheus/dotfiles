# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, inputs, ... }:

let
  # Session list for the greeter: everything the display manager knows about
  # except hyprland-uwsm.desktop — the hyprland package ships that entry
  # unconditionally, and we always launch plain Hyprland.
  greeterSessions = pkgs.runCommand "greeter-sessions" { } ''
    mkdir -p $out/share/wayland-sessions
    for f in ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop; do
      case "$(basename "$f")" in
        hyprland-uwsm.desktop) ;;
        *) ln -s "$f" "$out/share/wayland-sessions/" ;;
      esac
    done
  '';

  # dwl autostart + dwlb bar; run as dwl's `-s` child so it inherits
  # WAYLAND_DISPLAY and drains the status stream (see dwl/startup.sh).
  dwlStartup = pkgs.writeShellScript "dwl-startup" (builtins.readFile ./dwl/startup.sh);

  # tuigreet launcher: ASCII banner + one random (real) quote per boot.
  # Quotes live in greeter/quotes.txt — add lines there, rebuild to apply.
  # greet-align stays left: tuigreet centers each greeting line separately,
  # which would shear the ASCII art; the banner file carries its own indent.
  greeterLaunch = pkgs.writeShellScript "tuigreet-launch" ''
    banner="$(${pkgs.coreutils}/bin/cat ${./greeter/banner.txt})"
    quote="$(${pkgs.gnugrep}/bin/grep -Ev '^[[:space:]]*(#|$)' ${./greeter/quotes.txt} \
      | ${pkgs.coreutils}/bin/shuf -n 1 \
      | ${pkgs.coreutils}/bin/fold -s -w 72)"
    exec ${pkgs.tuigreet}/bin/tuigreet \
      --time --time-format '%I:%M %p  |  %A, %B %d' \
      --remember --remember-session --user-menu \
      --width 80 --window-padding 1 --container-padding 2 --greet-align left \
      --power-shutdown 'systemctl poweroff' \
      --power-reboot 'systemctl reboot' \
      --theme 'border=yellow;title=yellow;greet=magenta;time=white;prompt=yellow;input=white;action=magenta;button=yellow;container=black' \
      --greeting "$banner

$quote" \
      --sessions ${greeterSessions}/share/wayland-sessions
  '';
in
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

  # Keep kernel/udev chatter off tty1 so it doesn't paint over tuigreet.
  # Errors (level <=3) still print; everything is always in the journal.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # Extra data partition, created in the free gap after /boot. Holds large,
  # relocatable data (PHMUB, build caches, local model weights) so it doesn't
  # fill / (which shares one ext4 partition with /nix).
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/f9889b12-35a4-4872-961b-a5466ebb6b64";
    fsType = "ext4";
  };

  # pcie_aspm=off removed 2026-07-12: it was added while chasing WiFi
  # enumeration failures blamed on an MT7925, but the card is a Qualcomm
  # WCN7850 (ath12k) and the real fix was BIOS "Onboard Wi-Fi/BT Module
  # Control -> Auto". If WiFi vanishes after a reboot, boot the previous
  # generation from systemd-boot and re-add "pcie_aspm=off" here.

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

  # Enable Hyprland — compositor and matching portal from the upstream flake
  # (see flake.nix), not nixpkgs. nixpkgs lags the compositor and dropped
  # hyprexpo; pulling from the flake keeps compositor + plugins on one ABI.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  programs.direnv.enable = true;
  
  # Hyprland plugins. Stable /etc paths so the stow-managed hyprland.conf can
  # `plugin =` them without hardcoding nix store paths. All three are built
  # against the flake Hyprland (flake.nix inputs) so their ABI matches 0.55.4.
  #   hyprsplit — dwm-style per-monitor workspace sets (Super+N = Nth workspace
  #               of the FOCUSED monitor; second monitor's set is ids 11-20).
  #   Hyprspace — KDE/GNOME-style workspace overview with window drag.
  #   hyprexpo  — expo grid overview (community fork; see pkgs/hyprexpo.nix).
  environment.etc."hypr/plugins/libhyprsplit.so".source =
    "${inputs.hyprsplit.packages.${pkgs.stdenv.hostPlatform.system}.hyprsplit}/lib/libhyprsplit.so";
  # Hyprspace DISABLED 2026-08-11: upstream (last commit 2026-05-28) doesn't
  # compile against Hyprland 0.56 (AnimationManager.hpp moved). Re-enable this
  # line + the hyprland.conf plugin/bind lines when KZDKM/Hyprspace catches up.
  # environment.etc."hypr/plugins/libHyprspace.so".source =
  #   "${inputs.hyprspace.packages.${pkgs.stdenv.hostPlatform.system}.Hyprspace}/lib/libHyprspace.so";
  # hyprexpo from the fork's flake since v0.56.1+3 (built against our pinned
  # Hyprland via `follows`); pkgs/hyprexpo.nix was the 0.55-era hand-build.
  environment.etc."hypr/plugins/libhyprexpo.so".source =
    "${inputs.hyprexpo.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo}/lib/libhyprexpo.so";

  # ── Alternative compositors, selectable at the greetd session picker ──
  # Purely additive: Hyprland stays the default. Log out and pick one to try it.
  #   niri  — scrollable tiling (infinite horizontal strip), Rust
  #   river — dynamic tiling, Zig, i3-ish tags
  #   dwl   — suckless dwm for Wayland (minimal; no session file upstream)
  programs.niri.enable = true;
  programs.river-classic.enable = true;

  # dwl ships no wayland-session entry, so provide one. providedSessions is
  # required by the sessionPackages assertion.
  services.displayManager.sessionPackages = [
    (pkgs.writeTextFile {
      name = "dwl-session";
      destination = "/share/wayland-sessions/dwl.desktop";
      text = ''
        [Desktop Entry]
        Name=dwl
        Comment=dwm for Wayland
        Exec=dwl -s ${dwlStartup}
        Type=Application
      '';
      passthru.providedSessions = [ "dwl" ];
    })
  ];

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

  # GPU-aware suspend guard: while ANY process holds CUDA compute, hold a
  # sleep:idle inhibitor. Catches everything the script-level inhibitors
  # don't know about (Livebook runtimes, python experiments, ad-hoc runs).
  systemd.services.gpu-suspend-inhibitor = {
    description = "Inhibit idle-suspend while GPU compute is active";
    wantedBy = [ "multi-user.target" ];
    path = [ config.hardware.nvidia.package pkgs.systemd pkgs.gnugrep ];
    script = ''
      while true; do
        if nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -q .; then
          # Hold the lock for 60s at a time while compute apps exist
          systemd-inhibit --what=sleep:idle --who=gpu-watch \
            --why="GPU compute active" sleep 60
        else
          sleep 60
        fi
      done
    '';
    serviceConfig.Restart = "always";
  };

  # Bazel toolchain wrappers use #!/bin/bash shebangs
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Docker
  virtualisation.docker.enable = true;

  # Enable flakes and the new nix command
  nix.settings.experimental-features = ["nix-command" "flakes" ];

  # hyprwm's binary cache, so the flake Hyprland (+ hypr* deps) is substituted
  # instead of built from source. Merged with the default cache.nixos.org.
  nix.settings.substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];

  # trust devenv's binary cache and allow blewf to manage caches
  nix.settings.trusted-users = [ "root" "blewf" ];

  # `nixos-rebuild build-vm` boots this config in QEMU. These settings apply
  # ONLY to that VM variant — the defaults (1 core / 1 GB) are unusably slow.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 8;
    diskSize = 16384;
  };

  # ── Store hygiene ────────────────────────────────────────────────────
  # / and /nix share one ext4 partition, so an ungroomed store eats $HOME.
  # GC weekly; keep 30d of generations so rollback still works.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # devenv memoizes evaluation results — including absolute /nix/store paths —
  # in <project>/.devenv/nix-eval-cache.db, but only GC-roots the newest shell
  # (.devenv/gc/shell, overwritten each rebuild). The sweep above deletes the
  # older paths the cache still references, after which devenv either dies with
  # "path '/nix/store/...-devenv-shell.drv' does not exist and cannot be
  # created" or silently serves a stale evaluation. Drop the caches so the next
  # devenv command re-evaluates; they are pure cache and cost ~1s to rebuild.
  systemd.services.nix-gc.postStop = ''
    ${pkgs.findutils}/bin/find /home/blewf -maxdepth 5 \
      \( -name node_modules -o -name .git -o -name .direnv -o -name result \) -prune -o \
      -type d -name .devenv -exec ${pkgs.coreutils}/bin/rm -f \
        {}/nix-eval-cache.db {}/nix-eval-cache.db-shm {}/nix-eval-cache.db-wal \;
  '';

  # Hardlink identical files in the store. auto-optimise-store dedups on every
  # build; the weekly timer sweeps what already accumulated.
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;

  # nh — nicer rebuild UX (`nh os switch`, shows a diff of what changed).
  # Its own `clean` is left off; nix.gc above already handles collection.
  programs.nh = {
    enable = true;
    flake = "/home/blewf/dotfiles";
  };

  # Display manager — greetd + tuigreet (GDM core-dumps with NVIDIA open modules)
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${greeterLaunch}";
      user = "greeter";
    };
  };

  # Heal a wedged HDMI handshake at BOOT, before the greeter appears.
  # Symptom (seen 2026-07-12): the ASUS VG27V reports "no signal" from
  # power-on even though the GPU is driving it; a connector off→reprobe cycle
  # forces a fresh link train. Boot-time only: the post-S3-resume wedge is a
  # different failure (165Hz link training fails cold; connector cycling
  # doesn't help) and is handled in-session by scripts/hdmi-wake.sh
  # (60→165Hz bounce) via hypridle after_sleep_cmd and Super+Shift+H.
  # Do NOT hook this unit to post-resume.target: without After= ordering it
  # starts at suspend ENTRY, cycling the connector as the box goes down.
  systemd.services.hdmi-link-retrain = {
    description = "Cycle HDMI connector to retrain a wedged link";
    wantedBy = [ "graphical.target" ];
    before = [ "greetd.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for i in $(seq 1 50); do
        set -- /sys/class/drm/card*-HDMI-A-1/status
        [ -e "$1" ] && break
        sleep 0.2
      done
      for st in /sys/class/drm/card*-HDMI-A-1/status; do
        [ -e "$st" ] || continue
        if [ "$(cat "$st")" = "connected" ]; then
          echo off > "$st"
          sleep 1
          echo detect > "$st"
        fi
      done
    '';
  };

  # Allow blewf to fire the boot-style connector retrain on demand without
  # sudo (manual escalation: systemctl restart hdmi-link-retrain).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "hdmi-link-retrain.service" &&
          subject.user == "blewf") {
        return polkit.Result.YES;
      }
    });
  '';

  # Keep GNOME as a fallback desktop environment
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Give hyprlock its own PAM stack. Without /etc/pam.d/hyprlock it falls
  # back to the `su` stack, which includes pam_faillock: three typos at the
  # lockscreen would lock the ACCOUNT for 10 minutes on top of the screen —
  # journal showed `pam_unix(su:auth)` entries from exactly this fallback.
  security.pam.services.hyprlock = { };

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

  # Case/motherboard RGB via OpenRGB (MSI Mystic Light USB controller 0db0:0076
  # on the MAG X870E Tomahawk). Installs udev rules and runs the SDK server so
  # the `openrgb` CLI autoconnects instead of re-detecting hardware every call.
  # `motherboard = "amd"` loads i2c-piix4/i2c-dev for RAM/GPU RGB detection.
  # Toggle keybind: Super+Shift+L (led-toggle.sh).
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
    # 1.0rc2 (nixpkgs) rejects this board ("No matching driver found for
    # MS-7E59"); support landed in master's MSIMysticLight761 driver
    # (gitlab issue #4910). Pin master until the next release ships it.
    # The systemd-service patch is upstream in master, so drop it.
    package = pkgs.openrgb.overrideAttrs (old: {
      version = "1.0rc2-unstable-2026-07-21";
      src = pkgs.fetchFromGitLab {
        owner = "CalcProgrammer1";
        repo = "OpenRGB";
        rev = "bd41ba3b5cb619485899b40c8ff073dcad3aa4ed";
        hash = "sha256-jITHNPieOPuhRqMghnW8NoOoL6GJmwzUWQRCW7KWzNM=";
      };
      patches = builtins.filter
        (p: !(lib.hasInfix "systemd-service" (baseNameOf p))) old.patches;
    });
  };

  # Nintendo / Mayflash GameCube controller adapter (WUP-028, 057e:0337, Wii-U
  # mode) for Slippi Dolphin. The device node otherwise comes up root-only and
  # needs a manual chown after every replug/reboot; this grants access
  # declaratively. uaccess ACLs it to the logged-in seat; MODE=0666 is the belt.
  #
  # OpenRGB SDK server holds the RGB controller's device fd for its whole
  # lifetime; when the MSI Mystic Light USB controller (0db0:0076) re-enumerates
  # (suspend/resume, USB power glitch) that fd goes stale — LEDs stop responding
  # while `openrgb -c` still exits 0. Restart the server whenever the controller
  # re-appears so it re-grabs the live handle. --no-block keeps the udev worker
  # from blocking on the restart. (See memory: openrgb-stale-handle.)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666", TAG+="uaccess"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0db0", ATTR{idProduct}=="0076", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart openrgb.service"
  '';

  # Overclock the GC adapter's USB polling from 125Hz to 1000Hz (standard
  # Slippi input-lag fix, ~4-8ms average latency reduction). If inputs ever
  # drop, load with rate=2 (500Hz) via boot.extraModprobeConfig.
  boot.extraModulePackages = [ config.boot.kernelPackages.gcadapter-oc-kmod ];
  boot.kernelModules = [ "gcadapter_oc" ];

  # Dictation daemon (systemd user service): F12 toggle / Super+F12 push-to-talk
  # in Hyprland. Whisper runs on the 5090 via Vulkan — the Vulkan build is on
  # the Hydra binary cache, unlike the unfree CUDA build, and is ~as fast here.
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
    extraGroups = [ "networkmanager" "wheel" "docker" "input" ]; # input: hyprwhspr-rs evdev listener
    packages = with pkgs; [
      thunderbird
    ];
  };
  programs.fish.enable = true;

  # Steam for Rivals of Aether 1/2 (octopus workshop character project,
  # 2026-08-08). The module wires up 32-bit graphics, FHS wrapper, udev.
  programs.steam.enable = true;

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
    aseprite  # pixel art/animation for RoA workshop character
        
    # (stow removed — Home Manager owns all dotfiles as of the Phase 6 migration.
    #  If you ever need it: nix shell nixpkgs#stow)

    # dwl: suckless — config is compiled in. dwl/config.h = v0.7 config.def.h
    # with Super as MODKEY, kitty/rofi, hyprland border colors + a few
    # muscle-memory binds. Session entry defined above.
    (dwl.override { configH = ./dwl/config.h; })
    dwlb       # status bar for dwl (fed by `dwl -s`, see dwl/startup.sh)

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
    # Video playback (for reviewing screen recordings from wf-recorder)
    mpv        # lightweight keyboard-driven player: `mpv file.mp4`
    celluloid  # GTK GUI front-end over mpv
    vlc        # heavyweight, plays everything
    timg       # in-terminal video/gif playback via kitty graphics: `timg file.mp4`

    # AGS v3 (aylur/ags flake, overlaid as ags-v3) — dashboard + dictation
    # pill. nixpkgs' `ags` (v2.3, astal-API) stays untouched because hyprpanel
    # builds against it. The `ags` on PATH is v3.
    ags-v3

    # Dictation (see services.hyprwhspr-rs): whisper-cli for testing,
    # whisper-cpp-download-ggml-model for fetching models
    whisper-cpp-vulkan
    # the module only creates the user service; install the binary too for
    # `hyprwhspr-rs --test` (interactive dictation debugging in a terminal)
    config.services.hyprwhspr-rs.package

    # Disk / dedup (added after finding / at 93% full)
    ncdu       # interactive disk usage browser
    dua        # faster parallel `du` with a TUI (dua i)
    fclones    # find + hardlink/remove duplicate files

    # Nix tooling
    comma      # `, cowsay hi` — run any program without installing it (needs nix-index db)
    statix     # lint Nix for antipatterns
    deadnix    # find unused Nix bindings
    nixfmt     # official Nix formatter (was nixfmt-rfc-style)

    # More CLI
    yq          # jq for YAML/XML/TOML
    bandwhich   # per-process network bandwidth TUI
    hexyl       # hex viewer
    difftastic  # structural (AST-aware) diff — `difft a.ex b.ex`

    # System utilities
    usbutils   # lsusb (debugging USB devices, e.g. the GC adapter)
    jq         # JSON processor (used by session save/restore)
    socat      # Socket relay (used by per-workspace wallpaper listener)
    bubblewrap # OS-level sandboxing (used by Claude Code)
    power-profiles-daemon  # CPU power profile switching
    libnotify  # notify-send
    networkmanagerapplet
    brightnessctl
    playerctl
    pavucontrol
    audacity   # Audio recording/editing (interviews)
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
    opencode       # provider-agnostic terminal coding agent (Kimi K3 via "Kimi For Coding")

    # Game dev — PHMUB (the biota-browser branch). nixpkgs is on 4.6.1 while
    # game/project.godot declares config/features="4.7"; it runs and renders fine,
    # the editor just notes the mismatch. Bump when nixpkgs catches up to 4.7.
    godot_4

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

    # Video editing
    davinci-resolve  # free version: no H.264/H.265/AAC *import* on Linux — use to-dnxhr first
    (writeShellApplication {
      name = "to-dnxhr";
      runtimeInputs = [ ffmpeg ];
      text = ''
        # Convert H.264/H.265+AAC footage to DNxHR HQ + PCM audio, which free
        # DaVinci Resolve on Linux can import. Output lands next to the input
        # as <name>.dnxhr.mov. Usage: to-dnxhr file1.mp4 [file2.mkv ...]
        for f in "$@"; do
          out="''${f%.*}.dnxhr.mov"
          ffmpeg -i "$f" -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p \
                 -c:a pcm_s16le "$out"
          echo "→ $out"
        done
      '';
    })

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

    # utils
    unzip
    xdelta

    # elixir livebook
    pkgs.livebook
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
  # that crosses 19:00 / 06:00 leaves the filter stuck in its pre-sleep state.
  # (Window is 19:00-06:00 per hypr/.config/hypr/hyprshade.toml.)
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
      # Do NOT pick the instance by mtime (`ls -t`): Hyprland leaves the runtime
      # dir behind when an instance dies, and those stale dirs get touched later
      # than the live one, so `ls -t | head -1` reliably picks a DEAD instance.
      # `hyprctl instances` lists only compositors that are actually running.
      ExecStart = pkgs.writeShellScript "hyprshade-resume" ''
        sig=$(${pkgs.hyprland}/bin/hyprctl instances 2>/dev/null \
              | sed -n 's/^instance \(.*\):$/\1/p' | head -n1)
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
