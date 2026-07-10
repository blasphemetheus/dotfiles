{ config, pkgs, lib, ... }:

let
  # absolute path required by mkOutOfStoreSymlink (Phase 3 active configs)
  dotfiles = "/home/blewf/dotfiles";

  # Weekly "is my setup healthy?" check — desktop notification via mako.
  # Deterministic, no LLM: flake staleness, disk pressure, uncommitted dotfiles.
  healthHints = pkgs.writeShellApplication {
    name = "nixos-health-hints";
    runtimeInputs = with pkgs; [ git libnotify coreutils ];
    text = ''
      hints=""
      n=0

      lock="${dotfiles}/flake.lock"
      if [ -f "$lock" ]; then
        age=$(( ( $(date +%s) - $(stat -c %Y "$lock") ) / 86400 ))
        if [ "$age" -gt 30 ]; then
          hints="$hints• flake.lock is $age days old — 'nix flake update' (release bumps need a reboot)"$'\n'
          n=$((n + 1))
        fi
      fi

      use=$(df --output=pcent / | tail -1 | tr -dc '0-9'); [ -n "$use" ] || use=0
      if [ "$use" -ge 85 ]; then
        hints="$hints• / is $use% full — 'nix-collect-garbage --delete-older-than 30d'; check ~/.cache/bazel"$'\n'
        n=$((n + 1))
      fi

      if [ -n "$(git -C "${dotfiles}" status --porcelain 2>/dev/null)" ]; then
        hints="$hints• ~/dotfiles has uncommitted changes"$'\n'
        n=$((n + 1))
      fi

      if [ "$n" -gt 0 ]; then
        notify-send -a nixos-health -u normal "🔧 Setup hints ($n)" "$hints"
      fi
    '';
  };
in
{
  home.username = "blewf";
  home.homeDirectory = "/home/blewf";

  # Match your NixOS system.stateVersion
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── Phase 2: Simple configs (stable, rarely edited) ──────────────────
  # These use `source` (copied to Nix store, immutable).
  # Requires rebuild to update, but fully reproducible.

  xdg.configFile = {
    # Cava — audio visualizer
    "cava/config".source = ./cava/.config/cava/config;
    "cava/shaders" = {
      source = ./cava/.config/cava/shaders;
      recursive = true;
    };
    "cava/themes" = {
      source = ./cava/.config/cava/themes;
      recursive = true;
    };

    # Wob — volume/brightness overlay bar
    "wob/wob.ini".source = ./wob/.config/wob/wob.ini;

    # Helix — modal editor
    "helix/config.toml".source = ./helix/.config/helix/config.toml;

    # Lazygit — git TUI
    "lazygit/config.yml".source = ./lazygit/.config/lazygit/config.yml;

    # Wlogout — power menu
    "wlogout/layout".source = ./wlogout/.config/wlogout/layout;
    "wlogout/style.css".source = ./wlogout/.config/wlogout/style.css;

    # Rofi — app launcher
    "rofi/config.rasi".source = ./rofi/.config/rofi/config.rasi;
    "rofi/catppuccin.rasi".source = ./rofi/.config/rofi/catppuccin.rasi;

    # Mako — notification daemon
    "mako/config".source = ./mako/.config/mako/config;

    # ── Phase 3: Active configs (edited + reloaded live) ─────────────────
    # Whole-dir out-of-store symlinks: ~/.config/<x> points straight at the repo,
    # so edits apply on reload without a rebuild, and HM does NOT manage the
    # runtime-mutable inner files (the opacity toggle writes into hypr/, waybar
    # style variants, ags needs its gitignored node_modules).
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hypr/.config/hypr";
    "waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/waybar/.config/waybar";
    "kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/kitty/.config/kitty";

    # ── Phase 5: remaining app configs (symlinked, not programs.* modules) ──
    # nvim: lazy.nvim manages plugins under ~/.local/share, config stays live.
    # ags: whole-dir symlink so the gitignored node_modules/@girs stay reachable.
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim/.config/nvim";
    "ags".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ags/.config/ags";
  };

  # ── Phase 4: native programs.* modules (shell integration hooks) ─────
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  programs.git = {
    enable = true;
    settings.merge.conflictstyle = "zdiff3";
    ignores = [ "**/.claude/settings.local.json" ];
    # identity stays in ~/.gitconfig (mounted into the sandbox) — not managed here.
  };

  # delta is its own module now (was programs.git.delta)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = { navigate = true; side-by-side = true; line-numbers = true; };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship/.config/starship.toml);
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;

  # Weekly "setup health" desktop notification (script defined in `let` above).
  systemd.user.services.nixos-health-hints = {
    Unit.Description = "NixOS setup health hints (desktop notification)";
    Service = {
      Type = "oneshot";
      ExecStart = "${healthHints}/bin/nixos-health-hints";
    };
  };
  systemd.user.timers.nixos-health-hints = {
    Unit.Description = "Weekly NixOS setup health hints";
    Timer = {
      OnCalendar = "Mon 10:00";
      Persistent = true; # fire on next login if the machine was off Monday
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Shell history in SQLite, fuzzy-searchable. Owns Ctrl-R.
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
  };

  # fzf WITHOUT fish keybindings — atuin owns Ctrl-R, and we don't want fzf
  # stealing it. Still available as the `fzf` binary for other tools to call.
  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };

  # Terminal multiplexer. Fish integration off on purpose: it would auto-attach
  # a session on every shell start.
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
  };

  # Git-compatible VCS. Works inside existing git repos (`jj git init --colocate`).
  programs.jujutsu = {
    enable = true;
    settings.user = {
      name = "Bradley Lewis Fargo";
      email = "blewfargs@gmail.com";
    };
  };

  # Locate which package provides a command. Powers `comma` (`, cowsay hi`) and
  # a working command-not-found. Build the index once: `nix-index` (~5-10 min).
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fish = {
    enable = true;

    shellAliases = {
      cat = "bat --paging=never";
      ls = "eza --icons --group-directories-first";
      ll = "eza --icons --group-directories-first -la";
      lt = "eza --icons --tree --level=2";
      find = "fd";
      grep = "rg";
      du = "dust";
      ps = "procs";
      diff = "delta";
      top = "btop";
      md = "glow";
      slippi = "${config.home.homeDirectory}/.nix-profile/bin/Slippi_Online-x86_64.AppImage";
    };

    shellAbbrs.nrs = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka";

    # Login / non-interactive init. PATH (~/.local/bin) comes from home.sessionPath;
    # starship/direnv/zoxide hooks come from their programs.* modules above.
    shellInit = ''
      set -gx DOLPHIN_DIR "$HOME/.local/share/slippi/netplay"
      test -f ~/.config/fish/secrets.fish && source ~/.config/fish/secrets.fish
    '';

    interactiveShellInit = ''
      # fastfetch once per login session
      if not test -f /tmp/.fastfetch-done-(id -u)
          touch /tmp/.fastfetch-done-(id -u)
          fastfetch
      end
    '';

    functions = {
      # Rotating "tool of the day" tip — reminds me to use the cool stuff I own.
      # Deterministic by day-of-year so it changes daily but not per-shell.
      fish_greeting = ''
        set -l tips \
            "jj — 'jj git init --colocate' in any repo; 'jj undo' reverses ANY operation" \
            "zellij — terminal multiplexer with sane keybinds (tmux, but friendlier)" \
            "atuin — Ctrl-R now fuzzy-searches your entire shell history" \
            "comma — ', cowsay hi' runs any program without installing it" \
            "dua — 'dua i' browses disk usage interactively (you run tight on space)" \
            "nh — 'nh os switch' rebuilds and shows a diff of what changed" \
            "difftastic — 'difft a b' does structural, syntax-aware diffs" \
            "niri / river / dwl — log out and pick one at the greeter to try a new WM" \
            "nix-locate — 'nix-locate bin/ffmpeg' finds which package ships a binary" \
            "hexyl — 'hexyl <file>' is a colored hex viewer" \
            "ncdu / dua — find what's eating the disk before it bites" \
            "yazi — press 'y' to open the file manager; it cd's where you quit" \
            "build-vm — 'nixos-rebuild build-vm --flake ~/dotfiles#nixos_slanka' tests risky changes safely"
        set -l i (math (date +%j) % (count $tips) + 1)
        set_color yellow; echo "  💡 "$tips[$i]; set_color normal
      '';

      # yazi wrapper — cd into the directory yazi exits in (press q)
      y = ''
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            cd -- "$cwd"
        end
        command rm -f -- "$tmp"
      '';

      # Claude Code wrapper — sets the terminal title so it's identifiable in Hyprland
      claude = ''
        printf '\033]0;Claude Code: %s\007' (basename (pwd))
        command claude $argv
        printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
      '';

      # Run Claude Code in a Docker sandbox
      sandbox = ''
        docker run -it \
            --cap-add NET_ADMIN --cap-add NET_RAW \
            -v ~/.claude:/home/claude/.claude \
            -v ~/.claude.json:/home/claude/.claude.json \
            -v ~/.gitconfig:/home/claude/.gitconfig:ro \
            -v ~/git/edifice:/workspace/edifice \
            -v ~/git/exphil:/workspace/exphil \
            -v ~/git/shine:/workspace/shine \
            -v ~/git/nx:/workspace/nx \
            -v ~/dotfiles:/workspace/dotfiles \
            -v ~/git/.devcontainer/output:/out \
            -v /tmp/claude-sandbox:/tmp \
            claude-sandbox $argv
      '';

      # Attach to the running sandbox container
      sandbox-join = ''
        docker exec -it (docker ps -q --filter ancestor=claude-sandbox) fish
      '';
    };
  };
}
