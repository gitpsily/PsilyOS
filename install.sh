#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  PsilyOS — Installer                     │
# │  Clone it. Run it. You're done.          │
# └──────────────────────────────────────────┘

# No set -e — we handle errors per-function so one failure doesn't kill the script

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
        cifs-utils nwg-displays

        # File Manager
        thunar yazi

        # Apps
        neovim btop chromium libreoffice-fresh discord

        # Virtualization
        libvirt qemu-full virt-viewer dnsmasq ebtables

        # Hardware monitoring + cooling
        lm_sensors liquidctl

        # Fonts
        ttf-jetbrains-mono-nerd otf-font-awesome

        # Auth agent
        polkit-gnome

        # System
        sddm qt5-graphicaleffects qt5-quickcontrols2
        wlr-randr

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

    # Install official packages (one at a time to survive failures)
    local installed=0
    local failed=()
    for pkg in "${official[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            echo "   Installing: $pkg"
            if sudo pacman -S --needed --noconfirm "$pkg" 2>&1 | tail -1; then
                installed=$((installed + 1))
            else
                failed+=("$pkg")
                echo "   FAILED: $pkg"
            fi
        fi
    done

    # Install AUR packages (one at a time)
    for pkg in "${aur[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            echo "   Installing (AUR): $pkg"
            if "$AUR_HELPER" -S --needed --noconfirm "$pkg" 2>&1 | tail -3; then
                installed=$((installed + 1))
            else
                failed+=("$pkg")
                echo "   FAILED: $pkg"
            fi
        fi
    done

    if [ ${#failed[@]} -gt 0 ]; then
        echo ""
        echo "   Installed $installed packages."
        echo "   Failed: ${failed[*]}"
        echo "   (You can install failed packages manually later)"
    else
        echo "   All packages installed. ($installed new)"
    fi
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
    echo ""
    echo ":: Shell: zsh is installed but NOT set as default."
    echo "   To switch: chsh -s \$(which zsh)"
    echo "   Test first: zsh (type 'exit' to return to bash)"
}

# ── Permissions ──────────────────────────────
set_permissions() {
    echo ""
    echo ":: Setting permissions..."
    chmod +x "$DOTFILES/scripts/"*.sh
}

# ── NVIDIA Setup (bare metal only) ───────────
setup_nvidia() {
    if systemd-detect-virt --quiet 2>/dev/null; then
        return  # Skip in VMs
    fi

    if ! lspci | grep -qi nvidia; then
        return  # No NVIDIA GPU
    fi

    echo ""
    echo ":: NVIDIA GPU detected — configuring..."

    # Install drivers
    local nvidia_pkgs=(nvidia nvidia-utils nvidia-settings lib32-nvidia-utils)
    for pkg in "${nvidia_pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || true
        fi
    done

    # Hyprland NVIDIA env vars
    local nvidia_conf="$DOTFILES/hypr/nvidia.conf"
    cat > "$nvidia_conf" << 'NVCONF'
# ┌──────────────────────────────────────────┐
# │  NVIDIA Configuration                    │
# │  Auto-generated for bare metal NVIDIA    │
# └──────────────────────────────────────────┘

env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

cursor {
    no_hardware_cursors = true
}
NVCONF

    # Source nvidia.conf from hyprland.conf if not already
    if ! grep -q "nvidia.conf" "$DOTFILES/hypr/hyprland.conf"; then
        sed -i '/source = .\/autostart.conf/a source = ./nvidia.conf' "$DOTFILES/hypr/hyprland.conf"
    fi

    # Add nvidia modules to mkinitcpio
    if ! grep -q "nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
        sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi

    echo "   NVIDIA configured."
}

# ── Cooling Profiles ────────────────────────
setup_cooling() {
    if systemd-detect-virt --quiet 2>/dev/null; then
        return  # Skip in VMs
    fi

    echo ""
    echo ":: Setting up cooling profiles..."

    # Create cooling script
    local cool_script="$DOTFILES/scripts/cooling.sh"
    cat > "$cool_script" << 'COOLEOF'
#!/usr/bin/env bash
# ┌──────────────────────────────────────────┐
# │  Cooling Profile — Aggressive            │
# │  Run at boot or manually                 │
# └──────────────────────────────────────────┘

# ── AIO Pump + Fans (liquidctl) ──────────────
# Detect and configure AIO cooler
if command -v liquidctl &>/dev/null; then
    # Initialize all devices
    liquidctl initialize --match ""  2>/dev/null

    # Aggressive pump profile — ramp up early
    liquidctl set pump speed \
        20 60 \
        30 70 \
        35 80 \
        40 90 \
        45 100 \
        2>/dev/null || true

    # Aggressive fan profile — keep it cool
    liquidctl set fan speed \
        20 50 \
        25 60 \
        30 70 \
        35 80 \
        40 90 \
        45 100 \
        2>/dev/null || true

    echo "AIO: Aggressive profile set"
else
    echo "liquidctl not found — skipping AIO"
fi

# ── NVIDIA GPU Fan (if available) ────────────
if command -v nvidia-settings &>/dev/null; then
    # Enable manual fan control
    nvidia-settings -a "[gpu:0]/GPUFanControlState=1" 2>/dev/null || true

    # Aggressive GPU fan curve via nvidia-settings
    # Set to 80% minimum — adjust after testing
    nvidia-settings -a "[fan:0]/GPUTargetFanSpeed=80" 2>/dev/null || true

    echo "GPU: Fan set to 80% (manual mode)"
fi

echo "Cooling profile applied."
COOLEOF
    chmod +x "$cool_script"

    # Create systemd service for boot
    sudo tee /etc/systemd/system/psilyos-cooling.service > /dev/null << 'SVCEOF'
[Unit]
Description=PsilyOS Cooling Profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/%i/.config/scripts/cooling.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

    # Use a user-specific service instead
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/cooling.service" << USVCEOF
[Unit]
Description=PsilyOS Cooling Profile

[Service]
Type=oneshot
ExecStart=$DOTFILES/scripts/cooling.sh
RemainAfterExit=yes

[Install]
WantedBy=default.target
USVCEOF

    systemctl --user daemon-reload
    systemctl --user enable cooling.service 2>/dev/null || true

    echo "   Cooling service installed (user systemd)."
}

# ── VM Detection + Tools ─────────────────────
setup_vm() {
    if systemd-detect-virt --quiet 2>/dev/null; then
        local virt=$(systemd-detect-virt)
        echo ""
        echo ":: VM detected ($virt) — installing guest tools..."
        case "$virt" in
            vmware)
                if ! pacman -Qi open-vm-tools &>/dev/null; then
                    sudo pacman -S --needed --noconfirm open-vm-tools
                fi
                sudo systemctl enable vmtoolsd 2>/dev/null || true
                sudo systemctl start vmtoolsd 2>/dev/null || true
                ;;
            kvm|qemu)
                if ! pacman -Qi qemu-guest-agent &>/dev/null; then
                    sudo pacman -S --needed --noconfirm qemu-guest-agent spice-vdagent
                fi
                sudo systemctl enable qemu-guest-agent 2>/dev/null || true
                ;;
            oracle)
                if ! pacman -Qi virtualbox-guest-utils &>/dev/null; then
                    sudo pacman -S --needed --noconfirm virtualbox-guest-utils
                fi
                sudo systemctl enable vboxservice 2>/dev/null || true
                ;;
        esac

        # Set VM renderer env vars in /etc/environment (read by PAM before any session)
        sudo touch /etc/environment
        if ! grep -q "WLR_NO_HARDWARE_CURSORS" /etc/environment; then
            echo 'WLR_NO_HARDWARE_CURSORS=1' | sudo tee -a /etc/environment
            echo 'WLR_RENDERER_ALLOW_SOFTWARE=1' | sudo tee -a /etc/environment
            echo "   Added WLR env vars to /etc/environment"
        else
            echo "   WLR env vars already in /etc/environment"
        fi

        echo "   Guest tools configured."
        echo "   VM renderer env vars added to /etc/environment"
    fi
}

# ── SMB Mount ────────────────────────────────
setup_smb() {
    local envfile="$DOTFILES/.env"
    if [ ! -f "$envfile" ]; then
        echo ""
        echo ":: No .env file found — skipping SMB mount."
        echo "   To enable, create $envfile with:"
        echo "     SMB_IP=10.69.1.218"
        echo "     SMB_SHARE=storage"
        echo "     SMB_USER=your_user"
        echo "     SMB_PASS=your_pass"
        return
    fi

    source "$envfile"

    if [ -z "${SMB_IP:-}" ] || [ -z "${SMB_SHARE:-}" ] || [ -z "${SMB_USER:-}" ] || [ -z "${SMB_PASS:-}" ]; then
        echo ""
        echo ":: .env missing SMB vars — skipping mount."
        return
    fi

    echo ""
    echo ":: Setting up SMB mount..."

    local mountpoint="/mnt/${SMB_SHARE}"
    local credfile="$HOME/.smbcredentials"

    # Write credentials file (600 perms)
    cat > "$credfile" << CRED
username=${SMB_USER}
password=${SMB_PASS}
CRED
    chmod 600 "$credfile"

    # Create mount point
    sudo mkdir -p "$mountpoint"

    # Add to fstab if not already there
    local fstab_entry="//${SMB_IP}/${SMB_SHARE} ${mountpoint} cifs credentials=${credfile},uid=$(id -u),gid=$(id -g),nofail,x-systemd.automount 0 0"
    if ! grep -q "${SMB_IP}/${SMB_SHARE}" /etc/fstab 2>/dev/null; then
        echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
        echo "   Added to /etc/fstab"
    fi

    # Mount now
    sudo mount "$mountpoint" 2>/dev/null && echo "   Mounted: $mountpoint" || echo "   Mount will be available after reboot"
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
    # Get sudo upfront and keep it alive throughout
    sudo -v
    while true; do sudo -n true; sleep 55; kill -0 "$$" || exit; done 2>/dev/null &

    preflight
    install_packages
    install_claude_code
    create_dirs
    symlink_configs
    set_permissions
    set_shell
    setup_nvidia
    setup_cooling
    setup_vm
    setup_libvirt
    setup_smb
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
