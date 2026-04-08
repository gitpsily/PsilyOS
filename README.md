# PsilyOS

An opinionated, handcrafted Arch Linux desktop built on Hyprland. Every config written from scratch. Every line intentional. No bloat, no mystery meat — just a clean, fast, beautiful system you actually understand.

Change your wallpaper and the entire desktop follows. Terminal, bar, launcher, notifications, lock screen, even tmux — all themed dynamically from your wallpaper colors. That's the idea. One image sets the mood for everything.

## What You Get

|                   |                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------- |
| **Compositor**    | Hyprland — tiling Wayland compositor with buttery animations                          |
| **Terminal**      | Ghostty (Kitty as backup)                                                             |
| **Shell**         | Zsh with Starship prompt                                                              |
| **Status Bar**    | Waybar — top bar, workspace indicators, system tray                                   |
| **Launcher**      | Rofi — app launcher, window switcher, clipboard history                               |
| **Notifications** | Mako — minimal, themed, stays out of the way                                          |
| **Lock Screen**   | Hyprlock — blurred screenshot, themed input                                           |
| **Idle**          | Hypridle — dims, locks, sleeps on schedule                                            |
| **Wallpaper**     | swww — smooth animated transitions                                                    |
| **Theming**       | wallust — generates a 16-color palette from your wallpaper and cascades it everywhere |
| **File Manager**  | Thunar (GUI) + yazi (TUI for the terminal heads)                                      |
| **Screenshots**   | grim + slurp — full screen, region, or active window, auto-copied to clipboard        |
| **Clipboard**     | wl-clipboard + cliphist — persistent history, searchable via Rofi                     |
| **Multiplexer**   | tmux — with dev layouts and agent swarm mode                                          |
| **Editor**        | Neovim                                                                                |
| **Browser**       | Chromium                                                                              |
| **Monitor**       | btop                                                                                  |
| **Logout**        | wlogout — lock, logout, suspend, reboot, shutdown                                     |
| **Login**         | SDDM                                                                                  |

## Install

Fresh Arch install. One command. Done.

```bash
git clone https://github.com/gitpsily/PsilyOS.git ~/PsilyOS
cd ~/PsilyOS
chmod +x install.sh
./install.sh
```

The installer will:

- Install an AUR helper (yay) if you don't have one
- Pull all packages from official repos and AUR
- Symlink every config to `~/.config/`
- Set zsh as your default shell
- Enable SDDM, NetworkManager, and Bluetooth
- Create wallpaper and screenshot directories

Reboot. Log in through SDDM. You're in Hyprland. Hit `Super+Shift+W` to pick a wallpaper and watch the whole desktop transform.

## Key Bindings

PsilyOS uses `Super` as the mod key. Vim-style navigation throughout.

### Essentials

| Key                 | Action             |
| ------------------- | ------------------ |
| `Super + Return`    | Open terminal      |
| `Super + Space`     | App launcher       |
| `Super + Q`         | Kill active window |
| `Super + F`         | Fullscreen         |
| `Super + V`         | Toggle floating    |
| `Super + Shift + Q` | Logout menu        |
| `Super + L`         | Lock screen        |

### Navigation

| Key                       | Action                         |
| ------------------------- | ------------------------------ |
| `Super + H/J/K/L`         | Focus left / down / up / right |
| `Super + 1-9`             | Jump to workspace              |
| `Super + Shift + 1-9`     | Move window to workspace       |
| `Super + Shift + H/J/K/L` | Move window                    |
| `Super + Ctrl + H/J/K/L`  | Resize window                  |
| `Super + mouse drag`      | Move or resize with mouse      |

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

**One wallpaper change updates:**

- Hyprland border colors and shadows
- Waybar background, text, and accent colors
- Rofi launcher theme
- Mako notification colors
- Ghostty terminal palette (all 16 colors)
- Hyprlock input field and text
- tmux status bar and pane borders
- wlogout button styling

The templates live in `wallust/templates/`. The generated configs get written to `~/.config/`. If you want to tweak how a color maps to a component, edit the template — not the generated file.

### How It Works

```
wallpaper.sh "~/Pictures/wallpapers/mountain.jpg"
  |
  |-- swww sets the wallpaper (animated transition)
  |-- wallust extracts 16 colors
  |-- wallust renders 8 templates -> 8 config files
  |-- Hyprland reloads
  |-- Waybar reloads
  +-- Mako reloads
```

Everything updates live. No logout required.

## tmux Agent Workflows

PsilyOS includes two tmux layout scripts built for working with AI coding agents.

### Dev Layout — `tdl`

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

### Swarm Layout — `tsl`

N tiled panes, each running the same command. Spin up a grid of agents and watch them work.

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
|   |-- rules.conf              Window rules + opacity
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
|-- tmux/                     Terminal multiplexer (wallust generates this)
|-- wallust/                  Theming engine
|   |-- wallust.toml            Template-to-target mappings
|   +-- templates/              Jinja2 templates (source of truth for theming)
|-- wlogout/                  Logout menu
|   |-- layout                  Button definitions
|   +-- style.css               Styles (wallust generates this)
|-- zsh/                      Shell
|   |-- .zshrc                  Config, aliases, env vars
|   +-- .zprofile               Auto-start Hyprland on tty1
|-- starship/                 Prompt
|   +-- starship.toml           Minimal, informative prompt config
|-- yazi/                     TUI file manager
|-- btop/                     System monitor
|-- scripts/                  Utility scripts
|   |-- wallpaper.sh            Set wallpaper + regenerate all themes
|   |-- screenshot.sh           Capture + clipboard + notification
|   |-- tmux-dev.sh             3-pane dev layout
|   +-- tmux-swarm.sh           N-pane agent grid
|-- install.sh                One-shot installer
+-- README.md
```

## Shell Aliases

PsilyOS sets up a handful of useful aliases in `.zshrc`:

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

## Notes

**VM Testing:** Works out of the box in VMware with a base Arch install. Clone and run the installer — that's it.

**NVIDIA (Baremetal):** When moving to bare metal with NVIDIA, you'll need the appropriate drivers and Hyprland environment variables. That's a separate config layer — PsilyOS keeps the base clean so hardware-specific tweaks don't pollute the main configs.

**Fonts:** JetBrainsMono Nerd Font everywhere. The installer handles it.

**Wallpapers:** Drop images into `~/Pictures/wallpapers/` — jpg, png, or webp. The wallpaper picker uses Rofi so you'll see filenames. Name them something meaningful.

## License

MIT
