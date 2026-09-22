{ config, pkgs, ... }:

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

  # Weekly LLM-tier advisor: the script gathers local state, then a headless
  # `claude -p` reads the dotfiles + that state and writes SUGGESTIONS.md. Only
  # Read/Write are granted (state is pre-gathered), so nothing shell-arbitrary
  # runs unattended. Uses your own nix-profile claude (subscription/quota).
  setupAdvisor = pkgs.writeShellApplication {
    name = "nixos-setup-advisor";
    runtimeInputs = with pkgs; [ git atuin libnotify coreutils procps findutils gawk gnugrep gnused ];
    text = ''
      cd "${dotfiles}" || exit 0
      claude="${config.home.homeDirectory}/.nix-profile/bin/claude"
      [ -x "$claude" ] || { echo "no claude binary" >&2; exit 0; }

      tmp=$(mktemp)
      {
        cat <<'PROMPT'
      You are my NixOS setup advisor. Read home.nix, configuration.nix, flake.nix and
      HOME-MANAGER-MIGRATION.md in the current directory, plus the system state below.
      Then WRITE a file named SUGGESTIONS.md at the repo root containing:
        - a SHORT prioritized list (max 6 bullets) of concrete improvements to my
          setup, skipping anything already done in the recent commits;
        - gentle nudges to use tools I installed but rarely run — infer "rarely run"
          from the usage counts below (0 or very low = unused);
        - a final line starting with "TLDR:" punchy enough for a desktop notification.
      Be specific and concise. Do NOT run shell commands; everything is here or in files.

      ## System state
      PROMPT
        echo "Date: $(date '+%Y-%m-%d %H:%M')"
        echo "Disk /: $(df -h / | tail -1)"
        echo "System generations: $(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l)"
        echo "flake.lock age (days): $(( ( $(date +%s) - $(stat -c %Y flake.lock) ) / 86400 ))"
        echo "Compositor: $(pgrep -x Hyprland >/dev/null && echo Hyprland || echo non-Hyprland)"
        echo "Recent commits:"; git log --oneline -12
        echo "Tool usage counts (atuin history, first word of each command, whole db):"
        # One awk pass over the history tallies by command name (no grep -cw
        # exit-1 double-print bug, no substring false positives). atuin itself
        # is invoked via Ctrl-R and niri from the greeter, so their counts
        # would be meaningless zeros — both omitted.
        atuin history list --cmd-only 2>/dev/null \
          | awk '{print $1}' | sort | uniq -c \
          | awk -v tools="jj zellij comma nix-locate river difft dua ncdu nh hexyl bandwhich fclones" '
              BEGIN { n = split(tools, wanted, " "); for (i = 1; i <= n; i++) count[wanted[i]] = 0 }
              { count[$2] = $1 }
              END { for (i = 1; i <= n; i++) printf "  %s: %d\n", wanted[i], count[wanted[i]] }'
      } > "$tmp"

      timeout 420 "$claude" -p --allowedTools "Read Edit Write Glob Grep" \
        --permission-mode acceptEdits < "$tmp" > /tmp/nixos-setup-advisor.log 2>&1 || true
      rm -f "$tmp"

      if [ -f SUGGESTIONS.md ]; then
        tldr=$(grep -m1 '^TLDR:' SUGGESTIONS.md | sed 's/^TLDR:[[:space:]]*//')
        [ -n "$tldr" ] || tldr="New setup suggestions ready"
        notify-send -a nixos-advisor -u normal "🤖 Weekly setup suggestions" "$tldr"$'\n'"→ ~/dotfiles/SUGGESTIONS.md"
      fi
    '';
  };

  # Persistent notification history: mako's own history is in-memory (lost on
  # mako restart / logout), so log every Notify DBus call to a jsonl file. jq
  # --arg does the JSON escaping, so bodies with quotes/commas stay valid.
  notifLogger = pkgs.writeShellApplication {
    name = "notification-logger";
    runtimeInputs = with pkgs; [ dbus jq coreutils ];
    text = ''
      logfile="${config.home.homeDirectory}/.local/state/mako/history.jsonl"
      mkdir -p "$(dirname "$logfile")"
      dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null |
      while IFS= read -r line; do
        case "$line" in
          *"member=Notify"*) inblock=1; sc=0; app=""; sum=""; body="" ;;
          "   string "*)
            if [ "''${inblock:-0}" = 1 ]; then
              sc=$((sc + 1)); s=''${line#*\"}; s=''${s%\"}
              case $sc in 1) app=$s ;; 3) sum=$s ;; 4) body=$s ;; esac
            fi ;;
          "   array ["*)
            if [ "''${inblock:-0}" = 1 ] && [ "$sc" -ge 4 ]; then
              jq -nc --arg a "$app" --arg s "$sum" --arg b "$body" --argjson t "$(date +%s)" \
                '{time:$t,app:$a,summary:$s,body:$b}' >> "$logfile" 2>/dev/null || true
              inblock=0
            fi ;;
        esac
      done
    '';
  };

  # Rofi picker over the persistent log (Super+Shift+N): search all history,
  # pick one, re-display it. Trims the log to the last 5000 lines on open.
  notifPicker = pkgs.writeShellApplication {
    name = "notification-picker";
    runtimeInputs = with pkgs; [ jq rofi libnotify coreutils ];
    text = ''
      logfile="${config.home.homeDirectory}/.local/state/mako/history.jsonl"
      if [ ! -s "$logfile" ]; then notify-send "Notification history" "empty so far"; exit 0; fi
      tail -n 5000 "$logfile" > "$logfile.tmp" && mv "$logfile.tmp" "$logfile"
      mapfile -t entries < <(tac "$logfile")
      display=$(printf '%s\n' "''${entries[@]}" | jq -r \
        '[(.time|strflocaltime("%m-%d %H:%M")), "[\(.app)]", .summary, (if .body!="" then "— "+.body else "" end)] | join(" ") | gsub("\n";" ")')
      idx=$(printf '%s\n' "$display" | rofi -dmenu -i -p "Notifications" -format 'i')
      [ -n "$idx" ] || exit 0
      entry="''${entries[$idx]}"
      notify-send -a "$(jq -r .app <<<"$entry")" "$(jq -r .summary <<<"$entry")" "$(jq -r .body <<<"$entry")"
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

    # aerc — keybindings (defaults + helix tweaks; aerc replaces its built-in
    # binds when this file exists, so it carries the full set)
    "aerc/binds.conf".source = ./aerc/binds.conf;

    # ── Phase 3: Active configs (edited + reloaded live) ─────────────────
    # Whole-dir out-of-store symlinks: ~/.config/<x> points straight at the repo,
    # so edits apply on reload without a rebuild, and HM does NOT manage the
    # runtime-mutable inner files (the opacity toggle writes into hypr/, waybar
    # style variants, ags needs its gitignored node_modules).
    "hypr".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hypr/.config/hypr";
    "waybar".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/waybar/.config/waybar";
    "kitty".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/kitty/.config/kitty";
    # niri: alternative compositor session (config.kdl auto-reloads on save).
    "niri".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/niri/.config/niri";
    # hyprwhspr-rs: single-source the dictation config. The live copy used to be
    # a hand-synced real file that could drift from the repo; vocab-add.sh also
    # edits this file in place and needs the repo path to BE the live path.
    "hyprwhspr-rs".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/hyprwhspr/.config/hyprwhspr-rs";

    # ── Phase 5: remaining app configs (symlinked, not programs.* modules) ──
    # nvim: lazy.nvim manages plugins under ~/.local/share, config stays live.
    # ags: whole-dir symlink so the gitignored node_modules/@girs stay reachable.
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim/.config/nvim";
    "ags".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ags/.config/ags";
  };

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

  # Weekly LLM advisor (headless claude → SUGGESTIONS.md + notification).
  systemd.user.services.nixos-setup-advisor = {
    Unit.Description = "Weekly LLM setup advisor (writes SUGGESTIONS.md)";
    Service = {
      Type = "oneshot";
      ExecStart = "${setupAdvisor}/bin/nixos-setup-advisor";
      TimeoutStartSec = "10min";
    };
  };
  systemd.user.timers.nixos-setup-advisor = {
    Unit.Description = "Weekly LLM setup advisor";
    Timer = {
      OnCalendar = "Mon 10:30"; # 30 min after the deterministic health check
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Flip hyprshade at the schedule boundaries. Without this there is NO trigger
  # for a session that simply stays logged in: `exec-once = hyprshade auto` runs
  # only at compositor start, and hyprshade-resume (configuration.nix) only on
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

  # Persistent notification logger. WantedBy=default.target, NOT
  # graphical-session.target — the latter doesn't activate under greetd.
  systemd.user.services.notification-logger = {
    Unit = {
      Description = "Persistent notification history logger";
      After = [ "dbus.service" ];
    };
    Service = {
      ExecStart = "${notifLogger}/bin/notification-logger";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Hourly LLM notification digest, running ONLY while DND is on: the timer
  # deliberately has no Install.WantedBy — dnd-smart.sh starts/stops it with
  # the mako mode, so DND state is the only owner and there's no enable-state
  # to drift across reboots.
  systemd.user.services.notif-digest = {
    Unit.Description = "LLM notification digest (mako history → ollama summary)";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/hypr/scripts/notif-digest.sh";
    };
  };
  systemd.user.timers.notif-digest = {
    Unit.Description = "Hourly notification digest while DND is active";
    Timer = {
      OnCalendar = "hourly";
      Persistent = false;
    };
    # NO Install.WantedBy — dnd-smart.sh owns this timer's lifecycle.
  };

  # notification-picker on PATH so the Hyprland keybind can call it by name.
  # libsecret: `secret-tool` — aerc reads the mailbox password from the
  # GNOME keyring (running with --components=secrets) instead of plaintext.
  home.packages = [ notifPicker pkgs.libsecret ];

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

  # ── Email: spikenard@ramblings.cc on Migadu ──────────────────────────
  # aerc (TUI client) is configured from this account block; Thunderbird is
  # installed system-side (configuration.nix) and self-configures via the
  # autoconfig DNS record on ramblings.cc. Password lives in the GNOME
  # keyring — store it once with:
  #   secret-tool store --label="Migadu spikenard" email spikenard@ramblings.cc
  accounts.email.accounts.ramblings = {
    primary = true;
    address = "spikenard@ramblings.cc";
    realName = "Bradley Fargo";
    userName = "spikenard@ramblings.cc";
    passwordCommand = "secret-tool lookup email spikenard@ramblings.cc";
    imap = {
      host = "imap.migadu.com";
      port = 993;
    };
    smtp = {
      host = "smtp.migadu.com";
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

  programs.aerc = {
    enable = true;
    extraConfig = {
      # accounts.conf lands in the world-readable Nix store; that's fine here
      # because it holds only the secret-tool lookup command, never the password.
      general.unsafe-accounts-conf = true;
      # compose editor: inherits $EDITOR = hx (home.sessionVariables)
    };
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
      # slippi is an autoloaded function (fish/functions/slippi.fish): opens
      # Slippi Launcher under the performance power profile. An alias here
      # would shadow it with the bare game Dolphin, which can't log in.
      # slippi-dolphin: the bare netplay Dolphin, for launching the game
      # without the launcher (local play, quick testing).
      slippi-dolphin = "${config.home.homeDirectory}/.nix-profile/bin/Slippi_Online-x86_64.AppImage";
    };

    shellAbbrs = {
      nrs = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka";
      nos = "nh os switch";
    };

    # Login / non-interactive init. PATH (~/.local/bin) comes from home.sessionPath;
    # starship/direnv/zoxide hooks come from their programs.* modules above.
    shellInit = ''
      set -gx DOLPHIN_DIR "$HOME/.local/share/slippi/netplay"

      # Dolphin GCI-folder cards (emulated GameCube Slot A). Drop a .gci here
      # and Training Mode CE / Melee sees it as a memory-card file; Dolphin
      # globs *.gci and reads the gamecode out of each header, so the on-disk
      # name is cosmetic (convention: <makercode>-<gamecode>-<internal name>).
      # Variables, not aliases, so they work as arguments: `cp x.gci $card_a`.
      # card_a       = mainline beta build (Slippi Launcher useNetplayBeta=true)
      # card_a_online = the older Ishiiruka ~/.config/SlippiOnline build
      set -gx card_a "$HOME/.config/slippi-dolphin/netplay-beta/GC/USA/Card A"
      set -gx card_a_online "$HOME/.config/SlippiOnline/GC/USA/Card A"

      test -f ~/.config/fish/secrets.fish && source ~/.config/fish/secrets.fish
    '';

    interactiveShellInit = ''
      # atuin 18.12 bug: _atuin_search re-assigns the picked command through a
      # bare command substitution, which splits it on newlines into a list;
      # `commandline -r "$list"` then joins with spaces, so a `\`-continued
      # multi-line command comes back as `\ ` (an escaped space) and breaks.
      # Re-source the function with `string collect` on that line.
      functions -q _atuin_search
      and functions _atuin_search \
          | string replace -- 'set ATUIN_H (string trim -- $ATUIN_H)' 'set ATUIN_H (string trim -- $ATUIN_H | string collect)' \
          | source

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

      # Steam with GameCube adapter support (Wii U mode, 057e:0337). Steam's
      # native GC support (Nov 2025) is off by default because libusb access
      # to the adapter is EXCLUSIVE — the same handle Slippi Dolphin needs,
      # so don't run this while playing Slippi / the ExPhil bot is up.
      steam-gcc = ''
        if pgrep -f "Slippi_Online|slippi-netplay" >/dev/null
            echo "steam-gcc: Slippi Dolphin is running — it and Steam fight over the adapter."
            echo "Close Slippi first (or launch plain 'steam' to leave the adapter alone)."
            return 1
        end
        if lsusb | grep -q "0079:1843"
            echo "steam-gcc: adapter is in PC mode (DragonRise) — flip the switch to 'Wii U'"
            echo "for Steam's native GC support + the 1000Hz overclock. Continuing anyway."
        end
        steam -enable-libusb-gamecube $argv
      '';

      # Claude Code wrapper — sets the terminal title so it's identifiable in Hyprland
      claude = ''
        printf '\033]0;Claude Code: %s\007' (basename (pwd))
        command claude $argv
        printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
      '';

      # Claude Code pointed at a third-party Anthropic-compatible endpoint.
      #
      # `env` builds the child process's environment directly, so none of
      # these overrides touch the shell — plain `claude` still goes to
      # Anthropic on your subscription, in the same terminal, afterwards.
      # (`env` also runs the real binary rather than the `claude` function
      # above, so each wrapper sets its own title.)
      #
      # CLAUDE_CONFIG_DIR gives each provider a fully separate profile:
      # its own credentials, sessions, projects and .claude.json. Verified
      # empirically — pointing it at an empty dir populates all four.
      #
      # Auth header differs by vendor, so follow each one's own docs:
      # ANTHROPIC_AUTH_TOKEN sends `Authorization: Bearer` (Moonshot),
      # ANTHROPIC_API_KEY sends `x-api-key` (DeepSeek).
      #
      # Keys go in ~/.config/fish/secrets.fish, already sourced by shellInit.
      claude-k3 = ''
        if not set -q MOONSHOT_API_KEY
            echo "claude-k3: MOONSHOT_API_KEY unset — add it to ~/.config/fish/secrets.fish" >&2
            return 1
        end
        printf '\033]0;Claude K3: %s\007' (basename (pwd))
        env -u ANTHROPIC_API_KEY \
            CLAUDE_CONFIG_DIR="$HOME/.claude-k3" \
            ANTHROPIC_BASE_URL="https://api.moonshot.ai/anthropic" \
            ANTHROPIC_AUTH_TOKEN="$MOONSHOT_API_KEY" \
            ANTHROPIC_MODEL="kimi-k3" \
            ANTHROPIC_DEFAULT_OPUS_MODEL="kimi-k3" \
            ANTHROPIC_DEFAULT_SONNET_MODEL="kimi-k3" \
            ANTHROPIC_DEFAULT_HAIKU_MODEL="kimi-k3" \
            CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 \
            claude $argv
        printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
      '';
      claude-kimi = "claude-k3 $argv";

      # DeepSeek V4 Pro. Cheaper than K3 and scores higher on SWE-bench, but
      # its Anthropic shim does NOT support MCP tools, document/search content
      # blocks, or container uploads — so MCP servers silently do nothing here.
      # Unknown model names get silently remapped to deepseek-v4-flash, so a
      # typo downgrades you rather than erroring.
      #
      # CLAUDE_CODE_MAX_CONTEXT_TOKENS is required: Claude Code doesn't know
      # these model ids, so it assumes a 200K window and auto-compacts at 200K
      # even though both models are 1M. (Not CLAUDE_CODE_AUTO_COMPACT_WINDOW —
      # that one is a percentage, 1-100, and a token count there is nonsense.)
      claude-ds = ''
        if not set -q DEEPSEEK_API_KEY
            echo "claude-ds: DEEPSEEK_API_KEY unset — add it to ~/.config/fish/secrets.fish" >&2
            return 1
        end
        printf '\033]0;Claude DeepSeek: %s\007' (basename (pwd))
        env -u ANTHROPIC_AUTH_TOKEN \
            CLAUDE_CONFIG_DIR="$HOME/.claude-ds" \
            ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic" \
            ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY" \
            ANTHROPIC_MODEL="deepseek-v4-pro" \
            ANTHROPIC_DEFAULT_OPUS_MODEL="deepseek-v4-pro" \
            ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek-v4-pro" \
            ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek-v4-flash" \
            CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 \
            claude $argv
        printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
      '';

      # Fully offline Claude Code against the local Ollama server
      # (services.ollama in configuration.nix). Same isolation scheme as the
      # wrappers above: its own CLAUDE_CONFIG_DIR, provider env only on the
      # child. Ollama ignores the token but Claude Code insists one is set.
      # Override the model per call: `claude-local --model gpt-oss:20b`.
      claude-local = ''
        set -l model qwen3-coder:30b
        if not curl -sf --max-time 2 http://localhost:11434/api/version >/dev/null
            echo "claude-local: ollama not answering on :11434 — sudo systemctl start ollama" >&2
            return 1
        end
        printf '\033]0;Claude Local: %s\007' (basename (pwd))
        env -u ANTHROPIC_API_KEY \
            CLAUDE_CONFIG_DIR="$HOME/.claude-local" \
            ANTHROPIC_BASE_URL="http://localhost:11434" \
            ANTHROPIC_AUTH_TOKEN="ollama" \
            ANTHROPIC_MODEL="$model" \
            ANTHROPIC_DEFAULT_OPUS_MODEL="$model" \
            ANTHROPIC_DEFAULT_SONNET_MODEL="$model" \
            ANTHROPIC_DEFAULT_HAIKU_MODEL="$model" \
            CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536 \
            DISABLE_TELEMETRY=1 \
            claude $argv
        printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
      '';

      # (sandbox / sandbox-join removed 2026-09-17: they ran Claude Code in a
      # `claude-sandbox` Docker container, but the Docker daemon was dropped
      # 2026-09-08 and the image is gone — the functions only errored. Claude
      # Code's built-in bubblewrap sandbox covers the use case now. Resurrect
      # from git history if needed.)

      # Teach the dictation daemon a word: vocab-add "wrong hearing" "correct term"
      # (appends to word_overrides in the hyprwhspr-rs config + restarts it)
      vocab-add = ''
        ~/.config/hypr/scripts/vocab-add.sh $argv
      '';

      # Recover a dead lockscreen. hyprlock 0.9.2 SEGVs on teardown (CShader
      # dtor racing the async asset thread) and leaves Hyprland's session-lock
      # surface orphaned: black screen that swallows input. Nothing unlocks it,
      # but the compositor is still alive underneath.
      #
      # Run from a TTY (Ctrl+Alt+F2, log in, `lockfix`) or any shell you can
      # still reach. Do NOT parse /run/user/$UID/hypr by mtime — dead instances
      # leave dirs behind with newer mtimes than the live one. `hyprctl
      # instances` filters to actually-running compositors, so trust that.
      lockfix = ''
        set -l sigs (hyprctl instances | string replace -rf '^instance (.*):$' '$1')
        if test (count $sigs) -eq 0
            echo "lockfix: no running Hyprland instance — nothing to recover"
            return 1
        end
        # Which instances already have a live hyprlock? Read each hyprlock's
        # signature out of /proc — never pkill globally: with two instances up
        # (tty2-escape scenario) that murders the healthy instance's lock too.
        set -l lock_pids (pgrep -x hyprlock)
        set -l locked_sigs
        for p in $lock_pids
            set -a locked_sigs (tr '\0' '\n' < /proc/$p/environ 2>/dev/null | string replace -f 'HYPRLAND_INSTANCE_SIGNATURE=' "")
        end
        set -l orphans
        for s in $sigs
            contains -- $s $locked_sigs; or set -a orphans $s
        end
        if test (count $orphans) -gt 0
            # Orphaned session lock, no hyprlock attached: just respawn —
            # allow_session_lock_restore reattaches it. Nothing to kill.
            for s in $orphans
                set -gx HYPRLAND_INSTANCE_SIGNATURE $s
                hyprctl eval 'hl.config({ misc = { allow_session_lock_restore = true } })'
                hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'
                echo "lockfix: relaunched hyprlock on orphaned instance $s"
            end
            return 0
        end
        # Every instance has a hyprlock — assume the visible one is hung.
        # Kill and respawn only the first instance's hyprlock.
        if test (count $sigs) -gt 1
            echo "lockfix: "(count $sigs)" Hyprland instances, all locked — recovering the first."
        end
        set -gx HYPRLAND_INSTANCE_SIGNATURE $sigs[1]
        for p in $lock_pids
            grep -qz "HYPRLAND_INSTANCE_SIGNATURE=$sigs[1]" /proc/$p/environ 2>/dev/null
            and kill $p
        end
        sleep 0.5
        hyprctl eval 'hl.config({ misc = { allow_session_lock_restore = true } })'
        hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'
        echo "lockfix: killed and relaunched hyprlock on $sigs[1]"
      '';
    };
  };
}
