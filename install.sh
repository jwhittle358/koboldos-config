#!/usr/bin/env bash
# KoboldOS Sway desktop — Arch Linux installer
#
# Installs the packages listed in packages/ and deploys the dotfiles in
# config/ to /etc/skel/.config (for future users) and/or the current user's
# ~/.config (existing files are backed up first). Also installs the KoboldOS
# GRUB theme and Plymouth splash from branding/ (edited system files are backed
# up once as <file>.koboldos-bak), and sets up greetd + ReGreet as the
# display manager. Neovim gets the LazyVim starter config;
# plugins download on first launch. Prompts for your git user name and email
# and sets them globally.
#
# Usage: ./install.sh [options]
#   --no-packages       skip package installation
#   --no-skel           don't install into /etc/skel
#   --no-user           don't install into the current user's home
#   --no-boot-theme     skip the GRUB theme and Plymouth boot splash
#   --no-dm             don't set up greetd + ReGreet as the display manager
#   --no-lazyvim        don't install the LazyVim Neovim config
#   --no-paru           don't build and install the paru AUR helper
#   --no-git            don't set the global git user name/email
#   --git-name NAME     git user.name to set (skips that prompt)
#   --git-email EMAIL   git user.email to set (skips that prompt)
#   --wallpaper PATH    wallpaper to install (default: wallpapers/crimson-gold.png)
#   -y, --yes           don't prompt for confirmation
#   -h, --help          show this help

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/config"
PACMAN_LIST="$REPO_DIR/packages/pacman.txt"
AUR_LIST="$REPO_DIR/packages/aur.txt"
WALLPAPER_DEST=/usr/share/backgrounds/crimson-gold.png
BRANDING_SRC="$REPO_DIR/branding"
GRUB_THEME_DIR=/boot/grub/themes/koboldos
PLYMOUTH_THEME_DIR=/usr/share/plymouth/themes/koboldos
GREETD_DIR=/etc/greetd
DEJAVU_DIR=/usr/share/fonts/TTF
LAZYVIM_STARTER=https://github.com/LazyVim/starter
PARU_AUR=https://aur.archlinux.org/paru.git

DO_PACKAGES=1
DO_SKEL=1
DO_USER=1
DO_BOOT_THEME=1
DO_DM=1
DO_LAZYVIM=1
DO_PARU=1
DO_GIT=1
GIT_NAME=""
GIT_EMAIL=""
NEED_MKINITCPIO=0
NEED_GRUB_MKCONFIG=0
WALLPAPER=""
ASSUME_YES=0

STARSHIP_INIT='eval "$(starship init bash)"'

info() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# Print the package names in a list file, skipping comments and blank lines.
read_list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

# True if any paru package (paru, paru-bin, paru-git) is installed.
paru_installed() {
    command -v paru >/dev/null || pacman -Qqs '^paru(-bin|-git)?$' &>/dev/null
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-packages) DO_PACKAGES=0 ;;
        --no-skel)     DO_SKEL=0 ;;
        --no-user)     DO_USER=0 ;;
        --no-boot-theme) DO_BOOT_THEME=0 ;;
        --no-dm)       DO_DM=0 ;;
        --no-lazyvim)  DO_LAZYVIM=0 ;;
        --no-paru)     DO_PARU=0 ;;
        --no-git)      DO_GIT=0 ;;
        --git-name)    GIT_NAME="${2:?--git-name needs a name}"; shift ;;
        --git-email)   GIT_EMAIL="${2:?--git-email needs an email}"; shift ;;
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
if [[ $DO_BOOT_THEME -eq 1 && ! -d "$BRANDING_SRC" ]]; then
    warn "Branding assets not found at $BRANDING_SRC; skipping boot theme"
    DO_BOOT_THEME=0
fi
if [[ $DO_DM -eq 1 && ! -d "$BRANDING_SRC/greetd" ]]; then
    warn "greetd config not found at $BRANDING_SRC/greetd; skipping display manager"
    DO_DM=0
fi

mapfile -t PACKAGES < <(read_list "$PACMAN_LIST")
mapfile -t AUR_PACKAGES < <(read_list "$AUR_LIST")

if [[ $ASSUME_YES -eq 0 ]]; then
    echo "This will:"
    if [[ $DO_PACKAGES -eq 1 ]]; then
        echo "  - upgrade the system and install ${#PACKAGES[@]} packages with pacman"
        if [[ $DO_PARU -eq 1 ]] && ! paru_installed; then
            echo "  - build and install the paru AUR helper from $PARU_AUR"
        fi
    fi
    if [[ -n "$WALLPAPER" ]]; then
        echo "  - install the wallpaper to $WALLPAPER_DEST"
    fi
    if [[ $DO_BOOT_THEME -eq 1 ]]; then
        echo "  - install the GRUB theme and Plymouth splash (edits /etc/default/grub,"
        echo "    /etc/mkinitcpio.conf and the kernel command line; backups saved as"
        echo "    <file>.koboldos-bak) and rebuild the initramfs"
    fi
    if [[ $DO_DM -eq 1 ]]; then
        echo "  - install the greetd + ReGreet login screen to $GREETD_DIR and enable"
        echo "    greetd.service (skipped if another display manager is enabled)"
    fi
    if [[ $DO_LAZYVIM -eq 1 ]]; then
        echo "  - set up LazyVim as the Neovim config (clones $LAZYVIM_STARTER)"
    fi
    if [[ $DO_GIT -eq 1 ]]; then
        echo "  - set your global git user name and email (you'll be asked next)"
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

# --- Git identity (asked now, applied at the end once git is installed) -------

# Current global git setting, or empty if unset or git isn't installed yet.
git_current() { git config --global --get "$1" 2>/dev/null || true; }

if [[ $DO_GIT -eq 1 && $ASSUME_YES -eq 0 ]]; then
    if [[ -z "$GIT_NAME" ]]; then
        current="$(git_current user.name)"
        read -rp "Git user name${current:+ [$current]}: " GIT_NAME
    fi
    while [[ -z "$GIT_EMAIL" ]]; do
        current="$(git_current user.email)"
        read -rp "Git email${current:+ [$current]}: " GIT_EMAIL
        # Blank keeps the current value; otherwise insist on something email-like.
        [[ -z "$GIT_EMAIL" || "$GIT_EMAIL" == *@* ]] && break
        warn "That doesn't look like an email address"
        GIT_EMAIL=""
    done
fi

# --- Packages ---------------------------------------------------------------

# Build paru from the AUR with makepkg (needs base-devel and git from pacman.txt).
install_paru() {
    local build rc=0
    if paru_installed; then
        info "paru already installed; skipping"
        return 0
    fi
    info "Building paru from the AUR"
    build="$(mktemp -d)"
    git clone --quiet --depth 1 "$PARU_AUR" "$build/paru" \
        && (cd "$build/paru" && makepkg -si --noconfirm --needed) || rc=1
    rm -rf "$build"
    return $rc
}

if [[ $DO_PACKAGES -eq 1 ]]; then
    info "Installing packages"
    sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

    if [[ $DO_PARU -eq 1 ]]; then
        install_paru || warn "paru install failed"
    fi

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

# Swaylock system default, unless the repo ships its own swaylock config.
if [[ -f "$BRANDING_SRC/swaylock.config" && ! -e "$CONFIG_SRC/swaylock" ]]; then
    info "Installing swaylock defaults"
    if [[ -f "$WALLPAPER_DEST" ]]; then
        sed "s|@WALLPAPER@|$WALLPAPER_DEST|" "$BRANDING_SRC/swaylock.config"
    else
        sed '/^image=/d' "$BRANDING_SRC/swaylock.config"
    fi | sudo install -Dm644 /dev/stdin /etc/swaylock/config
fi

# Save a pristine copy of a root-owned file before the first edit.
backup_once() {
    sudo test -e "$1.koboldos-bak" || sudo cp -a "$1" "$1.koboldos-bak"
}

# --- Display manager (greetd + ReGreet) ----------------------------------------

install_display_manager() {
    local f current
    if ! command -v greetd >/dev/null || ! command -v regreet >/dev/null \
            || ! command -v cage >/dev/null; then
        warn "greetd, greetd-regreet or cage not installed; skipping display manager"
        return 0
    fi

    info "Installing greetd + ReGreet login screen"
    for f in config.toml regreet.toml regreet.css; do
        [[ -f "$GREETD_DIR/$f" ]] && backup_once "$GREETD_DIR/$f"
    done
    sudo install -Dm644 "$BRANDING_SRC/greetd/config.toml" "$GREETD_DIR/config.toml"
    sudo install -Dm644 "$BRANDING_SRC/greetd/regreet.css" "$GREETD_DIR/regreet.css"
    if [[ -f "$WALLPAPER_DEST" ]]; then
        sed "s|@WALLPAPER@|$WALLPAPER_DEST|" "$BRANDING_SRC/greetd/regreet.toml"
    else
        # Drop the [background] section; ReGreet falls back to the CSS colour.
        sed '/^\[background\]/,/^$/d' "$BRANDING_SRC/greetd/regreet.toml"
    fi | sudo install -Dm644 /dev/stdin "$GREETD_DIR/regreet.toml"

    # Only one unit can own display-manager.service; don't fight an existing one.
    current="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    current="${current##*/}"
    if [[ -n "$current" && "$current" != greetd.service ]]; then
        warn "$current is already the display manager; to switch, run:"
        warn "  sudo systemctl disable $current && sudo systemctl enable greetd.service"
        return 0
    fi
    # Not --now: starting greetd on VT1 would clash with a running session.
    sudo systemctl enable greetd.service
}

if [[ $DO_DM -eq 1 ]]; then
    install_display_manager
fi

# --- Boot theme (GRUB + Plymouth) ---------------------------------------------

# True if a file's first matching line already contains the word `splash`.
has_splash() { sudo grep -qE "$2.*(^|[[:space:]\"])splash([[:space:]\"]|\$)" "$1"; }

grub_in_use() {
    [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null \
        && sudo test -f /boot/grub/grub.cfg
}

# Set KEY=VALUE in /etc/default/grub, uncommenting the key if needed.
set_grub_var() {
    local key="$1" val="$2"
    if grep -qE "^#?[[:space:]]*${key}=" /etc/default/grub; then
        sudo sed -i -E "s|^#?[[:space:]]*${key}=.*|${key}=${val}|" /etc/default/grub
    else
        printf '%s=%s\n' "$key" "$val" | sudo tee -a /etc/default/grub >/dev/null
    fi
}

install_grub_theme() {
    if ! grub_in_use; then
        info "GRUB not in use; skipping GRUB theme"
        return 0
    fi
    if ! command -v grub-mkfont >/dev/null || [[ ! -f "$DEJAVU_DIR/DejaVuSans.ttf" ]]; then
        warn "grub-mkfont or ttf-dejavu missing; skipping GRUB theme"
        return 0
    fi

    info "Installing GRUB theme"
    sudo install -d "$GRUB_THEME_DIR"
    sudo install -m644 "$BRANDING_SRC/grub/themes/koboldos/theme.txt" \
        "$BRANDING_SRC/grub/themes/koboldos/background.png" "$GRUB_THEME_DIR/"
    # GRUB only reads .pf2; the names embedded here must match theme.txt.
    sudo grub-mkfont -s 16 -o "$GRUB_THEME_DIR/dejavu_sans_16.pf2" "$DEJAVU_DIR/DejaVuSans.ttf"
    sudo grub-mkfont -s 20 -o "$GRUB_THEME_DIR/dejavu_sans_20.pf2" "$DEJAVU_DIR/DejaVuSans.ttf"
    sudo grub-mkfont -s 20 -o "$GRUB_THEME_DIR/dejavu_sans_bold_20.pf2" "$DEJAVU_DIR/DejaVuSans-Bold.ttf"
    sudo grub-mkfont -s 16 -o "$GRUB_THEME_DIR/dejavu_mono_16.pf2" "$DEJAVU_DIR/DejaVuSansMono.ttf"

    backup_once /etc/default/grub
    set_grub_var GRUB_THEME "\"$GRUB_THEME_DIR/theme.txt\""
    # Fall back to auto if the firmware doesn't offer 3440x1440.
    set_grub_var GRUB_GFXMODE 3440x1440,auto
    if grep -qE '^GRUB_TERMINAL(_OUTPUT)?=.*console' /etc/default/grub; then
        warn "GRUB_TERMINAL[_OUTPUT]=console is set in /etc/default/grub; the theme won't show until it's commented out"
    fi
    NEED_GRUB_MKCONFIG=1
}

# Insert the plymouth hook after systemd/udev and before (sd-)encrypt.
add_plymouth_hook() {
    local conf=/etc/mkinitcpio.conf
    if grep -qsE '^HOOKS=' /etc/mkinitcpio.conf.d/*.conf; then
        warn "HOOKS is overridden in /etc/mkinitcpio.conf.d; add 'plymouth' there (after systemd/udev, before encrypt/sd-encrypt)"
        return 1
    fi
    grep -qE '^HOOKS=\(.*\bplymouth\b' "$conf" && return 0

    backup_once "$conf"
    if grep -qE '^HOOKS=\(.*[ (](sd-)?encrypt\b' "$conf"; then
        sudo sed -i -E '/^HOOKS=\(/s/([ (])((sd-)?encrypt)\b/\1plymouth \2/' "$conf"
    elif grep -qE '^HOOKS=\(.*\b(systemd|udev)\b' "$conf"; then
        sudo sed -i -E '/^HOOKS=\(/s/\b(systemd|udev)\b/\1 plymouth/' "$conf"
    fi
    if ! grep -qE '^HOOKS=\(.*\bplymouth\b' "$conf"; then
        warn "Couldn't place the plymouth hook in $conf; add it yourself"
        return 1
    fi
}

# Add `splash` wherever this machine keeps its kernel command line.
add_splash() {
    local found=0 f boot

    if grub_in_use; then
        found=1
        if ! has_splash /etc/default/grub '^GRUB_CMDLINE_LINUX_DEFAULT='; then
            backup_once /etc/default/grub
            sudo sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/' /etc/default/grub
            NEED_GRUB_MKCONFIG=1
            has_splash /etc/default/grub '^GRUB_CMDLINE_LINUX_DEFAULT=' \
                || warn "Couldn't add 'splash' to GRUB_CMDLINE_LINUX_DEFAULT; add it yourself"
        fi
    fi

    # systemd-boot entries (the ESP is usually root-only, hence sudo).
    boot="$(sudo bootctl -x 2>/dev/null || true)"
    if [[ -n "$boot" ]] && sudo test -d "$boot/loader/entries"; then
        while IFS= read -r -d '' f; do
            found=1
            has_splash "$f" '^options[[:space:]]' && continue
            backup_once "$f"
            sudo sed -i -E '/^options[[:space:]]/s/$/ splash/' "$f"
        done < <(sudo find "$boot/loader/entries" -maxdepth 1 -name '*.conf' -print0)
    fi

    # Unified kernel images built by mkinitcpio.
    if [[ -f /etc/kernel/cmdline ]]; then
        found=1
        if ! has_splash /etc/kernel/cmdline '^'; then
            backup_once /etc/kernel/cmdline
            sudo sed -i -E '1s/[[:space:]]*$/ splash/' /etc/kernel/cmdline
        fi
    fi

    [[ $found -eq 1 ]] || warn "Couldn't find the kernel command line; add 'splash' to it yourself"
}

install_plymouth_theme() {
    if ! command -v plymouth-set-default-theme >/dev/null; then
        warn "plymouth not installed; skipping boot splash"
        return 0
    fi
    info "Installing Plymouth theme"
    sudo install -d "$PLYMOUTH_THEME_DIR"
    sudo install -m644 "$BRANDING_SRC"/plymouth/koboldos/* "$PLYMOUTH_THEME_DIR/"
    sudo plymouth-set-default-theme koboldos
    add_plymouth_hook || true
    add_splash
    NEED_MKINITCPIO=1
}

if [[ $DO_BOOT_THEME -eq 1 ]]; then
    install_grub_theme
    install_plymouth_theme
    # mkinitcpio first so rebuilt UKIs pick up the new cmdline.
    if [[ $NEED_MKINITCPIO -eq 1 ]]; then
        info "Rebuilding initramfs"
        sudo mkinitcpio -P
    fi
    if [[ $NEED_GRUB_MKCONFIG -eq 1 ]]; then
        info "Regenerating GRUB config"
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
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

# LazyVim: stage the starter as the nvim config, with the repo's config/nvim
# (KoboldOS colorscheme etc.) layered on top. Those files are LazyVim plugin
# specs, so without the starter there's nothing to deploy.
if [[ $DO_LAZYVIM -eq 1 ]]; then
    info "Fetching LazyVim starter"
    if ! command -v git >/dev/null; then
        warn "git not installed; skipping LazyVim"
        rm -rf "$STAGE/nvim"
    elif git clone --quiet --depth 1 "$LAZYVIM_STARTER" "$STAGE/nvim.starter"; then
        rm -rf "$STAGE/nvim.starter/.git"
        if [[ -d "$STAGE/nvim" ]]; then
            cp -a "$STAGE/nvim/." "$STAGE/nvim.starter/"
            rm -rf "$STAGE/nvim"
        fi
        mv "$STAGE/nvim.starter" "$STAGE/nvim"
    else
        warn "Couldn't clone $LAZYVIM_STARTER; skipping LazyVim"
        rm -rf "$STAGE/nvim" "$STAGE/nvim.starter"
    fi
else
    rm -rf "$STAGE/nvim"
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
        # A non-LazyVim nvim config leaves plugins/state that would clash, so
        # back those up alongside it.
        if [[ "$name" == nvim && -e "$target" ]] \
                && ! grep -qs LazyVim "$target/lua/config/lazy.lua"; then
            for d in "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
                [[ -e "$d" ]] || continue
                dest="$BACKUP/nvim-data/${d#"$HOME"/}"
                mkdir -p "${dest%/*}"
                mv "$d" "$dest"
            done
        fi
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

# --- Git identity -------------------------------------------------------------
if [[ $DO_GIT -eq 1 && ( -n "$GIT_NAME" || -n "$GIT_EMAIL" ) ]]; then
    if command -v git >/dev/null; then
        info "Setting git identity"
        [[ -z "$GIT_NAME" ]] || git config --global user.name "$GIT_NAME"
        [[ -z "$GIT_EMAIL" ]] || git config --global user.email "$GIT_EMAIL"
    else
        warn "git not installed; skipping git user name/email"
    fi
fi

info "Done. Reboot to the KoboldOS login screen and pick 'Sway', or run 'sway' from a TTY."
