# Add local bin to PATH
set -gx PATH $HOME/.local/bin $PATH

# Load secrets
test -f ~/.config/fish/secrets.fish && source ~/.config/fish/secrets.fish

if status is-interactive
    # Commands to run in interactive sessions can go here
end
zoxide init fish | source
alias start-vocalinux='/home/dori/vocalinux/start-vocalinux.sh'
export PATH="$HOME/.local/bin:$PATH"

# Amp CLI
export PATH="/home/dori/.amp/bin:$PATH"

# opencode
fish_add_path /home/dori/.opencode/bin
