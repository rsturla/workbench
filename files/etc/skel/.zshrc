# Path to oh-my-zsh installation
export ZSH=/usr/share/oh-my-zsh

# Set theme
ZSH_THEME="robbyrussell"

# Disable automatic updates (managed by system)
zstyle ':omz:update' mode disabled

# Plugins
plugins=(
    git
    direnv
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
