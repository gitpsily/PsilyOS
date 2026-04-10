# PsilyOS

An opinionated, handcrafted Arch Linux desktop built on Hyprland. Every config written from scratch. Every line intentional. No bloat, no mystery meat — just a clean, fast, beautiful system you actually understand.

Change your wallpaper and the entire desktop follows. Terminal, bar, launcher, notifications, lock screen, even tmux — all themed dynamically from your wallpaper colors. That's the idea. One image sets the mood for everything.

## What You Get

### Desktop

|                     |                                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| **Compositor**      | Hyprland — tiling Wayland compositor with buttery animations                                   |
| **Terminal**        | Ghostty + Kitty + Foot (fallback for VMs)                                                      |
| **Shell**           | Zsh with Starship prompt                                                                       |
| **Status Bar**      | Waybar — workspace indicators, clock, volume, network, bluetooth, battery, system tray         |
| **Launcher**        | Rofi — app launcher, window switcher, clipboard history, wallpaper picker                      |
| **Notifications**   | Mako — minimal, themed, stays out of the way                                                   |
| **Lock Screen**     | Hyprlock — blurred screenshot, themed input, clock display                                     |
| **Idle**            | Hypridle — dims at 5min, locks at 10min, screen off at 15min                                   |
| **Wallpaper**       | awww — smooth animated transitions, wallust color extraction                                   |
| **Theming**         | wallust — generates a 16-color palette from your wallpaper and cascades it across 8 components |
| **File Manager**    | Thunar (GUI) + yazi (TUI)                                                                      |
| **Screenshots**     | grim + slurp — full screen, region, or active window, auto-copied to clipboard                 |
| **Clipboard**       | wl-clipboard + cliphist — persistent history, searchable via Rofi                              |
| **Multiplexer**     | tmux — with dev layouts and agent swarm mode                                                   |
| **Monitor Manager** | nwg-displays — GUI for multi-monitor setup                                                     |
| **Logout**          | wlogout — lock, logout, suspend, reboot, shutdown                                              |
| **Login**           | SDDM                                                                                           |

### Apps

|                    |                                   |
| ------------------ | --------------------------------- |
| **Editor**         | Neovim                            |
| **Browsers**       | Chromium, Librewolf               |
| **Office**         | LibreOffice                       |
| **Media**          | Plex Desktop                      |
| **Chat**           | Discord                           |
| **Passwords**      | 1Password                         |
| **System Monitor** | btop                              |
| **Dev Tools**      | Claude Code (AI coding assistant) |

### Virtualization

|                |                                  |
| -------------- | -------------------------------- |
| **Hypervisor** | libvirt + QEMU                   |
| **Viewer**     | virt-viewer (with SPICE support) |
| **Networking** | dnsmasq + ebtables               |

### Hardware (bare metal, auto-detected)

|                |                                                                      |
| -------------- | -------------------------------------------------------------------- |
| **NVIDIA**     | Auto-installs drivers, sets Hyprland env vars, configures mkinitcpio |
| **AIO Cooler** | liquidctl with aggressive pump + fan curves via systemd service      |
| **GPU Fans**   | NVIDIA fan control at 80% manual mode                                |
| **Sensors**    | lm_sensors for temperature monitoring                                |

## Install

Fresh Arch install. Clone, fill in your config, run.

```bash
git clone https://github.com/gitpsily/PsilyOS.git ~/PsilyOS
cd ~/PsilyOS

# Optional: set up SMB/NAS mount
cp .env.example .env
nano .env  # fill in your NAS credentials

# Run
chmod +x install.sh
./install.sh
```

The installer handles everything:

- Installs yay (AUR helper) if needed
- Installs all packages from official repos and AUR (one at a time, survives failures)
- Symlinks all configs to `~/.config/`
- Detects VMs and installs guest tools (VMware, KVM, VirtualBox)
- Detects NVIDIA GPUs and configures drivers + Hyprland env vars
- Sets up aggressive cooling profiles (AIO pump, fans, GPU)
- Mounts SMB/NAS shares (if `.env` is configured)
- Fixes SDDM session to use `start-hyprland`
- Installs Claude Code via npm
- Restores Claude Code setup from backup (if found on NAS)
- Enables SDDM, NetworkManager, Bluetooth, libvirtd
- Downloads 10 wallpapers on first install
- Sudo keepalive — asks for your password once

Reboot. Log in through SDDM. You're in Hyprland.

## Key Bindings

`Super` is the mod key. Vim-style navigation throughout.

### Essentials

| Key                 | Action                  |
| ------------------- | ----------------------- |
| `Super + Return`    | Open terminal (Ghostty) |
| `Super + Space`     | App launcher (Rofi)     |
| `Super + Q`         | Kill active window      |
| `Super + F`         | Fullscreen              |
| `Super + V`         | Toggle floating         |
| `Super + Shift + Q` | Logout menu             |
| `Super + L`         | Lock screen             |
| `Super + M`         | Exit Hyprland           |

### Navigation

| Key                       | Action                         |
| ------------------------- | ------------------------------ |
| `Super + H/J/K/L`         | Focus left / down / up / right |
| `Super + 1-9`             | Jump to workspace              |
| `Super + Shift + 1-9`     | Move window to workspace       |
| `Super + Shift + H/J/K/L` | Move window                    |
| `Super + Ctrl + H/J/K/L`  | Resize window                  |
| `Super + mouse drag`      | Move or resize with mouse      |
| `Super + scroll`          | Scroll through workspaces      |

### Tools

| Key                     | Action                             |
| ----------------------- | ---------------------------------- |
| `Super + Shift + W`     | Pick wallpaper (themes everything) |
| `Super + Shift + V`     | Clipboard history                  |
| `Print`                 | Screenshot — full screen           |
| `Super + Print`         | Screenshot — select region         |
| `Super + Shift + Print` | Screenshot — active window         |
| `Super + R`             | Run command                        |
| `Super + Tab`           | Window switcher                    |

## Dynamic Theming

This is the heart of PsilyOS. wallust extracts a color palette from your wallpaper and generates config files for every component through Jinja2 templates.

**One wallpaper change updates 8 configs:**

- Hyprland border colors and shadows
- Waybar background, text, and accent colors
- Rofi launcher theme
- Mako notification colors
- Ghostty terminal palette (all 16 colors)
- Hyprlock input field and text
- tmux status bar and pane borders
- wlogout button styling

The templates live in `wallust/templates/`. The generated configs get written to `~/.config/`. Edit the template, not the generated file.

### How It Works

```
Super+Shift+W  ->  wallpaper.sh
  |
  |-- awww sets the wallpaper (animated transition)
  |-- wallust extracts 16 colors (kmeans, harddark16 palette)
  |-- wallust renders 8 Jinja2 templates -> 8 config files
  |-- hyprctl reload
  |-- waybar reloads
  +-- mako reloads
```

Everything updates live. No logout required.

## tmux Agent Workflows

Two tmux layout scripts for working with AI coding agents.

### Dev Layout -- `tdl`

Three-pane setup: editor on the left, agent pane top-right, shell bottom-right.

```
+----------------+-----------+
|                |  agent    |
|   editor       +-----------+
|                |  shell    |
+----------------+-----------+
```

```bash
tdl              # starts "dev" session in current dir
tdl myproject .  # custom session name + directory
```

### Swarm Layout -- `tsl`

N tiled panes, each running the same command.

```
+------+------+------+
| ag1  | ag2  | ag3  |
+------+------+------+
| ag4  | ag5  | ag6  |
+------+------+------+
```

```bash
tsl 4                 # 4 empty panes
tsl 6 "claude" swarm  # 6 Claude agents in "swarm" session
```

### tmux Bindings

| Key                       | Action                  |
| ------------------------- | ----------------------- |
| `Ctrl+Space`              | Prefix (also `Ctrl+b`)  |
| `Prefix + v`              | Split vertical          |
| `Prefix + h`              | Split horizontal        |
| `Prefix + c`              | New window              |
| `Prefix + k`              | Kill window             |
| `Alt + 1-9`               | Jump to window          |
| `Alt + Left/Right`        | Previous / next window  |
| `Alt + Up/Down`           | Previous / next session |
| `Ctrl+Alt + Arrows`       | Navigate panes          |
| `Ctrl+Alt+Shift + Arrows` | Resize panes            |

## Project Structure

```
PsilyOS/
|-- hypr/                     Hyprland configuration
|   |-- hyprland.conf           Main config (sources everything below)
|   |-- keybinds.conf           All key bindings
|   |-- rules.conf              Window rules
|   |-- theme.conf              Colors (wallust generates this)
|   |-- autostart.conf          Startup daemons
|   |-- hyprlock.conf           Lock screen (wallust generates this)
|   +-- hypridle.conf           Idle timeouts
|-- waybar/                   Status bar
|   |-- config.jsonc            Modules and layout
|   +-- style.css               Styles (wallust generates this)
|-- rofi/                     Application launcher
|   |-- config.rasi             Behavior and settings
|   +-- theme.rasi              Theme (wallust generates this)
|-- mako/                     Notifications (wallust generates this)
|-- ghostty/                  Terminal (wallust generates this)
|-- foot/                     Fallback terminal (VM-friendly)
|-- tmux/                     Terminal multiplexer (wallust generates this)
|-- wallust/                  Theming engine
|   |-- wallust.toml            Template-to-target mappings (v3 format)
|   +-- templates/              8 Jinja2 templates (source of truth for theming)
|-- wlogout/                  Logout menu
|   |-- layout                  Button definitions
|   +-- style.css               Styles (wallust generates this)
|-- zsh/                      Shell config
|   |-- .zshrc                  Aliases, env vars, starship init
|   +-- .zprofile               Auto-start Hyprland on tty1
|-- starship/                 Prompt config
|-- yazi/                     TUI file manager config
|-- btop/                     System monitor config
|-- scripts/                  Utility scripts
|   |-- wallpaper.sh            Set wallpaper + regenerate all themes
|   |-- screenshot.sh           Capture + clipboard + notification
|   |-- tmux-dev.sh             3-pane dev layout (tdl)
|   +-- tmux-swarm.sh           N-pane agent grid (tsl)
|-- .env.example              SMB/NAS mount config template
|-- install.sh                One-shot installer
+-- README.md
```

## Shell Aliases

Set up in `.zshrc`:

| Alias     | Command                               |
| --------- | ------------------------------------- |
| `t`       | Attach to tmux or start a new session |
| `tdl`     | tmux dev layout                       |
| `tsl`     | tmux swarm layout                     |
| `wall`    | Pick a wallpaper                      |
| `shot`    | Take a screenshot                     |
| `v`       | Neovim                                |
| `ll`      | `ls -lah`                             |
| `update`  | `sudo pacman -Syu`                    |
| `cleanup` | Remove orphan packages + clear cache  |

## Hardware Support

The installer auto-detects your environment and configures accordingly. Everything is skipped in VMs.

**NVIDIA GPU:** Installs `nvidia`, `nvidia-utils`, `nvidia-settings`, `lib32-nvidia-utils`. Creates `hypr/nvidia.conf` with Hyprland env vars (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME`, `NVD_BACKEND`). Adds nvidia modules to mkinitcpio and rebuilds initramfs. Disables hardware cursors.

**AIO Cooler:** liquidctl profiles applied at boot via user systemd service. Aggressive curves: pump hits 100% at 45C, fans hit 100% at 45C. Tune the temperature/speed pairs in `scripts/cooling.sh`.

**GPU Fan:** Set to 80% manual mode on NVIDIA GPUs. Adjust in `scripts/cooling.sh`.

**VM Detection:** Auto-installs guest tools for VMware (`open-vm-tools`), KVM/QEMU (`qemu-guest-agent`, `spice-vdagent`), and VirtualBox (`virtualbox-guest-utils`). Sets `WLR_NO_HARDWARE_CURSORS` and `WLR_RENDERER_ALLOW_SOFTWARE` in `/etc/environment` for VMware.

## SMB/NAS Mount

Copy `.env.example` to `.env` and fill in your NAS credentials before running the installer:

```bash
cp .env.example .env
nano .env
```

The installer creates a credentials file at `~/.smbcredentials` (600 permissions), adds an fstab entry with `x-systemd.automount`, and mounts the share. The `.env` and `.smbcredentials` files are gitignored.

## Claude Code Integration

The installer installs Claude Code via npm. If a `claude-backup-*.tar.gz` is found anywhere on the system, the installer offers to restore your Claude Code environment — settings, plugins, memory, session transcripts, skills, and hooks.

Bring your own backup. The restore function handles path remapping if your username changed between machines.

## License

MIT
