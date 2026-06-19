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
