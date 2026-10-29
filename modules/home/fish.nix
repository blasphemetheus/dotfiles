{ config, lib, osConfig, ... }:
let
  # Helpers tied to one person's accounts and hardware (API-key Claude
  # wrappers, Slippi/Steam GameCube): see dotfiles.user.personalTools.
  personal = osConfig.dotfiles.user.personalTools;
in
{
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
    } // lib.optionalAttrs personal {
      # slippi is an autoloaded function (fish/functions/slippi.fish): opens
      # Slippi Launcher under the performance power profile. An alias here
      # would shadow it with the bare game Dolphin, which can't log in.
      # slippi-dolphin: the bare netplay Dolphin, for launching the game
      # without the launcher (local play, quick testing).
      slippi-dolphin = "${config.home.homeDirectory}/.nix-profile/bin/Slippi_Online-x86_64.AppImage";
    };

    shellAbbrs = {
      nrs = "sudo nixos-rebuild switch --flake ~/dotfiles";
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
            "build-vm — 'nixos-rebuild build-vm --flake ~/dotfiles' tests risky changes safely"
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

    } // lib.optionalAttrs personal {
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

    } // {
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
