# Add local bin to PATH
set -gx PATH $HOME/.local/bin $PATH

# Load secrets
test -f ~/.config/fish/secrets.fish && source ~/.config/fish/secrets.fish

if status is-interactive
    # Kill the default fish greeting
    set -g fish_greeting

    # Only run fastfetch on the first terminal per session
    if not test -f /tmp/.fastfetch-done-(id -u)
        touch /tmp/.fastfetch-done-(id -u)
        fastfetch
    end
end

# Starship prompt
starship init fish | source

# Direnv (auto-activate devenv on cd)
direnv hook fish | source

# Zoxide (smart cd)
zoxide init fish | source

# Yazi wrapper — cd into directory on exit (press q)
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        cd -- "$cwd"
    end
    command rm -f -- "$tmp"
end

# Modern CLI aliases
alias cat='bat --paging=never'
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -la'
alias lt='eza --icons --tree --level=2'
alias find='fd'
alias grep='rg'
alias du='dust'
alias ps='procs'
alias diff='delta'
alias top='btop'
alias md='glow'

# Rebuild NixOS from the flake (always use --flake so Home Manager is applied)
abbr -a nrs 'sudo nixos-rebuild switch --flake ~/dotfiles'

# Slippi Dolphin (installed via nix profile: github:lytedev/slippi-nix#slippi-netplay)
# `slippi` itself is an autoloaded function that opens Slippi Launcher.
alias slippi-dolphin="$HOME/.nix-profile/bin/Slippi_Online-x86_64.AppImage"
# Folder containing the Dolphin executable — pass to ExPhil play scripts as --dolphin $DOLPHIN_DIR
# (symlink dir: libmelee requires "netplay" in the path, hardcoded Slippi Launcher convention)
set -gx DOLPHIN_DIR "$HOME/.local/share/slippi/netplay"

# Claude Code wrapper — sets terminal title so it's identifiable in Hyprland
function claude
    printf '\033]0;Claude Code: %s\007' (basename (pwd))
    command claude $argv
    printf '\033]0;%s\007' (hostname)": "(prompt_pwd)
end

# Claude Code sandbox
function sandbox
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
end

# Attach to running sandbox
function sandbox-join
    docker exec -it (docker ps -q --filter ancestor=claude-sandbox) fish
end

fish_add_path ~/.local/bin
