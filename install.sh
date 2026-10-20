#!/usr/bin/env bash
# KoboldOS Sway desktop — Arch Linux installer
#
# Installs the packages listed in packages/ and deploys the dotfiles in
# config/ to /etc/skel/.config (for future users) and/or the current user's
# ~/.config (existing files are backed up first).
#
# Usage: ./install.sh [options]
#   --no-packages       skip package installation
#   --no-skel           don't install into /etc/skel
#   --no-user           don't install into the current user's home
#   --wallpaper PATH    wallpaper to install (default: wallpapers/crimson-gold.png)
#   -y, --yes           don't prompt for confirmation
#   -h, --help          show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/config"
PACMAN_LIST="$REPO_DIR/packages/pacman.txt"
AUR_LIST="$REPO_DIR/packages/aur.txt"
WALLPAPER_DEST=/usr/share/backgrounds/crimson-gold.png

DO_PACKAGES=1
DO_SKEL=1
DO_USER=1
WALLPAPER=""
ASSUME_YES=0

STARSHIP_INIT='eval "$(starship init bash)"'

info() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# Print the package names in a list file, skipping comments and blank lines.
read_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages) DO_PACKAGES=0 ;;
        --no-skel)     DO_SKEL=0 ;;
        --no-user)     DO_USER=0 ;;
        --wallpaper)   WALLPAPER="${2:?--wallpaper needs a path}"; shift ;;
        -y|--yes)      ASSUME_YES=1 ;;
        -h|--help)     usage ;;
        *)             die "Unknown option: $1 (see --help)" ;;
    esac
    shift
done

if [[ -z "$WALLPAPER" && -f "$REPO_DIR/wallpapers/crimson-gold.png" ]]; then
    WALLPAPER="$REPO_DIR/wallpapers/crimson-gold.png"
fi

[[ $EUID -ne 0 ]] || die "Run as your normal user; sudo is used where needed."
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux."
[[ -d "$CONFIG_SRC" ]] || die "Config source not found: $CONFIG_SRC"
command -v sudo >/dev/null || die "sudo is required."
[[ -z "$WALLPAPER" || -f "$WALLPAPER" ]] || die "Wallpaper not found: $WALLPAPER"

mapfile -t PACKAGES < <(read_list "$PACMAN_LIST")
mapfile -t AUR_PACKAGES < <(read_list "$AUR_LIST")

if [[ $ASSUME_YES -eq 0 ]]; then
    echo "This will:"
    if [[ $DO_PACKAGES -eq 1 ]]; then
        echo "  - upgrade the system and install ${#PACKAGES[@]} packages with pacman"
    fi
    if [[ -n "$WALLPAPER" ]]; then
        echo "  - install the wallpaper to $WALLPAPER_DEST"
    fi
    if [[ $DO_SKEL -eq 1 ]]; then
        echo "  - copy configs into /etc/skel (affects new users only)"
    fi
    if [[ $DO_USER -eq 1 ]]; then
        echo "  - copy configs into $HOME/.config (existing files backed up)"
    fi
    read -rp "Continue? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || exit 0
fi

# --- Packages ---------------------------------------------------------------
if [[ $DO_PACKAGES -eq 1 ]]; then
    info "Installing packages"
    sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

    if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
        AUR_HELPER="$(command -v paru || command -v yay || true)"
        if [[ -n "$AUR_HELPER" ]]; then
            info "Installing AUR packages with ${AUR_HELPER##*/}"
            "$AUR_HELPER" -S --needed --noconfirm "${AUR_PACKAGES[@]}" \
                || warn "AUR package install failed"
        else
            warn "No AUR helper (paru/yay) found; skipping: ${AUR_PACKAGES[*]}"
        fi
    fi

    info "Enabling NetworkManager"
    sudo systemctl enable --now NetworkManager.service
fi

# --- Wallpaper --------------------------------------------------------------
if [[ -n "$WALLPAPER" ]]; then
    info "Installing wallpaper"
    sudo install -Dm644 "$WALLPAPER" "$WALLPAPER_DEST"
fi

# Stage a copy of the configs so we can patch them without touching the repo.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -a "$CONFIG_SRC/." "$STAGE/"

# sway's `bg` fails outright if the image is missing, so fall back to a solid
# colour rather than relying on the trailing colour argument.
if [[ ! -f "$WALLPAPER_DEST" ]]; then
    warn "No wallpaper at $WALLPAPER_DEST; using solid charcoal background"
    sed -i 's|^output \* bg .*|output * bg #1B1B1B solid_color|' "$STAGE/sway/config"
fi

# Verify the polkit agent path the sway config expects.
POLKIT_AGENT=/usr/lib/mate-polkit/polkit-mate-authentication-agent-1
if [[ ! -x "$POLKIT_AGENT" ]]; then
    found="$(pacman -Qlq mate-polkit 2>/dev/null | grep -m1 'authentication-agent-1$' || true)"
    if [[ -n "$found" ]]; then
        sed -i "s|$POLKIT_AGENT|$found|" "$STAGE/sway/config"
    else
        warn "mate-polkit agent not found; auth dialogs won't appear in sway"
    fi
fi

# Fall back to Adwaita-dark when Arc isn't installed.
if [[ ! -d /usr/share/themes/Arc-Dark ]]; then
    warn "Arc-Dark GTK theme not installed; using Adwaita-dark"
    sed -i 's/^gtk-theme-name=.*/gtk-theme-name=Adwaita-dark/' \
        "$STAGE/gtk-3.0/settings.ini" "$STAGE/gtk-4.0/settings.ini"
fi

add_starship_init() {
    local rc="$1" use_sudo="$2"
    if [[ -f "$rc" ]] && grep -qF "$STARSHIP_INIT" "$rc"; then
        return 0
    fi
    if [[ "$use_sudo" -eq 1 ]]; then
        printf '\n%s\n' "$STARSHIP_INIT" | sudo tee -a "$rc" >/dev/null
    else
        printf '\n%s\n' "$STARSHIP_INIT" >> "$rc"
    fi
}

# --- /etc/skel ----------------------------------------------------------------
if [[ $DO_SKEL -eq 1 ]]; then
    info "Installing configs into /etc/skel"
    sudo install -d -m755 /etc/skel/.config /etc/skel/Pictures
    sudo cp -a "$STAGE/." /etc/skel/.config/
    sudo chown -R root:root /etc/skel/.config
    add_starship_init /etc/skel/.bashrc 1
fi

# --- Current user ------------------------------------------------------------
if [[ $DO_USER -eq 1 ]]; then
    info "Installing configs into $HOME/.config"
    BACKUP="$HOME/.config/koboldos-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$HOME/.config" "$HOME/Pictures"
    for src in "$STAGE"/*; do
        name="${src##*/}"
        target="$HOME/.config/$name"
        if [[ -e "$target" ]]; then
            mkdir -p "$BACKUP"
            mv "$target" "$BACKUP/"
        fi
        cp -a "$src" "$target"
    done
    if [[ -d "$BACKUP" ]]; then
        info "Previous configs backed up to $BACKUP"
    fi
    add_starship_init "$HOME/.bashrc" 0
fi

info "Done. Log out and choose 'Sway' in your display manager, or run 'sway' from a TTY."
