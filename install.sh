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

    # Enable multilib repo (needed for Steam, 32-bit libs)
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo ":: Enabling multilib repo..."
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy
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
        vlc gimp obs-studio docker pavucontrol

        # Gaming
        steam mangohud lutris

        # Thunar extras
        thunar-archive-plugin xarchiver

        # Virtualization
        libvirt qemu-full virt-viewer dnsmasq ebtables

        # Hardware monitoring + cooling
        lm_sensors liquidctl

        # Sandbox deps (Claude Code)
        bubblewrap socat

        # Fonts
        ttf-jetbrains-mono-nerd otf-font-awesome

        # Auth agent
        polkit-gnome

        # System
        sddm qt5-graphicaleffects qt5-quickcontrols2
        wlr-randr

        # Build deps + Node (for claude code)
        base-devel git nodejs npm github-cli

        # Python (for claude code hooks + overseer)
        python python-pip yamllint
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
        cursor-bin
        prismlauncher
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
    ln -sfn "$src" "$dst"
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
    # NOTE: symlinks break Claude Code's bwrap sandbox — create real files
    # that source the PsilyOS versions instead
    for rcfile in .zshrc .zprofile; do
        if [ -L "$HOME/$rcfile" ]; then
            rm "$HOME/$rcfile"
        elif [ -e "$HOME/$rcfile" ] && [ ! -L "$HOME/$rcfile" ]; then
            mv "$HOME/$rcfile" "$HOME/${rcfile}.bak"
        fi
        echo "[[ -f \"$DOTFILES/zsh/$rcfile\" ]] && source \"$DOTFILES/zsh/$rcfile\"" > "$HOME/$rcfile"
        echo "   Created: $HOME/$rcfile (sourcing shim)"
    done

    # Clean up stale source lines from previous installs
    sed -i '/vm.conf/d' "$DOTFILES/hypr/hyprland.conf" 2>/dev/null || true
    sed -i '/nvidia.conf/d' "$DOTFILES/hypr/hyprland.conf" 2>/dev/null || true
}

# ── Set Default Shell ────────────────────────
set_shell() {
    # Check both $SHELL env var AND /etc/passwd (env var doesn't update until re-login)
    local current_shell
    current_shell=$(getent passwd "$USER" | cut -d: -f7)

    if [ "$(basename "$current_shell")" = "zsh" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        echo ""
        echo ":: Shell already set to zsh."
        return
    fi

    echo ""
    echo ":: Setting default shell to zsh..."
    sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || {
        echo "   chsh failed — you may need to run manually:"
        echo "   chsh -s \$(which zsh)"
    }
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

    # Add nvidia modules to mkinitcpio (handles both empty and pre-existing MODULES)
    if ! grep -q "nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
        local nvidia_mods="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
        if grep -q 'MODULES=()' /etc/mkinitcpio.conf 2>/dev/null; then
            # Empty MODULES — replace directly
            sudo sed -i "s/MODULES=()/MODULES=($nvidia_mods)/" /etc/mkinitcpio.conf
        else
            # Pre-existing modules — append inside the parens
            sudo sed -i "s/MODULES=(\(.*\))/MODULES=(\1 $nvidia_mods)/" /etc/mkinitcpio.conf
        fi
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

    # User-level systemd service (no root required)
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

        # Mask hyprland-update-screen — it crashes in VMs (SIGABRT on GTK render)
        # Can't remove hyprland-guiutils (hard dep of hyprland), but the update
        # splash is non-essential and kills the session when it crashes.
        if [ -f /usr/bin/hyprland-update-screen ]; then
            sudo dpkg-divert --quiet --divert /usr/bin/hyprland-update-screen.real --rename /usr/bin/hyprland-update-screen 2>/dev/null || \
            sudo mv /usr/bin/hyprland-update-screen /usr/bin/hyprland-update-screen.real 2>/dev/null || true
            echo '#!/bin/sh' | sudo tee /usr/bin/hyprland-update-screen > /dev/null
            echo 'exit 0' | sudo tee -a /usr/bin/hyprland-update-screen > /dev/null
            sudo chmod +x /usr/bin/hyprland-update-screen
            echo "   Masked hyprland-update-screen (crashes in VMs)"
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
        echo "     SMB_IP=your_nas_ip"
        echo "     SMB_SHARE=your_share"
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

    # Create empty placeholders for wallust-generated configs.
    # Hyprland/waybar/etc crash on boot if source'd files don't exist yet.
    # wallust run will overwrite these with real themed versions.
    local placeholders=(
        "$DOTFILES/hypr/theme.conf"
        "$DOTFILES/hypr/hyprlock.conf"
        "$DOTFILES/waybar/style.css"
        "$DOTFILES/rofi/theme.rasi"
        "$DOTFILES/mako/config"
        "$DOTFILES/foot/foot.ini"
        "$DOTFILES/ghostty/config"
        "$DOTFILES/tmux/tmux.conf"
        "$DOTFILES/wlogout/style.css"
    )
    for f in "${placeholders[@]}"; do
        [ -f "$f" ] || touch "$f"
    done

    # Foot needs [tweak] even before wallust runs, otherwise it spams a
    # font-monospace warning on every launch
    if [ ! -s "$DOTFILES/foot/foot.ini" ]; then
        cat > "$DOTFILES/foot/foot.ini" << 'FOOTEOF'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=10x8

[cursor]
style=beam

[tweak]
font-monospace-warn=no
FOOTEOF
    fi

    echo "   Wallust placeholders created (overwritten on first theme apply)"
}

# ── Restore Claude Code Setup ────────────────
restore_claude() {
    # Find the most recent Claude backup anywhere on the system
    local backup=""
    backup=$(find "$HOME" /mnt /media /tmp "$DOTFILES" \
        -maxdepth 4 -name "claude-backup-*.tar.gz" -type f 2>/dev/null \
        | sort -t- -k3,5 -r | head -1)

    if [ -z "$backup" ]; then
        echo ""
        echo ":: No Claude Code backup found."
        read -rp "   Path to backup tarball (or Enter to skip): " backup
        [ -z "$backup" ] && return
        if [ ! -f "$backup" ]; then
            echo "   File not found: $backup — skipping."
            return
        fi
    else
        echo ""
        echo ":: Found Claude backup: $backup"
        read -rp "   Use this? [Y/n] " confirm
        if [[ "$confirm" =~ ^[Nn] ]]; then
            read -rp "   Path to backup tarball (or Enter to skip): " backup
            [ -z "$backup" ] && return
            if [ ! -f "$backup" ]; then
                echo "   File not found: $backup — skipping."
                return
            fi
        fi
    fi

    echo ""
    echo ":: Restoring Claude Code setup from $backup..."

    # Detect backup format: new format has relative paths (CLAUDE.md, .claude/, overseer/)
    # Old format has absolute paths (home/username/.claude/, home/username/overseer/)
    local has_home_dir=$(tar tzf "$backup" 2>/dev/null | grep "^home/" | head -1)

    if [ -n "$has_home_dir" ]; then
        # ── Old format: absolute paths under home/username/ ──
        local tmpdir=$(mktemp -d)
        tar xzf "$backup" -C "$tmpdir" 2>/dev/null || true

        local backup_home=$(find "$tmpdir/home" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
        if [ -z "$backup_home" ]; then
            echo "   Could not find home directory in backup — skipping."
            rm -rf "$tmpdir"
            return
        fi

        local backup_user=$(basename "$backup_home")

        [ -d "$backup_home/.claude" ] && cp -a "$backup_home/.claude" "$HOME/"
        [ -d "$backup_home/overseer" ] && cp -a "$backup_home/overseer" "$HOME/"
        [ -f "$backup_home/CLAUDE.md" ] && cp -a "$backup_home/CLAUDE.md" "$HOME/"
        [ -d "$backup_home/.claude-mem" ] && cp -a "$backup_home/.claude-mem" "$HOME/"
        [ -f "$backup_home/.claude.json" ] && cp -a "$backup_home/.claude.json" "$HOME/"
        [ -d "$backup_home/alfred-data" ] && cp -a "$backup_home/alfred-data" "$HOME/"
        mkdir -p "$HOME/.local/share"
        [ -d "$backup_home/.local/share/overseer-chromadb" ] && cp -a "$backup_home/.local/share/overseer-chromadb" "$HOME/.local/share/"
        [ -f "$backup_home/.local/share/overseer-fts.db" ] && cp -a "$backup_home/.local/share/overseer-fts.db" "$HOME/.local/share/"
        [ -f "$backup_home/.local/share/overseer-graph.db" ] && cp -a "$backup_home/.local/share/overseer-graph.db" "$HOME/.local/share/"

        # Remap username if changed
        local old_project="$HOME/.claude/projects/-home-${backup_user}"
        local new_project="$HOME/.claude/projects/-home-$(whoami)"
        if [ -d "$old_project" ] && [ "$old_project" != "$new_project" ]; then
            mv "$old_project" "$new_project"
            echo "   Remapped project memory: $backup_user -> $(whoami)"
        fi

        if [ -f "$HOME/.claude/settings.json" ] && [ "$backup_user" != "$(whoami)" ]; then
            sed -i "s|/home/${backup_user}|$HOME|g" "$HOME/.claude/settings.json"
            echo "   Fixed paths in settings.json"
        fi
        if [ -f "$HOME/.claude.json" ] && [ "$backup_user" != "$(whoami)" ]; then
            sed -i "s|/home/${backup_user}|$HOME|g" "$HOME/.claude.json"
            echo "   Fixed paths in .claude.json"
        fi
        # Clean up stale .mcp.json from old backups (Claude Code doesn't read it)
        rm -f "$HOME/.claude/.mcp.json" 2>/dev/null

        rm -rf "$tmpdir"
    else
        # ── New format: relative paths from $HOME ──
        echo "   Detected new backup format (relative paths)"
        mkdir -p "$HOME/.local/share"
        tar xzf "$backup" -C "$HOME" 2>/dev/null
        echo "   Extracted to $HOME"
    fi

    # ── Wire up memory system ────────────────────

    # 1. Install uv (needed by session flush hooks)
    if ! command -v uv &>/dev/null; then
        echo "   Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
    fi

    # 2. Build overseer venv with chromadb (pip install --user fails on Arch PEP 668)
    local venv="$HOME/.local/share/overseer-venv"
    if [ ! -d "$venv" ]; then
        echo "   Building overseer venv..."
        python -m venv "$venv"
        "$venv/bin/pip" install chromadb 2>/dev/null
    fi

    # 3. Build memory-compiler venv
    if [ -f "$HOME/.claude/memory-compiler/pyproject.toml" ] && [ ! -d "$HOME/.claude/memory-compiler/.venv" ]; then
        echo "   Building memory-compiler venv..."
        (cd "$HOME/.claude/memory-compiler" && "$HOME/.local/bin/uv" sync 2>/dev/null || true)
    fi

    # 4. Wire Overseer MCP server via claude mcp add (user scope)
    # NOTE: ~/.claude/.mcp.json is NOT read by Claude Code — must use claude mcp add
    if command -v claude &>/dev/null; then
        claude mcp remove overseer -s user 2>/dev/null || true
        claude mcp add -s user overseer -- "$HOME/.local/share/overseer-venv/bin/python3" "$HOME/overseer/mcp-chromadb/server.py" 2>/dev/null
        echo "   Wired Overseer MCP server (claude mcp add -s user)"
    else
        echo "   WARNING: claude CLI not available — add Overseer MCP manually after install:"
        echo "   claude mcp add -s user overseer -- $HOME/.local/share/overseer-venv/bin/python3 $HOME/overseer/mcp-chromadb/server.py"
    fi
    # Clean up stale .mcp.json if it exists (was never read by Claude Code)
    rm -f "$HOME/.claude/.mcp.json" 2>/dev/null

    # 5. Ensure SessionStart hook exists in settings.json
    if [ -f "$HOME/.claude/settings.json" ]; then
        if ! grep -q "SessionStart" "$HOME/.claude/settings.json"; then
            local hook_cmd="python3 \$HOME/.claude/memory-compiler/hooks/session-start.py"
            python3 -c "
import json
with open('$HOME/.claude/settings.json') as f:
    cfg = json.load(f)
hooks = cfg.setdefault('hooks', {})
hooks['SessionStart'] = [{'hooks': [{'type': 'command', 'command': '$hook_cmd', 'timeout': 5}]}]
with open('$HOME/.claude/settings.json', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null && echo "   Added SessionStart hook to settings.json"
        fi
    fi

    # 6. Set git identity from .env (or prompt)
    if [ -z "$(git config --global user.name)" ]; then
        if [ -n "${GIT_USER_NAME:-}" ]; then
            git config --global user.name "$GIT_USER_NAME"
            echo "   Git user.name set to: $GIT_USER_NAME"
        else
            echo "   Git identity not configured. Set GIT_USER_NAME in .env"
        fi
    fi
    if [ -z "$(git config --global user.email)" ]; then
        if [ -n "${GIT_USER_EMAIL:-}" ]; then
            git config --global user.email "$GIT_USER_EMAIL"
            echo "   Git user.email set to: $GIT_USER_EMAIL"
        else
            echo "   Git email not configured. Set GIT_USER_EMAIL in .env"
        fi
    fi

    # 6b. Set up gh credential helper for git push
    if command -v gh &>/dev/null; then
        gh auth setup-git 2>/dev/null || true
        echo "   GitHub credential helper configured"
    fi

    # 6c. Generate SSH key if not present
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        local ssh_comment="${SSH_KEY_COMMENT:-${GIT_USER_EMAIL:-$(whoami)}}"
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        ssh-keygen -t ed25519 -C "$ssh_comment" -f "$HOME/.ssh/id_ed25519" -N ""
        echo "   SSH key generated: ~/.ssh/id_ed25519"
        echo "   Add public key to GitHub: https://github.com/settings/keys"
        echo "   Public key:"
        cat "$HOME/.ssh/id_ed25519.pub"
    else
        echo "   SSH key already exists"
    fi

    # Install all plugins if claude is available
    if command -v claude &>/dev/null; then
        # Add marketplaces
        claude plugins marketplace add thedotmack --source github --repo thedotmack/claude-mem 2>/dev/null || true
        claude plugins marketplace add claudikins-marketplace --source github --repo elb-pr/claudikins-marketplace 2>/dev/null || true

        # Install claudikins plugins
        claude plugins install claudikins-kernel --marketplace claudikins-marketplace 2>/dev/null || true
        claude plugins install claudikins-tool-executor --marketplace claudikins-marketplace 2>/dev/null || true
        claude plugins install claudikins-klaus --marketplace claudikins-marketplace 2>/dev/null || true
        claude plugins install claudikins-grfp --marketplace claudikins-marketplace 2>/dev/null || true
        claude plugins install claudikins-automatic-context-manager --marketplace claudikins-marketplace 2>/dev/null || true

        # Install claude-mem (then disable — data migrated to Overseer)
        claude plugins install claude-mem --marketplace thedotmack 2>/dev/null || true
        claude plugins disable claude-mem@thedotmack 2>/dev/null || true

        echo "   Plugins installed:"
        echo "     - claudikins-kernel (plan/execute/verify/ship workflow)"
        echo "     - claudikins-tool-executor (96 MCP tools via 3-tool interface)"
        echo "     - claudikins-klaus (debugging agent)"
        echo "     - claudikins-grfp (README creation pipeline)"
        echo "     - claudikins-automatic-context-manager (auto handoff at 60%)"
        echo "     - claude-mem (DISABLED — data in Overseer)"
    else
        echo "   Claude Code config restored. Install plugins after installing claude:"
        echo "     claude plugins marketplace add thedotmack --source github --repo thedotmack/claude-mem"
        echo "     claude plugins marketplace add claudikins-marketplace --source github --repo elb-pr/claudikins-marketplace"
        echo "     claude plugins install claudikins-kernel --marketplace claudikins-marketplace"
        echo "     claude plugins install claudikins-tool-executor --marketplace claudikins-marketplace"
        echo "     claude plugins install claudikins-klaus --marketplace claudikins-marketplace"
        echo "     claude plugins install claudikins-grfp --marketplace claudikins-marketplace"
        echo "     claude plugins install claudikins-automatic-context-manager --marketplace claudikins-marketplace"
        echo "     claude plugins install claude-mem --marketplace thedotmack"
        echo "     claude plugins disable claude-mem@thedotmack"
    fi

    # 7. Generate .zshrc.local from .env (API keys available at shell runtime)
    local zshrc_local="$DOTFILES/zsh/.zshrc.local"
    echo "# Auto-generated from .env — do not commit (gitignored)" > "$zshrc_local"
    [ -n "${GEMINI_API_KEY:-}" ] && echo "export GEMINI_API_KEY='$GEMINI_API_KEY'" >> "$zshrc_local"
    [ -n "${APIFY_TOKEN:-}" ] && echo "export APIFY_TOKEN='$APIFY_TOKEN'" >> "$zshrc_local"
    [ -n "${CLAUDE_BACKUP_DIR:-}" ] && echo "export CLAUDE_BACKUP_DIR='$CLAUDE_BACKUP_DIR'" >> "$zshrc_local"
    echo "   Generated .zshrc.local from .env"

    echo ""
    echo "   Memory system wired:"
    echo "     - SessionStart hook (daily log + knowledge index injection)"
    echo "     - UserPromptSubmit hook (prompt classification)"
    echo "     - Stop hook (session capture on exit)"
    echo "     - PreCompact hook (capture before context compression)"
    echo "     - Overseer MCP server (hybrid search across 1298+ memories)"
    echo ""
    echo "   Manual steps remaining:"
    echo "     1. claude login (Anthropic auth)"
    echo "     2. gh auth login (GitHub auth)"
    if [ -z "${GIT_USER_EMAIL:-}" ]; then
        echo "     3. Set GIT_USER_EMAIL in .env and re-run, or:"
        echo "        git config --global user.email 'your-email'"
    fi
    if [ -z "${GEMINI_API_KEY:-}" ]; then
        echo "     4. Set GEMINI_API_KEY in .env (for Gemini MCP tools)"
    fi
    echo "   Restart Claude Code to activate."
}

# ── Fix SDDM Session ─────────────────────────
fix_sddm_session() {
    echo ""
    echo ":: Fixing Hyprland SDDM session..."
    local session="/usr/share/wayland-sessions/hyprland.desktop"
    if [ -f "$session" ]; then
        if grep -q "Exec=.*start-hyprland" "$session"; then
            echo "   Already using start-hyprland"
        elif grep -qE "Exec=(/usr/bin/)?Hyprland" "$session"; then
            sudo sed -i 's|Exec=.*Hyprland.*|Exec=/usr/bin/start-hyprland|' "$session"
            echo "   Fixed: $session now uses start-hyprland"
        else
            echo "   Unknown Exec line in $session — check manually"
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

    local downloaded=0
    local failed=0
    for i in "${!urls[@]}"; do
        local dest="$wall_dir/${names[$i]}"
        if [ -f "$dest" ] && file "$dest" | grep -q 'image'; then
            continue
        fi
        echo "   Downloading: ${names[$i]}"
        curl -sL "${urls[$i]}" -o "$dest" 2>/dev/null || true
        # Validate it's actually an image (not an HTML error page)
        if [ -f "$dest" ] && ! file "$dest" | grep -q 'image'; then
            rm -f "$dest"
            echo "   FAILED: ${names[$i]} (got HTML instead of image)"
            failed=$((failed + 1))
        else
            downloaded=$((downloaded + 1))
        fi
    done

    local total=$(find "$wall_dir" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | wc -l)
    echo "   Done. $total valid wallpapers."
    [ "$failed" -gt 0 ] && echo "   $failed downloads failed (CDN returned HTML — try again later)"
}

# ── Claude Backup Timer ─────────────────────
setup_claude_backup() {
    local backup_script="$HOME/.config/scripts/claude-backup.sh"
    if [ ! -f "$backup_script" ]; then
        echo ""
        echo ":: No claude-backup.sh found — skipping backup timer."
        return
    fi

    echo ""
    echo ":: Setting up Claude backup timer..."

    mkdir -p "$HOME/.config/systemd/user"

    cat > "$HOME/.config/systemd/user/claude-backup.service" << BSVCEOF
[Unit]
Description=Claude Code environment backup

[Service]
Type=oneshot
ExecStart=$backup_script
Environment=CLAUDE_BACKUP_DIR=%h
BSVCEOF

    cat > "$HOME/.config/systemd/user/claude-backup.timer" << BTMREOF
[Unit]
Description=Daily Claude Code backup

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target
BTMREOF

    systemctl --user daemon-reload
    systemctl --user enable claude-backup.timer 2>/dev/null || true
    systemctl --user start claude-backup.timer 2>/dev/null || true

    echo "   claude-backup.timer enabled (daily)"
}

# ── Services ─────────────────────────────────
enable_services() {
    echo ""
    echo ":: Enabling services..."
    sudo systemctl enable sddm --force 2>/dev/null || true
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl enable bluetooth 2>/dev/null || true
    sudo systemctl enable libvirtd 2>/dev/null || true
    sudo systemctl enable docker 2>/dev/null || true
    sudo usermod -aG docker "$USER" 2>/dev/null || true
}

# ── Run ──────────────────────────────────────
main() {
    # Get sudo upfront and keep it alive throughout
    sudo -v
    while true; do sudo -n true; sleep 55; kill -0 "$$" || exit; done 2>/dev/null &

    # Source .env early — git config, API keys, SMB all read from here
    if [ -f "$DOTFILES/.env" ]; then
        source "$DOTFILES/.env"
        echo ":: Loaded .env"
    else
        echo ":: No .env found — copy .env.example to .env and fill in your values."
        echo "   Some features (SMB mount, git config, API keys) will need manual setup."
    fi

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
    setup_smb
    restore_claude
    setup_claude_backup
    setup_libvirt
    fix_sddm_session
    enable_services
    download_wallpapers

    # Generate initial theme configs from wallust templates
    if ! command -v wallust &>/dev/null; then
        echo ""
        echo "!! WARNING: wallust is not installed — desktop will have NO theming."
        echo "   Install it manually:  $AUR_HELPER -S wallust"
        echo "   Then run:  wallust run ~/Pictures/wallpapers/<any-image>"
    else
        local first_wall=$(find "$HOME/Pictures/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
        if [ -z "$first_wall" ]; then
            echo ""
            echo "!! WARNING: No wallpapers found in ~/Pictures/wallpapers/"
            echo "   Desktop will have NO theming until you add a wallpaper and run:"
            echo "   wallust run ~/Pictures/wallpapers/<any-image>"
        else
            echo ""
            echo ":: Generating initial theme from $first_wall..."
            if wallust run "$first_wall"; then
                echo "   Theme generated successfully."
            else
                echo "!! WARNING: wallust run failed — desktop will have NO theming."
                echo "   Try manually:  wallust run $first_wall"
            fi
        fi
    fi

    # Foot: suppress nerd font monospace warning (idempotent)
    grep -q 'font-monospace-warn' "$DOTFILES/foot/foot.ini" 2>/dev/null || printf '\n[tweak]\nfont-monospace-warn=no\n' >> "$DOTFILES/foot/foot.ini"

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
