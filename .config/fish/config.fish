set fish_greeting ''

source (starship init fish --print-full-init | psub)
zoxide init fish | source

fastfetch

alias a2="aria2c -x 16"
alias ls="eza"
alias zd="z"
alias y="yay"

set -gx PNPM_HOME "/home/eren/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end

set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH