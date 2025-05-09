# Disable the default greeting
set fish_greeting ''

# Initialize starship prompt
source (starship init fish --print-full-init | psub)

# Initialize zoxide (directory jumper)
zoxide init fish | source

# Display system info on startup
fastfetch

# Aliases
alias a2="aria2c -x 16"
alias ls="eza"
alias ll="eza -la"
alias la="eza -a"
alias lt="eza -T"
alias lsg="eza --git-ignore"
alias zd="z"
alias y="yay"
alias c="clear"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias df="df -h"
alias free="free -h"
alias grep="grep --color=auto"
alias ip="ip -c address"
alias cat="bat --style=plain --paging=never"

# Directory bookmarks
function mark
    set -U fish_mark_$argv[1] (pwd)
end

function goto
    set -q fish_mark_$argv[1]; and cd $fish_mark_$argv[1]
end

function marks
    set -l marks (set -n | grep ^fish_mark_)
    for mark in $marks
        set -l mark_name (string replace fish_mark_ '' $mark)
        set -l mark_path $$mark
        printf "%-10s -> %s\n" $mark_name $mark_path
    end
end

# Git shortcuts
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias gb="git branch"
alias glog="git log --oneline --graph --decorate"

# Environment variables
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path $PNPM_HOME

# Use vim as default editor if available
if type -q vim
    set -gx EDITOR vim
    set -gx VISUAL vim
    alias vi="vim"
end

# Add cargo bin path if Rust is installed
if test -d $HOME/.cargo/bin
    fish_add_path $HOME/.cargo/bin
end

# Add go bin path if Go is installed
if test -d $HOME/go/bin
    fish_add_path $HOME/go/bin
end

# Add bun bin path if Bun is installed
if test -d $XDG_CACHE_HOME/.bun/bin
    fish_add_path $XDG_CACHE_HOME/.bun/bin
end

# Zig-specific settings
if type -q zig
    # Set Zig cache directory
    set -gx ZIG_CACHE_DIR "$HOME/.cache/zig"
    
    # Add zig aliases
    alias zb="zig build"
    alias zr="zig run"
    alias zt="zig test"
    alias zfmt="zig fmt"
end

# Create a function to update system (Arch-specific)
function update
    echo "Updating system packages..."
    yay -Syu
    
    echo "Updating fish plugins..."
    if type -q fisher
        fisher update
    end
    
    echo "Updating flatpak apps..."
    if type -q flatpak
        flatpak update -y
    end
    
    echo "System update complete!"
end

# Extract function - handles various archive formats
function extract
    if test -f $argv[1]
        switch $argv[1]
            case '*.tar.bz2'
                tar xjf $argv[1]
            case '*.tar.gz'
                tar xzf $argv[1]
            case '*.bz2'
                bunzip2 $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*.gz'
                gunzip $argv[1]
            case '*.tar'
                tar xf $argv[1]
            case '*.tbz2'
                tar xjf $argv[1]
            case '*.tgz'
                tar xzf $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.Z'
                uncompress $argv[1]
            case '*.7z'
                7z x $argv[1]
            case '*.xz'
                xz -d $argv[1]
            case '*'
                echo "'$argv[1]' cannot be extracted via extract"
        end
    else
        echo "'$argv[1]' is not a valid file"
    end
end

# System information function
function sysinfo
    echo "System Information:"
    echo "-------------------"
    echo "Hostname: "(cat /etc/hostname)
    echo "Kernel: "(uname -r)
    echo "Uptime: "(uptime -p)
    echo "CPU: "(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    echo "Memory: "(free | grep Mem | awk '{print $3 " / " $2 " used"}')
    echo "Disk usage: "(df -h / | tail -1 | awk '{print $3 " / " $2 " used"}') 
    echo "IP address: "(/usr/bin/ip -4 addr show | grep -oP "(?<=inet ).*(?=/)" | head -1)
end

# Function to find large files
function findlarge
    set -l size "100M"
    if test (count $argv) -gt 0
        set size $argv[1]
    end
    find . -type f -size +$size -exec ls -lh {} \; | sort -k5,5hr
end

# Function to quickly serve current directory
function serve
    set -l port 8000
    if test (count $argv) -gt 0
        set port $argv[1]
    end
    python -m http.server $port
end

# Key bindings
bind \cp up-or-search # Ctrl+P for history search up
bind \cn down-or-search # Ctrl+N for history search down
bind \cf forward-char # Ctrl+F to move cursor forward
bind \cb backward-char # Ctrl+B to move cursor backward
bind \e\[1\;5D backward-word # Ctrl+Left to move back one word
bind \e\[1\;5C forward-word # Ctrl+Right to move forward one word

# Add PATH additions
fish_add_path $HOME/.local/bin
