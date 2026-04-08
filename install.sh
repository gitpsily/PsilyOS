#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  PsilyOS — Installer                     │
# │  Clone it. Run it. You're done.          │
# └──────────────────────────────────────────┘

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$HOME/.config"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║                                      ║"
echo "  ║       ┏━┓┏━┓╻╻  ╻ ╻┏━┓┏━┓          ║"
echo "  ║       ┣━┛┗━┓┃┃  ┗┳┛┃ ┃┗━┓          ║"
echo "  ║       ╹  ┗━┛╹┗━╸ ╹ ┗━┛┗━┛          ║"
echo "  ║                                      ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Dotfiles: $DOTFILES"
echo "  Target:   $CONFIG"
echo ""

# ── Preflight Checks ────────────────────────
preflight() {
    # Must be Arch
    if ! command -v pacman &>/dev/null; then
        echo "!! PsilyOS requires Arch Linux."
        exit 1
    fi

    # Need an AUR helper
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        echo ":: No AUR helper found. Installing yay..."
        sudo pacman -S --needed --noconfirm base-devel git
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
        (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
        AUR_HELPER="yay"
    fi

    echo ":: AUR helper: $AUR_HELPER"
}

# ── Package Installation ─────────────────────
install_packages() {
    echo ""
    echo ":: Installing packages..."

    # Official repo packages
    local official=(
        # Core Wayland + Hyprland
        hyprland hyprlock hypridle xdg-desktop-portal-hyprland
        waybar mako swww

        # Terminal + Shell
        foot kitty zsh starship tmux

        # Utilities
        grim slurp wl-clipboard cliphist
        brightnessctl playerctl jq bat
        network-manager-applet blueman

        # File Manager
        thunar yazi

        # Apps
        neovim btop chromium

        # Fonts
        ttf-jetbrains-mono-nerd otf-font-awesome

        # Auth agent
        polkit-gnome

        # System
        sddm qt5-graphicaleffects qt5-quickcontrols2

        # Build deps
        base-devel git
    )

    # AUR packages
    local aur=(
        rofi-wayland
        ghostty
        wallust
        wlogout
    )

    # Install official packages
    local to_install=()
    for pkg in "${official[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        echo "   Official: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
    fi

    # Install AUR packages
    local aur_install=()
    for pkg in "${aur[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            aur_install+=("$pkg")
        fi
    done

    if [ ${#aur_install[@]} -gt 0 ]; then
        echo "   AUR: ${aur_install[*]}"
        "$AUR_HELPER" -S --needed --noconfirm "${aur_install[@]}"
    fi

    echo "   All packages installed."
}

# ── Symlink Configs ──────────────────────────
link_config() {
    local src="$1"
    local dst="$2"

    # Back up existing non-symlink configs
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "   Backing up: $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    echo "   Linked: $dst"
}

symlink_configs() {
    echo ""
    echo ":: Symlinking configs..."

    # XDG config dirs
    link_config "$DOTFILES/hypr"      "$CONFIG/hypr"
    link_config "$DOTFILES/waybar"    "$CONFIG/waybar"
    link_config "$DOTFILES/rofi"      "$CONFIG/rofi"
    link_config "$DOTFILES/mako"      "$CONFIG/mako"
    link_config "$DOTFILES/ghostty"   "$CONFIG/ghostty"
    link_config "$DOTFILES/tmux"      "$CONFIG/tmux"
    link_config "$DOTFILES/wallust"   "$CONFIG/wallust"
    link_config "$DOTFILES/wlogout"   "$CONFIG/wlogout"
    link_config "$DOTFILES/yazi"      "$CONFIG/yazi"
    link_config "$DOTFILES/btop"      "$CONFIG/btop"
    link_config "$DOTFILES/scripts"   "$CONFIG/scripts"

    # Starship reads a single file, not a dir
    link_config "$DOTFILES/starship/starship.toml" "$CONFIG/starship.toml"

    # Shell configs live in $HOME
    link_config "$DOTFILES/zsh/.zshrc"    "$HOME/.zshrc"
    link_config "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
}

# ── Set Default Shell ────────────────────────
set_shell() {
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo ""
        echo ":: Setting zsh as default shell..."
        chsh -s "$(which zsh)"
    fi
}

# ── Permissions ──────────────────────────────
set_permissions() {
    echo ""
    echo ":: Setting permissions..."
    chmod +x "$DOTFILES/scripts/"*.sh
}

# ── Directories ──────────────────────────────
create_dirs() {
    echo ""
    echo ":: Creating directories..."
    mkdir -p "$HOME/Pictures/wallpapers"
    mkdir -p "$HOME/Pictures/screenshots"
    mkdir -p "$HOME/.cache/psilyos"
}

# ── Services ─────────────────────────────────
enable_services() {
    echo ""
    echo ":: Enabling services..."
    sudo systemctl enable sddm --force 2>/dev/null || true
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl enable bluetooth 2>/dev/null || true
}

# ── Run ──────────────────────────────────────
main() {
    preflight
    install_packages
    create_dirs
    symlink_configs
    set_permissions
    set_shell
    enable_services

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║       PsilyOS installed.             ║"
    echo "  ║                                      ║"
    echo "  ║  1. Drop wallpapers into:            ║"
    echo "  ║     ~/Pictures/wallpapers/           ║"
    echo "  ║                                      ║"
    echo "  ║  2. Reboot.                          ║"
    echo "  ║     Log in via SDDM -> Hyprland.     ║"
    echo "  ║                                      ║"
    echo "  ║  3. Super+Shift+W picks a wallpaper  ║"
    echo "  ║     and themes your entire desktop.   ║"
    echo "  ║                                      ║"
    echo "  ║  Welcome home.                       ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
}

main "$@"
