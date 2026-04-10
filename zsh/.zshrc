# ┌──────────────────────────────────────────┐
# │  Zsh Configuration             │
# └──────────────────────────────────────────┘

# ── History ──────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ── Options ──────────────────────────────────
setopt AUTO_CD
setopt CORRECT
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS

# ── Completion ───────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Key Bindings ─────────────────────────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# ── Aliases ──────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -a'
alias grep='grep --color=auto'
alias cat='bat --paging=never 2>/dev/null || cat'
alias tree='tree -C'
alias vim='nvim'
alias v='nvim'
alias c='clear'

# Tmux
alias t='tmux attach 2>/dev/null || tmux new-session'
alias tdl='~/.config/scripts/tmux-dev.sh'
alias tsl='~/.config/scripts/tmux-swarm.sh'

# System
alias update='sudo pacman -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null; sudo paccache -r'

# Shortcuts
alias wall='~/.config/scripts/wallpaper.sh'
alias shot='~/.config/scripts/screenshot.sh'

# Disable autocorrect for commands zsh gets wrong
alias awww='nocorrect awww'
alias awww-daemon='nocorrect awww-daemon'

# ── Path ─────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Editor ───────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim

# ── Wayland ──────────────────────────────────
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland,x11
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# ── Wallust Colors ───────────────────────────
# Terminal colors handled by foot/ghostty config, not escape sequences

# ── Starship Prompt ──────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
