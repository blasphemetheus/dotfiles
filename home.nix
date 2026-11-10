{ config, lib, pkgs, osConfig, ... }:
let
  # Who this home belongs to: hosts/<name>/default.nix sets dotfiles.user.
  user = osConfig.dotfiles.user;
  identity = user.fullName != null && user.email != null;
in
{
  imports = [
    ./modules/home/health.nix
    ./modules/home/fish.nix
    ./modules/home/notifications.nix
    ./modules/home/dotfiles.nix
  ];

  home.username = user.name;
  home.homeDirectory = user.home;

  # Match your NixOS system.stateVersion
  home.stateVersion = "25.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ── Phase 4: native programs.* modules (shell integration hooks) ─────
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

  # Helix everywhere: git commits, aerc compose, sudoedit, anything honoring
  # $EDITOR/$VISUAL. (NixOS's default was nano.)
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };

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

  # (relinkAstalGjs activation removed 2026-07-12: AGS v3's nix wrapper embeds
  # its JS lib, so `ags run` needs no node_modules at all.)

  # Flip hyprshade at the schedule boundaries. Without this there is NO trigger
  # for a session that simply stays logged in: `exec-once = hyprshade auto` runs
  # only at compositor start, and hyprshade-resume (modules/system/compositors.nix) only on
  # wake. Sit at the desk through 19:00 and the filter never comes on; sit
  # through 06:00 and it never goes off.
  #
  # Replaces hand-written ~/.config/systemd/user/hyprshade.{service,timer} that
  # `hyprshade install` dropped — those pinned an absolute /nix/store path that
  # breaks on every upgrade, and were never enabled anyway.
  systemd.user.services.hyprshade-schedule = {
    Unit.Description = "Apply hyprshade schedule";
    Service = {
      Type = "oneshot";
      # Same stale-instance trap as hyprshade-resume: never `ls -t` the runtime
      # dir, dead instances outlive the live one there.
      ExecStart = toString (pkgs.writeShellScript "hyprshade-schedule" ''
        sig=$(${pkgs.hyprland}/bin/hyprctl instances 2>/dev/null \
              | sed -n 's/^instance \(.*\):$/\1/p' | head -n1)
        [ -z "$sig" ] && exit 0
        export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        exec ${pkgs.hyprshade}/bin/hyprshade auto
      '');
    };
  };
  systemd.user.timers.hyprshade-schedule = {
    Unit.Description = "hyprshade schedule boundaries (see hyprshade.toml)";
    Timer = {
      OnCalendar = [ "*-*-* 06:00:00" "*-*-* 19:00:00" ];
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Agent watchers: local-LLM triage of Hyprland ERR lines + post-resume
  # health. Explicitly opt-in: agent-watchers-toggle.sh runs
  # `systemctl --user enable --now`, and that enablement is the persistence —
  # the service has no Install section, so it never starts on its own.
  systemd.user.services.agent-watchers = {
    Unit = {
      Description = "LLM agent watchers (hyprland log tail + resume health)";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "%h/.config/hypr/scripts/agent-watchers.sh";
      Restart = "on-failure";
      RestartSec = 10;
    };
    # NO Install section — enable/disable is the user's explicit toggle.
  };

  # libsecret: `secret-tool` — aerc reads the mailbox password from the
  # GNOME keyring (running with --components=secrets) instead of plaintext.
  home.packages = [ pkgs.libsecret ];

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

  # ── Email: the host's dotfiles.user.mailbox ──────────────────────────
  # aerc (TUI client) is configured from this account block; Thunderbird is
  # installed system-side (modules/system/user.nix) and self-configures via
  # the mail domain's autoconfig DNS record. Password lives in the GNOME
  # keyring — store it once with:
  #   secret-tool store --label="<mailbox.label>" email <mailbox.address>
  # No mailbox on the host → no account, and aerc stays unconfigured.
  accounts.email.accounts.primary = lib.mkIf (user.mailbox != null) {
    primary = true;
    inherit (user.mailbox) address realName;
    userName = user.mailbox.address;
    passwordCommand = "secret-tool lookup email ${user.mailbox.address}";
    imap = {
      host = user.mailbox.imapHost;
      port = 993;
    };
    smtp = {
      host = user.mailbox.smtpHost;
      port = 465;
      tls.enable = true;
    };
    aerc = {
      enable = true;
      extraAccounts = {
        copy-to = "Sent";
        default = "INBOX";
        archive = "Archive";
      };
    };
  };

  programs.aerc = lib.mkIf (user.mailbox != null) {
    enable = true;
    extraConfig = {
      # accounts.conf lands in the world-readable Nix store; that's fine here
      # because it holds only the secret-tool lookup command, never the password.
      general.unsafe-accounts-conf = true;
      # compose editor: inherits $EDITOR = hx (home.sessionVariables)
    };
  };

  # Git-compatible VCS. Works inside existing git repos (`jj git init --colocate`).
  # Identity comes from dotfiles.user.{fullName,email}; with either unset jj
  # falls back to its own config, the way git falls back to ~/.gitconfig.
  programs.jujutsu = {
    enable = true;
    settings = lib.optionalAttrs identity {
      user = {
        name = user.fullName;
        email = user.email;
      };
    };
  };

  # Locate which package provides a command. Powers `comma` (`, cowsay hi`) and
  # a working command-not-found. Build the index once: `nix-index` (~5-10 min).
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

}
