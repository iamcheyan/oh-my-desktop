#!/bin/bash
set -eu

# oh-my-desktop setup script.
# Installs dependencies and creates runtime symlinks from ~ into this repo.
# Run after cloning:  git clone ... ~/development/OMD && cd ~/development/OMD && ./Init.sh

REPO="$(cd "$(dirname "$0")" && pwd)"

# ── Color helpers ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Distro detection ──────────────────────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-$DISTRO_ID}"
        DISTRO_NAME="${PRETTY_NAME:-$DISTRO_ID}"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO_ID="arch"
        DISTRO_LIKE="arch"
        DISTRO_NAME="Arch Linux"
    else
        err "Cannot detect distribution. /etc/os-release not found."
        exit 1
    fi

    # Normalize distro family
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|alma)
            DISTRO_FAMILY="rhel"
            ;;
        arch|manjaro|endeavouros|garuda|cachyos|artix)
            DISTRO_FAMILY="arch"
            ;;
        opensuse*|sles)
            DISTRO_FAMILY="suse"
            ;;
        *)
            if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
                DISTRO_FAMILY="debian"
            elif [[ "$DISTRO_LIKE" == *"rhel"* ]] || [[ "$DISTRO_LIKE" == *"fedora"* ]]; then
                DISTRO_FAMILY="rhel"
            elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
                DISTRO_FAMILY="arch"
            else
                DISTRO_FAMILY="unknown"
            fi
            ;;
    esac

    info "Detected: $DISTRO_NAME (family: $DISTRO_FAMILY)"
}

# ── Package definitions ───────────────────────────────────────────────────────
# Core Hyprland ecosystem
PACKAGES_HYPRLAND=(
    hyprland
    hyprlock
    hypridle
    hyprpicker
    xdg-desktop-portal-hyprland
)

# Audio
PACKAGES_AUDIO=(
    pipewire
    pipewire-pulse
    wireplumber
    pamixer
    playerctl
)

# Network
PACKAGES_NETWORK=(
    network-manager
    iwd
)

# Display/brightness
PACKAGES_DISPLAY=(
    brightnessctl
    swaybg
    grim
    slurp
    wl-clipboard
)

# Clipboard
PACKAGES_CLIPBOARD=(
    cliphist
)

# Notification
PACKAGES_NOTIFICATION=(
    mako
)

# Input method
PACKAGES_INPUT=(
    fcitx5
    fcitx5-gtk
    fcitx5-qt
)

# Power/polkit
PACKAGES_POWER=(
    power-profiles-daemon
    polkit-gnome
    gnome-keyring
)

# Terminal
PACKAGES_TERMINAL=(
    foot
)

# Essential tools
PACKAGES_TOOLS=(
    jq
    curl
    git
    python3
    python3-pip
)

# Qt/GTK integration
PACKAGES_QT_GTK=(
    qt6-wayland
    qt5-wayland
    adwaita-qt5
    gnome-themes-extra
    xdg-desktop-portal-gtk
)

# File managers
PACKAGES_FILES=(
    nautilus
    evince
)

# ── Package name mapping ──────────────────────────────────────────────────────
get_debian_pkg() {
    case "$1" in
        hyprland)               echo "hyprland" ;;
        hyprlock)               echo "hyprlock" ;;
        hypridle)               echo "hypridle" ;;
        hyprpicker)             echo "hyprpicker" ;;
        xdg-desktop-portal-hyprland) echo "xdg-desktop-portal-hyprland" ;;
        pipewire)               echo "pipewire" ;;
        pipewire-pulse)         echo "pipewire-pulse" ;;
        wireplumber)            echo "wireplumber" ;;
        pamixer)                echo "pamixer" ;;
        playerctl)              echo "playerctl" ;;
        network-manager)        echo "network-manager" ;;
        iwd)                    echo "iwd" ;;
        brightnessctl)          echo "brightnessctl" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        mako)                   echo "mako" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-frontend-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-frontend-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        foot)                   echo "foot" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        git)                    echo "git" ;;
        python3)                echo "python3" ;;
        python3-pip)            echo "python3-pip" ;;
        qt6-wayland)            echo "qt6-wayland" ;;
        qt5-wayland)            echo "libqt5waylandclient5" ;;
        adwaita-qt5)            echo "adwaita-qt" ;;
        gnome-themes-extra)     echo "gnome-themes-extra" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        nautilus)               echo "nautilus" ;;
        evince)                 echo "evince" ;;
        *)                      echo "$1" ;;
    esac
}

get_fedora_pkg() {
    case "$1" in
        hyprland)               echo "hyprland" ;;
        hyprlock)               echo "hyprlock" ;;
        hypridle)               echo "hypridle" ;;
        hyprpicker)             echo "hyprpicker" ;;
        xdg-desktop-portal-hyprland) echo "xdg-desktop-portal-hyprland" ;;
        pipewire)               echo "pipewire" ;;
        pipewire-pulse)         echo "pipewire-pulseaudio" ;;
        wireplumber)            echo "wireplumber" ;;
        pamixer)                echo "pamixer" ;;
        playerctl)              echo "playerctl" ;;
        network-manager)        echo "NetworkManager" ;;
        iwd)                    echo "iwd" ;;
        brightnessctl)          echo "brightnessctl" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        mako)                   echo "mako" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        foot)                   echo "foot" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        git)                    echo "git" ;;
        python3)                echo "python3" ;;
        python3-pip)            echo "python3-pip" ;;
        qt6-wayland)            echo "qt6-qtwayland" ;;
        qt5-wayland)            echo "qt5-qtwayland" ;;
        adwaita-qt5)            echo "adwaita-qt5" ;;
        gnome-themes-extra)     echo "gnome-themes-extra" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        nautilus)               echo "nautilus" ;;
        evince)                 echo "evince" ;;
        *)                      echo "$1" ;;
    esac
}

get_arch_pkg() {
    # Arch uses the original names
    echo "$1"
}

# ── Package installation ──────────────────────────────────────────────────────
install_packages() {
    local pkg_list=("$@")
    local mapped_pkgs=()

    for pkg in "${pkg_list[@]}"; do
        case "$DISTRO_FAMILY" in
            debian)
                mapped_pkgs+=("$(get_debian_pkg "$pkg")")
                ;;
            rhel)
                mapped_pkgs+=("$(get_fedora_pkg "$pkg")")
                ;;
            arch)
                mapped_pkgs+=("$(get_arch_pkg "$pkg")")
                ;;
            *)
                warn "Unknown distro family, trying package name as-is: $pkg"
                mapped_pkgs+=("$pkg")
                ;;
        esac
    done

    case "$DISTRO_FAMILY" in
        debian)
            info "Installing packages with apt..."
            sudo apt update
            sudo apt install -y "${mapped_pkgs[@]}" || {
                warn "Some packages may not be available. Continuing..."
            }
            ;;
        rhel)
            info "Installing packages with dnf..."
            sudo dnf install -y "${mapped_pkgs[@]}" || {
                warn "Some packages may not be available. Continuing..."
            }
            ;;
        arch)
            info "Installing packages with pacman..."
            sudo pacman -Syu --noconfirm "${mapped_pkgs[@]}" || {
                warn "Some packages may not be available. Continuing..."
            }
            ;;
        *)
            err "Unsupported distro family: $DISTRO_FAMILY"
            err "Please install these packages manually:"
            printf '  %s\n' "${mapped_pkgs[@]}"
            return 1
            ;;
    esac
}

# ── Hyprland PPA/source installation helpers ──────────────────────────────────
setup_hyprland_repo_debian() {
    info "Adding Hyprland repository for Debian/Ubuntu..."
    sudo apt install -y apt-transport-https

    # Add hyprland PPA
    if ! grep -q "hyprland" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        sudo add-apt-repository -y ppa:hyprland/stable || {
            warn "Could not add Hyprland PPA. You may need to add it manually."
            return 1
        }
        sudo apt update
    fi
}

setup_hyprland_repo_rhel() {
    info "Adding Hyprland repository for Fedora..."
    # Fedora typically has Hyprland in repos or COPR
    sudo dnf copr enable -y hyprland/hyprland || {
        warn "Could not add Hyprland COPR. You may need to add it manually."
    }
}

# ── Main installation flow ────────────────────────────────────────────────────
install_all_dependencies() {
    info "Installing core dependencies..."
    echo

    # Hyprland ecosystem
    info "═══ Hyprland Ecosystem ═══"
    case "$DISTRO_FAMILY" in
        debian)
            setup_hyprland_repo_debian || true
            ;;
        rhel)
            setup_hyprland_repo_rhel || true
            ;;
    esac
    install_packages "${PACKAGES_HYPRLAND[@]}"
    echo

    # Audio
    info "═══ Audio System ═══"
    install_packages "${PACKAGES_AUDIO[@]}"
    echo

    # Network
    info "═══ Network ═══"
    install_packages "${PACKAGES_NETWORK[@]}"
    echo

    # Display
    info "═══ Display & Screenshots ═══"
    install_packages "${PACKAGES_DISPLAY[@]}"
    echo

    # Clipboard
    info "═══ Clipboard ═══"
    install_packages "${PACKAGES_CLIPBOARD[@]}"
    echo

    # Notifications
    info "═══ Notifications ═══"
    install_packages "${PACKAGES_NOTIFICATION[@]}"
    echo

    # Input method
    info "═══ Input Method ═══"
    install_packages "${PACKAGES_INPUT[@]}"
    echo

    # Power/Polkit
    info "═══ Power & Authentication ═══"
    install_packages "${PACKAGES_POWER[@]}"
    echo

    # Terminal
    info "═══ Terminal ═══"
    install_packages "${PACKAGES_TERMINAL[@]}"
    echo

    # Essential tools
    info "═══ Essential Tools ═══"
    install_packages "${PACKAGES_TOOLS[@]}"
    echo

    # Qt/GTK
    info "═══ Qt/GTK Integration ═══"
    install_packages "${PACKAGES_QT_GTK[@]}"
    echo

    # File managers
    info "═══ File Managers ═══"
    install_packages "${PACKAGES_FILES[@]}"
    echo

    ok "All dependencies installed!"
}

# ── Symlink creation ──────────────────────────────────────────────────────────
create_symlinks() {
    local LINKS=(
        "$HOME/.config/quickshell|$REPO/quickshell"
        "$HOME/.config/omarchy|$REPO/omarchy"
        "$HOME/.config/walker|$REPO/omarchy/walker"
        "$HOME/.config/foot|$REPO/omarchy/foot"
        "$HOME/.config/kitty|$REPO/omarchy/kitty"
        "$HOME/.config/alacritty|$REPO/omarchy/alacritty"
        "$HOME/.config/ghostty|$REPO/omarchy/ghostty"
        "$HOME/.config/omd|$REPO"
        "$HOME/.local/share/omarchy|$REPO/share"
    )

    local backup_dir=""

    make_backup() {
        local target="$1"
        local stamp
        stamp="$(date +%Y%m%d_%H%M%S)"
        local bak="${target}.bak.${stamp}"

        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  removed existing symlink $target"
        elif [[ -e "$target" ]]; then
            if [[ -z "$backup_dir" ]]; then
                backup_dir="$HOME/.config/omd-backup-${stamp}"
                mkdir -p "$backup_dir"
                echo "Backups will be stored in $backup_dir"
            fi
            mv "$target" "$backup_dir/$(basename "$target")"
            echo "  backed up $target -> $backup_dir/$(basename "$target")"
        fi
    }

    echo
    info "Creating runtime symlinks..."
    echo "Repo: $REPO"
    echo

    for entry in "${LINKS[@]}"; do
        target="${entry%%|*}"
        source="${entry##*|}"

        if [[ ! -e "$source" ]]; then
            err "source $source does not exist"
            exit 1
        fi

        mkdir -p "$(dirname "$target")"

        if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
            ok "  $target (already linked)"
            continue
        fi

        make_backup "$target"
        ln -s "$source" "$target"
        echo "  LINK $target -> $source"
    done

    echo
    echo "Symlinks:"
    for entry in "${LINKS[@]}"; do
        target="${entry%%|*}"
        printf "  %-32s -> %s\n" "$target" "$(readlink "$target")"
    done

    if [[ -n "$backup_dir" ]]; then
        echo
        warn "Pre-existing files backed up to: $backup_dir"
        echo "Review and remove when no longer needed."
    fi
}

# ── Print summary ─────────────────────────────────────────────────────────────
print_summary() {
    echo
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  oh-my-desktop setup complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Next steps:"
    echo "  1. Log out and log back in (for group changes to take effect)"
    echo "  2. Start Hyprland from your display manager"
    echo "  3. Or add to ~/.profile:"
    echo "       if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then"
    echo "         exec Hyprland"
    echo "       fi"
    echo
    echo "Useful commands:"
    echo "  hyprctl reload            # Reload Hyprland config"
    echo "  ~/.config/omd/bin/omd-restart   # (Re)start Quickshell apps"
    echo "  ~/.config/omd/bin/omd-doctor    # Check runtime dependencies"
    echo
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  oh-my-desktop installer${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo

    detect_distro
    echo

    # Ask for confirmation
    echo "This will install the following packages:"
    echo "  - Hyprland ecosystem (compositor, lock, idle, portal)"
    echo "  - Quickshell dependencies"
    echo "  - Audio (PipeWire, WirePlumber)"
    echo "  - Network (NetworkManager, iwd)"
    echo "  - Display tools (brightnessctl, swaybg, grim, slurp)"
    echo "  - Clipboard (cliphist, wl-clipboard)"
    echo "  - Notifications (mako)"
    echo "  - Input method (fcitx5)"
    echo "  - Terminal (foot)"
    echo "  - Essential tools (jq, curl, git)"
    echo "  - Qt/GTK integration"
    echo

    read -p "Proceed with installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    install_all_dependencies
    create_symlinks
    print_summary
}

main "$@"
