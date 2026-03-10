# Add local bin to PATH
set -gx PATH $HOME/.local/bin $PATH

# Load secrets
test -f ~/.config/fish/secrets.fish && source ~/.config/fish/secrets.fish

if status is-interactive
    fastfetch
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

# Claude Code wrapper — sets terminal title so it's identifiable in Hyprland
function claude
    printf '\033]0;Claude Code: %s\007' (basename (pwd))
    command claude $argv
    printf '\033]0;%s\007' (fish_prompt_hostname)": "(prompt_pwd)
end
