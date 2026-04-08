# ┌──────────────────────────────────────────┐
# │  Zsh Login Profile             │
# │  Auto-start Hyprland on tty1             │
# └──────────────────────────────────────────┘

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    exec Hyprland
fi
