# Fastest possible Homebrew initialization (Hardcoded paths bypass the slow 'eval' command)
if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
    export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
    export MANPATH="/home/linuxbrew/.linuxbrew/share/man${MANPATH+:$MANPATH}:"
    export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}"
elif systemctl is-active --quiet brew-setup.service; then
    echo "☕ Homebrew is currently unpacking in the background."
    echo "   Brew commands will be ready in a minute or two. Just open a new tab when it finishes!"
    echo ""
fi

# Initialize Starship Prompt
eval "$(starship init zsh)"

# Enable Fedora's system-wide Zsh plugins
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Basic Zsh Settings
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Fix the Backspace/Delete keys just in case Wayland acts up
bindkey "^[[3~" delete-char
bindkey "^[3;5~" delete-char
