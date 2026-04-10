#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  Keybind Cheat Sheet                     │
# │  Displays all PsilyOS keybinds in Rofi   │
# └──────────────────────────────────────────┘

rofi -dmenu -p "Keybinds" -i -no-custom -theme-str 'window { width: 550px; }' << 'EOF'
Super+Return        Terminal
Super+B             Browser (Librewolf)
Super+Space         App Launcher (Rofi)
Super+Q             Kill Window
Super+F             Fullscreen
Super+V             Float Toggle
Super+M             Exit Hyprland
Super+L             Lock Screen
Super+Shift+Q       Logout Menu
Super+Shift+W       Wallpaper Picker
Super+Shift+V       Clipboard History
Super+R             Run Command
Super+Tab           Window Switcher
Super+H/J/K/L       Focus Direction
Super+1-9           Workspace
Super+Shift+1-9     Move to Workspace
Super+Shift+HJKL    Move Window
Super+Ctrl+HJKL     Resize Window
Print               Screenshot (Full)
Super+Print         Screenshot (Region)
Super+Shift+Print   Screenshot (Window)
Ctrl+Space          tmux Prefix
Alt+1-9             tmux Window
Alt+Left/Right      tmux Prev/Next Window
Alt+Up/Down         tmux Prev/Next Session
EOF
