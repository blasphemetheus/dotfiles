# Shared NixOS system config — imported by every host in hosts/*/default.nix.
# Anything tied to one machine's hardware (GPU driver, disks, monitor quirks,
# RGB, host name) belongs in that host's file, not here.

{ config, pkgs, lib, inputs, ... }:

let
  # Session list for the greeter: everything the display manager knows about
  # except hyprland-uwsm.desktop — the hyprland package ships that entry
  # unconditionally, and we always launch plain Hyprland.
  #
  # Default session = Hyprland. tuigreet sorts the menu by Name= with a plain
  # (case-sensitive) compare and picks index 0 when nothing is remembered, so
  # "GNOME" used to beat "Hyprland". The GNOME entries are copied with a
  # lowercase name so they sort last. The list is also exposed at the stable
  # path /etc/greeter-sessions (see environment.etc + --sessions below):
  # --remember-session stores the absolute .desktop path, and a /nix/store
  # path went stale on every rebuild, which is what kept resetting the default.
  greeterSessions = pkgs.runCommand "greeter-sessions" { } ''
    mkdir -p $out/share/wayland-sessions
    for f in ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/*.desktop; do
      case "$(basename "$f")" in
        hyprland-uwsm.desktop) ;;
        gnome*.desktop)
          sed -e 's/^Name=GNOME on Wayland$/Name=gnome on Wayland (fallback)/' \
              -e 's/^Name=GNOME$/Name=gnome (fallback)/' "$f" > "$out/share/wayland-sessions/$(basename "$f")" ;;
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
  # Banner/quotes are read from /etc/greeter (environment.etc below) so the
  # hyprlock lock screen shows the same files (scripts/greeter-{banner,quote}.sh).
  greeterLaunch = pkgs.writeShellScript "tuigreet-launch" ''
    banner="$(${pkgs.coreutils}/bin/cat /etc/greeter/banner.txt)"
    quote="$(${pkgs.gnugrep}/bin/grep -Ev '^[[:space:]]*(#|$)' /etc/greeter/quotes.txt \
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
      --sessions /etc/greeter-sessions
  '';
in
{
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

  # nixpkgs default kernel (6.18.x as of the 2026-03 lock). Was pinned to 6.12
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

  hardware.graphics.enable = true;

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

  # Hyprland plugins. Stable /etc paths so the Lua config can hl.plugin.load()
  # them without hardcoding nix store paths. Both are built against the flake
  # Hyprland (flake.nix inputs) so their ABI matches 0.56.2.
  #   hyprsplit — dwm-style per-monitor workspace sets (Super+N = Nth workspace
  #               of the FOCUSED monitor; second monitor's set is ids 11-20).
  #   hyprexpo  — expo grid overview (sandwichfarm fork flake input).
  # hyprsplit is a Lua LIBRARY since Hyprland 0.55 (the .so refuses Lua configs):
  # install the pinned input's init.lua where hypr/.config/hypr/hyprsplit/init.lua
  # symlinks to, and lua/plugins.lua require()s it.
  environment.etc."hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";
  environment.etc."hypr/plugins/libhyprsplit.so".source =
    "${inputs.hyprsplit.packages.${pkgs.stdenv.hostPlatform.system}.hyprsplit}/lib/libhyprsplit.so";
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
    settings = {
      # Boot → straight into Hyprland, which locks itself immediately
      # (hyprland.conf exec-once on HYPR_AUTOLOGIN_LOCK; hyprlock is the
      # login screen). No password is taken here, so the keyring is unlocked
      # by hyprlock's PAM stack instead — see security.pam.services.hyprlock.
      initial_session = {
        command = "${pkgs.writeShellScript "hyprland-autologin" ''
          export HYPR_AUTOLOGIN_LOCK=1
          exec ${config.programs.hyprland.package}/bin/start-hyprland
        ''}";
        user = "blewf";
      };
      # After logout (or if the session dies) greetd falls back to tuigreet.
      default_session = {
        command = "${greeterLaunch}";
        user = "greeter";
      };
    };
  };
  # Stable paths for tuigreet's session list and the shared banner/quotes
  # (see greeterSessions / greeterLaunch above; hyprlock reads the same files).
  environment.etc."greeter-sessions".source = "${greeterSessions}/share/wayland-sessions";
  environment.etc."greeter/banner.txt".source = ./greeter/banner.txt;
  environment.etc."greeter/quotes.txt".source = ./greeter/quotes.txt;

  # Keep GNOME as a fallback desktop environment
  services.desktopManager.gnome.enable = true;
  # GNOME drags in the LocalSearch/Tracker file indexer, which timed out on
  # D-Bus activation (120s) every Hyprland session. Not wanted here.
  services.gnome.localsearch.enable = false;
  services.gnome.tinysparql.enable = false;
  # avahi is up (via GNOME) but warned "No NSS support for mDNS"; wire nss-mdns
  # so .local names resolve and the warning goes away.
  services.avahi.nssmdns4 = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Give hyprlock its own PAM stack. Without /etc/pam.d/hyprlock it falls
  # back to the `su` stack, which includes pam_faillock: three typos at the
  # lockscreen would lock the ACCOUNT for 10 minutes on top of the screen —
  # journal showed `pam_unix(su:auth)` entries from exactly this fallback.
  # enableGnomeKeyring: with greetd autologin nobody types a password at
  # session start, so the first hyprlock unlock is what opens the keyring
  # (pam_gnome_keyring auth against the already-running daemon).
  security.pam.services.hyprlock = { enableGnomeKeyring = true; };

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
    extraGroups = [ "networkmanager" "wheel" "input" ]; # input: hyprwhspr-rs evdev listener
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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    # git/fish/zoxide/direnv/starship/zellij used to be here too — removed
    # 2026-09-17: Home Manager's programs.* modules (home.nix) install them for
    # blewf, and HM's shell hooks are the ones that actually run. fish stays on
    # the system PATH via programs.fish.enable (needed as the login shell);
    # for root-side git: `nix shell nixpkgs#git`.
    btop
    elixir
    erlang
    inotify-tools
    nodejs
    devenv
    cachix
    google-chrome
    chromium
    # Force native Wayland instead of XWayland. Discord ran as an XWayland
    # client by default, and on 2026-08-27 its renderer wedged on the splash
    # spinner after 6d18h of uptime across several S3 cycles — gateway still
    # connected and logs still flowing, but the window never repainted. Chrome
    # and Chromium both run native Wayland here and don't do this. Verified
    # xwayland:0 and a clean load under these flags before committing.
    # NB: the nixpkgs wrapper already appends --enable-speech-dispatcher, so
    # don't repeat it here or it lands on the command line twice.
    # Recovery if it wedges anyway: scripts/discord-recover.sh (Super+Shift+K).
    (discord.override {
      commandLineArgs = "--ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations";
    })
    openssl
    mosh
        
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
    pyprland       # Scratchpads, magnify, and more
    xwayland-satellite  # X11 apps under niri (niri spawns it; see niri/config.kdl)

    # Launcher and notifications
    rofi
    wofi
    anyrun         # Rust Wayland-native launcher
    mako

    # Terminal
    kitty
    ghostty        # Zig GPU-accelerated terminal
    wezterm        # Rust GPU-accelerated terminal + multiplexer
    nushell        # Structured data shell

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
    wsdd           # gvfs network browsing spawns this (was "Failed to spawn the wsdd daemon")
    brightnessctl
    playerctl
    pavucontrol
    audacity   # Audio recording/editing (interviews)
    blueman
    wob            # Volume/brightness overlay bar
    hyprshade      # Blue light filter
    qbittorrent
    # File manager
    kdePackages.dolphin

    # Dev tools
    neovim
    helix
    lazygit
    vscode
    gh             # GitHub CLI
    zed-editor     # Rust GPU-accelerated editor
    opencode       # provider-agnostic terminal coding agent (Kimi K3 via "Kimi For Coding")

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
    yazi       # TUI file manager with image preview
    glow       # terminal markdown renderer

    # Video editing
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
    (writeShellApplication {
      name = "maketiny";
      runtimeInputs = [ ffmpeg ];
      text = ''
        # Shrink a video to fit under a size limit (default 20 MB) with
        # two-pass H.264: caps at 60 fps, drops to 720p when the bitrate
        # budget is thin. Output lands next to the input as <name>.tiny.mp4.
        # Usage: maketiny file.mp4 [target_mb]
        f="$1"; target_mb="''${2:-20}"
        out="''${f%.*}.tiny.mp4"
        dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
        has_audio=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" | head -n1)
        # Aim ~4% under the limit to cover container overhead
        total_kbps=$(awk -v mb="$target_mb" -v d="$dur" 'BEGIN{printf "%d", mb*8*1024*0.96/d}')
        audio_kbps=0; audio_opts=(-an)
        if [ -n "$has_audio" ]; then audio_kbps=96; audio_opts=(-c:a aac -b:a 96k); fi
        video_kbps=$((total_kbps - audio_kbps))
        vf="fps=min(source_fps\,60)"
        if [ "$video_kbps" -lt 2500 ]; then vf="$vf,scale=-2:'min(720,ih)'"; fi
        echo "→ ''${dur%.*}s, ''${video_kbps} kbps video, ''${audio_kbps} kbps audio"
        log=$(mktemp -d)
        ffmpeg -y -hide_banner -loglevel error -stats -i "$f" -vf "$vf" \
          -c:v libx264 -preset slow -b:v "''${video_kbps}k" -pass 1 -passlogfile "$log/p" -an -f null /dev/null
        ffmpeg -y -hide_banner -loglevel error -stats -i "$f" -vf "$vf" \
          -c:v libx264 -preset slow -b:v "''${video_kbps}k" -pass 2 -passlogfile "$log/p" \
          -pix_fmt yuv420p -movflags +faststart "''${audio_opts[@]}" "$out"
        rm -rf "$log"
        echo "→ $out ($(du -h "$out" | cut -f1))"
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
    livebook
    # ChatGPT desktop (ChatGPT/Work/Codex + Remote connections) — OpenAI's official Linux .deb
    # in an FHS env; nixpkgs' `chatgpt` is darwin-only. See pkgs/chatgpt.nix to bump.
    (callPackage ./pkgs/chatgpt.nix { })
    inputs.hyprdisplays.packages.${pkgs.stdenv.hostPlatform.system}.default   # Super+Shift+M display manager
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
      # At logout the compositor socket is gone; without this the agent
      # restart-looped ("cannot open display") until systemd hit the start
      # limit. A failing ExecCondition stops the unit cleanly, no restart.
      ExecCondition = "${pkgs.bash}/bin/sh -c 'test -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\"'";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

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
        sig=$(${config.programs.hyprland.package}/bin/hyprctl instances 2>/dev/null \
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
