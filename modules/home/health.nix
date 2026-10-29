{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  inputAge = pkgs.callPackage ../../pkgs/flake-input-age.nix { };
  # Weekly "is my setup healthy?" check — desktop notification via mako.
  # Deterministic, no LLM: flake staleness, disk pressure, uncommitted dotfiles.
  healthHints = pkgs.writeShellApplication {
    name = "nixos-health-hints";
    runtimeInputs = with pkgs; [
      git
      libnotify
      coreutils
      jq
      inputAge
    ];
    text = ''
      hints=""
      n=0

      lock="${dotfiles}/flake.lock"
      if [ -f "$lock" ]; then
        ages=$(flake-input-age --json "$lock" | jq -r '.[] | [.input, (if .ageDays == null then "unknown" else (.ageDays | tostring) end)] | @tsv')
        while IFS=$'\t' read -r input age; do
          [ -n "$input" ] || continue
          if [ "$age" = unknown ]; then
            hints="$hints• $input: locked source age unknown"$'\n'
          elif [ "$age" -gt 30 ]; then
            hints="$hints• $input: locked source is $age days old — review updates/pins"$'\n'
          else
            continue
          fi
          n=$((n + 1))
        done <<< "$ages"
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
    runtimeInputs = with pkgs; [
      git
      atuin
      libnotify
      coreutils
      procps
      findutils
      gawk
      gnugrep
      gnused
      inputAge
    ];
    text = ''
      cd "${dotfiles}" || exit 0
      claude="${config.home.homeDirectory}/.nix-profile/bin/claude"
      [ -x "$claude" ] || { echo "no claude binary" >&2; exit 0; }

      tmp=$(mktemp)
      {
        cat <<'PROMPT'
      You are my NixOS setup advisor. Read home.nix, configuration.nix, flake.nix and
      the modules/, profiles/, and hosts/ directories, plus the system state below.
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
        echo "Locked source revision ages (not time since last update; deliberate pins may stay old):"
        flake-input-age flake.lock
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

in
{
  home.packages = [ inputAge ];
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
  # Wrapped in gpu-guard.sh (2026-09-26): if another compute job holds the
  # GPU when the timer fires, the run is deferred 24 h and re-checked, and so
  # on, instead of racing an ExPhil training run. (The advisor itself talks to
  # the Anthropic API, not Ollama — the guard is cheap insurance so any future
  # local-model switch inherits it.)
  systemd.user.services.nixos-setup-advisor = {
    Unit.Description = "Weekly LLM setup advisor (writes SUGGESTIONS.md)";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/hypr/scripts/gpu-guard.sh nixos-setup-advisor -- ${setupAdvisor}/bin/nixos-setup-advisor";
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

}
