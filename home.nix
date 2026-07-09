{ config, pkgs, lib, ... }:

let
  # absolute path required by mkOutOfStoreSymlink (Phase 3 active configs)
  dotfiles = "/home/blewf/dotfiles";
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
    # so edits apply on reload without a rebuild (same as the old stow links), and
    # HM does NOT manage the runtime-mutable inner files (opacity toggle writes
    # into hypr/, waybar style variants, etc). Unstow each (`stow -D <x>`) before
    # the first switch or HM refuses the existing symlink.
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
    delta = {
      enable = true;
      options = { navigate = true; side-by-side = true; line-numbers = true; };
    };
    extraConfig.merge.conflictstyle = "zdiff3";
    ignores = [ "**/.claude/settings.local.json" ];
    # identity stays in ~/.gitconfig (mounted into the sandbox) — not managed here.
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
      set -g fish_greeting
      # fastfetch once per login session
      if not test -f /tmp/.fastfetch-done-(id -u)
          touch /tmp/.fastfetch-done-(id -u)
          fastfetch
      end
    '';

    functions = {
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
