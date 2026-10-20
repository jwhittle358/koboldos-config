# koboldos-config

A Sway desktop for Arch Linux, themed in crimson, charcoal, gold and ivory.

| Colour   | Hex       | Used for                          |
|----------|-----------|-----------------------------------|
| Crimson  | `#8B1E24` | Focused windows, borders, selection |
| Charcoal | `#1B1B1B` | Backgrounds                       |
| Gold     | `#C8A24A` | Accents, clock, prompt            |
| Ivory    | `#F5F0E6` | Text                              |

## What's included

| Component | Config | Purpose |
|-----------|--------|---------|
| [Sway](https://swaywm.org/) | `config/sway/config` | Tiling Wayland compositor |
| [Waybar](https://github.com/Alexays/Waybar) | `config/waybar/` | Status bar |
| [wofi](https://hg.sr.ht/~scoopta/wofi) | `config/wofi/` | App launcher |
| [mako](https://github.com/emersion/mako) | `config/mako/config` | Notifications |
| [swaylock](https://github.com/swaywm/swaylock) | `config/swaylock/config` | Lock screen |
| [foot](https://codeberg.org/dnkl/foot) | `config/foot/foot.ini` | Terminal |
| [Starship](https://starship.rs/) | `config/starship.toml` | Shell prompt |
| [greetd](https://sr.ht/~kennylevinsen/greetd/) + [ReGreet](https://github.com/rharish101/ReGreet) | `branding/greetd/` | Login screen (display manager) |
| GTK 3/4 | `config/gtk-*/settings.ini` | Adwaita-dark theme, Papirus icons |

## Install

```sh
git clone https://github.com/<you>/koboldos-config.git
cd koboldos-config
./install.sh
```

Run it as your normal user; it uses `sudo` where needed. By default it:

1. Upgrades the system and installs everything in `packages/pacman.txt`.
2. Installs `packages/aur.txt` if `paru` or `yay` is available.
3. Enables NetworkManager.
4. Installs `wallpapers/crimson-gold.png` if present.
5. Installs the greetd + ReGreet login screen to `/etc/greetd/` and enables
   `greetd.service` (unless another display manager is already enabled).
6. Copies `config/` to `/etc/skel/.config` so new users get it.
7. Copies `config/` to `~/.config`, moving any existing files to
   `~/.config/koboldos-backup-<timestamp>/` first.
8. Adds Starship to `.bashrc`.

### Options

| Flag | Effect |
|------|--------|
| `--no-packages` | Skip package installation |
| `--no-skel` | Don't touch `/etc/skel` |
| `--no-user` | Don't touch your own `~/.config` |
| `--no-dm` | Don't set up the greetd + ReGreet display manager |
| `--wallpaper PATH` | Use a different wallpaper image |
| `-y`, `--yes` | Don't ask for confirmation |

## Keybindings

`Super` is the modifier key.

| Keys | Action |
|------|--------|
| `Super+Enter` | Terminal |
| `Super+D` | App launcher |
| `Super+Shift+F` | File manager |
| `Super+Shift+Q` | Close window |
| `Super+H/J/K/L` or arrows | Move focus |
| `Super+Shift+H/J/K/L` | Move window |
| `Super+1`–`5` | Switch workspace |
| `Super+Shift+1`–`5` | Move window to workspace |
| `Super+F` | Fullscreen |
| `Super+R` | Resize mode |
| `Super+Ctrl+L` | Lock screen |
| `Print` / `Super+Print` | Screenshot (full / region) to `~/Pictures` |
| `Super+Shift+C` | Reload config |
| `Super+Shift+E` | Exit Sway |

## Layout

```
config/        Dotfiles, mirrored into ~/.config
branding/      Boot splash, GRUB theme, swaylock and greetd/ReGreet login screen
packages/      pacman.txt (official repos) and aur.txt
wallpapers/    Optional crimson-gold.png
install.sh     Installer
```
