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
        waybar mako awww

        # Terminal + Shell
        foot kitty zsh starship tmux

        # Utilities
        grim slurp wl-clipboard cliphist
        brightnessctl playerctl jq bat
        network-manager-applet blueman

        # File Manager
        thunar yazi

        # Apps
        neovim btop chromium libreoffice-fresh discord

        # Virtualization
        libvirt qemu-full virt-viewer dnsmasq ebtables

        # Fonts
        ttf-jetbrains-mono-nerd otf-font-awesome

        # Auth agent
        polkit-gnome

        # System
        sddm qt5-graphicaleffects qt5-quickcontrols2

        # Build deps + Node (for claude code)
        base-devel git nodejs npm
    )

    # AUR packages
    local aur=(
        rofi-wayland
        ghostty
        wallust
        wlogout
        librewolf-bin
        1password
        plex-desktop
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
    link_config "$DOTFILES/foot"      "$CONFIG/foot"
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
    mkdir -p "$HOME/.cache/awww"
}

# ── Fix SDDM Session ─────────────────────────
fix_sddm_session() {
    echo ""
    echo ":: Fixing Hyprland SDDM session..."
    local session="/usr/share/wayland-sessions/hyprland.desktop"
    if [ -f "$session" ]; then
        if grep -q "Exec=Hyprland" "$session"; then
            sudo sed -i 's/Exec=Hyprland/Exec=start-hyprland/' "$session"
            echo "   Fixed: $session now uses start-hyprland"
        else
            echo "   Already using start-hyprland"
        fi
    fi
}

# ── Claude Code ──────────────────────────────
install_claude_code() {
    if ! command -v claude &>/dev/null; then
        echo ""
        echo ":: Installing Claude Code..."
        sudo npm install -g @anthropic-ai/claude-code
    fi
}

# ── Libvirt Setup ────────────────────────────
setup_libvirt() {
    echo ""
    echo ":: Setting up libvirt..."
    sudo usermod -aG libvirt "$USER" 2>/dev/null || true
}

# ── Wallpapers ───────────────────────────────
download_wallpapers() {
    local wall_dir="$HOME/Pictures/wallpapers"
    if [ "$(ls -A "$wall_dir" 2>/dev/null)" ]; then
        echo ""
        echo ":: Wallpapers already present, skipping download."
        return
    fi

    echo ""
    echo ":: Downloading wallpapers..."

    local urls=(
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=3840&q=90"
        "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=3840&q=90"
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=3840&q=90"
        "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=3840&q=90"
        "https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=3840&q=90"
        "https://images.unsplash.com/photo-1518173946687-a1e6e3b40e35?w=3840&q=90"
        "https://images.unsplash.com/photo-1465056836900-8f1e940c1f8a?w=3840&q=90"
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=3840&q=90"
        "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=3840&q=90"
        "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=3840&q=90"
    )

    local names=(
        "mountain-lake.jpg"
        "forest-fog.jpg"
        "forest-canopy.jpg"
        "rolling-hills.jpg"
        "waterfall.jpg"
        "aurora.jpg"
        "misty-forest.jpg"
        "ocean-rocks.jpg"
        "mountain-sunset.jpg"
        "golden-field.jpg"
    )

    for i in "${!urls[@]}"; do
        if [ ! -f "$wall_dir/${names[$i]}" ]; then
            echo "   Downloading: ${names[$i]}"
            curl -sL "${urls[$i]}" -o "$wall_dir/${names[$i]}" 2>/dev/null || true
        fi
    done

    echo "   Done. $(ls "$wall_dir" | wc -l) wallpapers ready."
}

# ── Services ─────────────────────────────────
enable_services() {
    echo ""
    echo ":: Enabling services..."
    sudo systemctl enable sddm --force 2>/dev/null || true
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl enable bluetooth 2>/dev/null || true
    sudo systemctl enable libvirtd 2>/dev/null || true
}

# ── Run ──────────────────────────────────────
main() {
    preflight
    install_packages
    install_claude_code
    create_dirs
    symlink_configs
    set_permissions
    set_shell
    setup_libvirt
    fix_sddm_session
    enable_services
    download_wallpapers

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
