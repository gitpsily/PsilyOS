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
    # Wait up to 30s — VMs can be slow to initialize
    for i in $(seq 1 60); do
        awww query &>/dev/null && return 0
        sleep 0.5
    done
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

pick_wallpaper() {
    if [ -f "$CURRENT" ] && [ -s "$CURRENT" ]; then
        local saved
        saved=$(cat "$CURRENT")
        # Verify the saved wallpaper is still a valid image
        if [ -f "$saved" ] && file "$saved" | grep -q 'image'; then
            echo "$saved"
            return
        fi
    fi
    # Find first valid image (skip corrupted downloads)
    if [ -d "$WALL_DIR" ]; then
        find "$WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) | while read -r f; do
            file "$f" | grep -q 'image' && echo "$f" && break
        done
    fi
}

case "${1:-}" in
    init)
        WALL=$(pick_wallpaper)
        if [ -z "$WALL" ]; then
            notify-send "PsilyOS" "No wallpapers found in $WALL_DIR" 2>/dev/null
            exit 0
        fi

        if ! wait_for_daemon; then
            notify-send "PsilyOS" "awww-daemon not ready after 30s — wallpaper skipped" 2>/dev/null
            exit 0
        fi

        set_wallpaper "$WALL"
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
