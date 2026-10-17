{
  config,
  pkgs,
  inputs,
  ...
}:
{
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
    # muscle-memory binds. Session entry is in modules/system/compositors.nix.
    (dwl.override { configH = ../../dwl/config.h; })
    dwlb # status bar for dwl (fed by `dwl -s`, see dwl/startup.sh)

    # Hyprland ecosystem
    waybar
    ironbar # Rust Wayland bar (alongside waybar)
    swww
    hyprlock
    hypridle
    hyprpicker
    pyprland # Scratchpads, magnify, and more
    xwayland-satellite # X11 apps under niri (niri spawns it; see niri/config.kdl)

    # Launcher and notifications
    rofi
    wofi
    anyrun # Rust Wayland-native launcher
    mako

    # Terminal
    kitty
    ghostty # Zig GPU-accelerated terminal
    wezterm # Rust GPU-accelerated terminal + multiplexer
    nushell # Structured data shell

    # Clipboard
    wl-clipboard
    cliphist

    # Screenshot / recording
    grim
    slurp
    satty # screenshot annotation tool
    wf-recorder
    # Video playback (for reviewing screen recordings from wf-recorder)
    mpv # lightweight keyboard-driven player: `mpv file.mp4`
    celluloid # GTK GUI front-end over mpv
    vlc # heavyweight, plays everything
    timg # in-terminal video/gif playback via kitty graphics: `timg file.mp4`

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
    ncdu # interactive disk usage browser
    dua # faster parallel `du` with a TUI (dua i)
    fclones # find + hardlink/remove duplicate files

    # Nix tooling
    comma # `, cowsay hi` — run any program without installing it (needs nix-index db)
    statix # lint Nix for antipatterns
    deadnix # find unused Nix bindings
    nixfmt # official Nix formatter (was nixfmt-rfc-style)

    # More CLI
    yq # jq for YAML/XML/TOML
    bandwhich # per-process network bandwidth TUI
    hexyl # hex viewer
    difftastic # structural (AST-aware) diff — `difft a.ex b.ex`

    # System utilities
    usbutils # lsusb (debugging USB devices, e.g. the GC adapter)
    jq # JSON processor (used by session save/restore)
    socat # Socket relay (used by per-workspace wallpaper listener)
    bubblewrap # OS-level sandboxing (used by Claude Code)
    power-profiles-daemon # CPU power profile switching
    libnotify # notify-send
    networkmanagerapplet
    wsdd # gvfs network browsing spawns this (was "Failed to spawn the wsdd daemon")
    brightnessctl
    playerctl
    pavucontrol
    audacity # Audio recording/editing (interviews)
    blueman
    wob # Volume/brightness overlay bar
    hyprshade # Blue light filter
    qbittorrent
    # File manager
    kdePackages.dolphin

    # Dev tools
    neovim
    helix
    lazygit
    vscode
    gh # GitHub CLI
    zed-editor # Rust GPU-accelerated editor
    opencode # provider-agnostic terminal coding agent (Kimi K3 via "Kimi For Coding")

    # Modern CLI tools (Rust/Go replacements)
    bat # cat with syntax highlighting
    eza # ls with icons and git status
    fd # find replacement
    ripgrep # grep replacement
    delta # git diff viewer
    dust # du replacement (disk usage)
    procs # ps replacement
    sd # sed replacement
    tokei # code line counter (cloc replacement)
    just # task runner (make replacement)
    tealdeer # tldr pages (simplified man pages)
    xh # HTTP client (curl/httpie replacement)
    hyperfine # benchmarking tool
    ouch # compression (tar/zip/7z auto-detect)
    doggo # DNS lookup (dig replacement)
    duf # disk usage overview (df replacement)
    broot # tree explorer with fuzzy search
    navi # interactive CLI cheatsheet
    choose # cut/awk replacement
    serpl # TUI search and replace across files
    felix-fm # Rust TUI file manager
    fastfetch # system info splash
    yazi # TUI file manager with image preview
    glow # terminal markdown renderer

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
    wtype # Wayland keyboard input (for rofimoji typing)
    wl-kbptr # Keyboard-driven mouse control
    walker # Wayland app launcher
    hyprpanel # All-in-one panel (alongside waybar)

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
    (callPackage ../../pkgs/chatgpt.nix { })
    inputs.hyprdisplays.packages.${pkgs.stdenv.hostPlatform.system}.default # Super+Shift+M display manager
  ];

}
