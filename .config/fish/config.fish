set fish_greeting ''

source (starship init fish --print-full-init | psub)
zoxide init fish | source

fastfetch

alias a2="aria2c -x 16"
alias ls="eza"
alias zd="z"
alias y="yay"

set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path /home/eren/.spicetify
