#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  Screenshot utility             │
# │  grim + slurp + wl-copy                  │
# └──────────────────────────────────────────┘
#
# Usage:
#   screenshot.sh full      — full screen
#   screenshot.sh region    — select region
#   screenshot.sh window    — active window

SHOT_DIR="$HOME/Pictures/screenshots"
mkdir -p "$SHOT_DIR"

FILENAME="$SHOT_DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-full}" in
    full)
        grim "$FILENAME"
        ;;
    region)
        grim -g "$(slurp)" "$FILENAME"
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$FILENAME"
        ;;
esac

# Copy to clipboard
wl-copy < "$FILENAME"

# Notify
notify-send "Screenshot saved" "$FILENAME" -i "$FILENAME" -t 3000
