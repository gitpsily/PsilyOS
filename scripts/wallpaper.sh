#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  Wallpaper manager              │
# │  Sets wallpaper + regenerates theme      │
# └──────────────────────────────────────────┘
#
# Usage:
#   wallpaper.sh init          — set last wallpaper on startup
#   wallpaper.sh [path]        — set specific wallpaper
#   wallpaper.sh               — pick with rofi

WALL_DIR="$HOME/Pictures/wallpapers"
CACHE="$HOME/.cache/psilyos"
CURRENT="$CACHE/current_wall"

mkdir -p "$CACHE"

wait_for_daemon() {
    for i in $(seq 1 20); do
        awww query &>/dev/null && return 0
        sleep 0.5
    done
    echo "wallpaper.sh: awww-daemon not ready after 10s" >&2
    return 1
}

set_wallpaper() {
    local wall="$1"

    # Set wallpaper with transition
    awww img "$wall" \
        --transition-type grow \
        --transition-duration 1.5 \
        --transition-fps 60

    # Save current wallpaper path
    echo "$wall" > "$CURRENT"

    # Generate colors with wallust
    wallust run "$wall"

    # Reload components
    pkill -SIGUSR2 waybar 2>/dev/null
    makoctl reload 2>/dev/null

    # Reload hyprland config (picks up new theme.conf)
    hyprctl reload 2>/dev/null
}

case "${1:-}" in
    init)
        # Wait for awww-daemon to be ready (race condition on boot)
        wait_for_daemon || exit 1

        if [ -f "$CURRENT" ] && [ -s "$CURRENT" ]; then
            set_wallpaper "$(cat "$CURRENT")"
        elif [ -d "$WALL_DIR" ]; then
            FIRST=$(find "$WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) | head -1)
            [ -n "$FIRST" ] && set_wallpaper "$FIRST"
        fi
        ;;
    "")
        # Pick wallpaper with rofi
        if [ -d "$WALL_DIR" ]; then
            PICK=$(find "$WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) \
                | sort \
                | rofi -dmenu -p "Wallpaper" -i)
            [ -n "$PICK" ] && set_wallpaper "$PICK"
        else
            echo "No wallpaper directory found at $WALL_DIR"
            exit 1
        fi
        ;;
    *)
        if [ -f "$1" ]; then
            set_wallpaper "$1"
        else
            echo "File not found: $1"
            exit 1
        fi
        ;;
esac
