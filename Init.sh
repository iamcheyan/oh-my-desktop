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
    pipewire-alsa
    pipewire-utils
    wireplumber
    pamixer
    playerctl
    pavucontrol
)

# Network
PACKAGES_NETWORK=(
    network-manager
    network-manager-wifi
    iwd
    blueman
)

# Display/brightness
PACKAGES_DISPLAY=(
    brightnessctl
    swaybg
    grim
    slurp
    swappy
    wl-clipboard
)

# Clipboard
PACKAGES_CLIPBOARD=(
    cliphist
    walker
)

# Notification
PACKAGES_NOTIFICATION=(
    mako
)

# Quickshell runtime
PACKAGES_QUICKSHELL=(
    quickshell
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
    kitty
)

# Essential tools
PACKAGES_TOOLS=(
    jq
    curl
    git
    ripgrep
    fish
    fontconfig
    unzip
    python3
    python3-pip
    ydotool
)

# Fonts used by Quickshell, Walker, terminals, and MaterialSymbol widgets
PACKAGES_FONTS=(
    cantarell-fonts
    noto-fonts
    noto-cjk-fonts
    noto-emoji-fonts
    jetbrains-mono-nerd-fonts
    meslo-nerd-fonts
    material-symbols-fonts
    font-awesome
)

# Fedora-specific nerd font packages (cascadia provides nerd symbols)
PACKAGES_FONTS_FEDORA=(
    cascadia-code-nf-fonts
    cascadia-mono-nf-fonts
)

# Qt/GTK integration
PACKAGES_QT_GTK=(
    qt6-wayland
    qt5-wayland
    adwaita-qt5
    gnome-themes-extra
    xdg-desktop-portal-gtk
    kdialog
    zenity
    qt6ct
    kvantum
)

# File managers
PACKAGES_FILES=(
    nautilus
    evince
    plasma-systemmonitor
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
        pipewire-alsa)          echo "pipewire-alsa" ;;
        pipewire-utils)         echo "pipewire-bin" ;;
        wireplumber)            echo "wireplumber" ;;
        pamixer)                echo "pamixer" ;;
        playerctl)              echo "playerctl" ;;
        pavucontrol)            echo "pavucontrol" ;;
        network-manager)        echo "network-manager" ;;
        network-manager-wifi)   echo "network-manager" ;;
        iwd)                    echo "iwd" ;;
        blueman)                echo "blueman" ;;
        brightnessctl)          echo "brightnessctl" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        swappy)                 echo "swappy" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        walker)                 echo "walker" ;;
        mako)                   echo "mako" ;;
        quickshell)             echo "quickshell" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-frontend-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-frontend-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        foot)                   echo "foot" ;;
        kitty)                  echo "kitty" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        git)                    echo "git" ;;
        ripgrep)                echo "ripgrep" ;;
        fish)                   echo "fish" ;;
        fontconfig)             echo "fontconfig" ;;
        unzip)                  echo "unzip" ;;
        python3)                echo "python3" ;;
        python3-pip)            echo "python3-pip" ;;
        ydotool)                echo "ydotool" ;;
        cantarell-fonts)        echo "fonts-cantarell" ;;
        noto-fonts)             echo "fonts-noto-core" ;;
        noto-cjk-fonts)         echo "fonts-noto-cjk" ;;
        noto-emoji-fonts)       echo "fonts-noto-color-emoji" ;;
        jetbrains-mono-nerd-fonts) echo "fonts-jetbrains-mono" ;;
        meslo-nerd-fonts)       echo "fonts-meslo" ;;
        material-symbols-fonts) echo "fonts-material-design-icons-iconfont" ;;
        font-awesome)           echo "fonts-font-awesome" ;;
        qt6-wayland)            echo "qt6-wayland" ;;
        qt5-wayland)            echo "libqt5waylandclient5" ;;
        adwaita-qt5)            echo "adwaita-qt" ;;
        gnome-themes-extra)     echo "gnome-themes-extra" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        kdialog)                echo "kdialog" ;;
        zenity)                 echo "zenity" ;;
        qt6ct)                  echo "qt6ct" ;;
        kvantum)                echo "qt5-style-kvantum" ;;
        nautilus)               echo "nautilus" ;;
        evince)                 echo "evince" ;;
        plasma-systemmonitor)   echo "plasma-systemmonitor" ;;
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
        pipewire-alsa)          echo "pipewire-alsa" ;;
        pipewire-utils)         echo "pipewire-utils" ;;
        wireplumber)            echo "wireplumber" ;;
        pamixer)                echo "pamixer" ;;
        playerctl)              echo "playerctl" ;;
        pavucontrol)            echo "pavucontrol" ;;
        network-manager)        echo "NetworkManager" ;;
        network-manager-wifi)   echo "NetworkManager-wifi" ;;
        iwd)                    echo "iwd" ;;
        blueman)                echo "blueman" ;;
        brightnessctl)          echo "brightnessctl" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        swappy)                 echo "swappy" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        walker)                 echo "walker" ;;
        mako)                   echo "mako" ;;
        quickshell)             echo "quickshell" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        foot)                   echo "foot" ;;
        kitty)                  echo "kitty" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        git)                    echo "git" ;;
        ripgrep)                echo "ripgrep" ;;
        fish)                   echo "fish" ;;
        fontconfig)             echo "fontconfig" ;;
        unzip)                  echo "unzip" ;;
        python3)                echo "python3" ;;
        python3-pip)            echo "python3-pip" ;;
        ydotool)                echo "ydotool" ;;
        cantarell-fonts)        echo "abattis-cantarell-vf-fonts" ;;
        noto-fonts)             echo "google-noto-sans-vf-fonts" ;;
        noto-cjk-fonts)         echo "google-noto-sans-cjk-vf-fonts" ;;
        noto-emoji-fonts)       echo "google-noto-color-emoji-fonts" ;;
        jetbrains-mono-nerd-fonts) echo "jetbrains-mono-fonts-all" ;;
        meslo-nerd-fonts)       echo "meslo-nerd-fonts" ;; # not in Fedora repos; handled by install_user_fonts fallback
        material-symbols-fonts) echo "material-symbols-fonts" ;; # not in Fedora repos; handled by install_user_fonts fallback
        font-awesome)           echo "fontawesome-6-free-fonts" ;;
        qt6-wayland)            echo "qt6-qtwayland" ;;
        qt5-wayland)            echo "qt5-qtwayland" ;;
        adwaita-qt5)            echo "adwaita-qt5" ;;
        gnome-themes-extra)     echo "gnome-themes-extra" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        kdialog)                echo "kdialog" ;;
        zenity)                 echo "zenity" ;;
        qt6ct)                  echo "qt6ct" ;;
        kvantum)                echo "kvantum" ;;
        nautilus)               echo "nautilus" ;;
        evince)                 echo "evince" ;;
        plasma-systemmonitor)   echo "plasma-systemmonitor" ;;
        *)                      echo "$1" ;;
    esac
}

get_arch_pkg() {
    case "$1" in
        network-manager)        echo "networkmanager" ;;
        network-manager-wifi)   echo "networkmanager" ;;
        cantarell-fonts)        echo "cantarell-fonts" ;;
        noto-fonts)             echo "noto-fonts" ;;
        noto-cjk-fonts)         echo "noto-fonts-cjk" ;;
        noto-emoji-fonts)       echo "noto-fonts-emoji" ;;
        jetbrains-mono-nerd-fonts) echo "ttf-jetbrains-mono-nerd" ;;
        meslo-nerd-fonts)       echo "ttf-meslo-nerd" ;;
        material-symbols-fonts) echo "ttf-material-symbols-variable-git" ;;
        font-awesome)           echo "ttf-font-awesome" ;;
        walker)                 echo "omarchy-walker" ;;
        kvantum)                echo "kvantum-qt5" ;;
        *)                      echo "$1" ;;
    esac
}

# ── Package installation ──────────────────────────────────────────────────────
install_packages() {
    local pkg_list=("$@")
    local mapped_pkgs=()
    local pkg

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

    mapfile -t mapped_pkgs < <(printf '%s\n' "${mapped_pkgs[@]}" | awk 'NF && !seen[$0]++')
    ((${#mapped_pkgs[@]})) || return 0

    retry_packages_individually() {
        local failed=0
        local single

        warn "Retrying package installation one package at a time..."
        for single in "${mapped_pkgs[@]}"; do
            case "$DISTRO_FAMILY" in
                debian)
                    sudo apt install -y "$single" || failed=1
                    ;;
                rhel)
                    sudo dnf install -y --skip-unavailable "$single" || failed=1
                    ;;
                arch)
                    sudo pacman -S --noconfirm --needed "$single" || failed=1
                    ;;
            esac
        done

        if ((failed)); then
            warn "Some packages were unavailable. Continuing; run bin/omd-doctor afterward for exact gaps."
        fi
    }

    case "$DISTRO_FAMILY" in
        debian)
            info "Installing packages with apt..."
            sudo apt update
            sudo apt install -y "${mapped_pkgs[@]}" || {
                retry_packages_individually
            }
            ;;
        rhel)
            info "Installing packages with dnf..."
            sudo dnf install -y --skip-unavailable "${mapped_pkgs[@]}" || {
                retry_packages_individually
            }
            ;;
        arch)
            info "Installing packages with pacman..."
            sudo pacman -Syu --noconfirm --needed "${mapped_pkgs[@]}" || {
                retry_packages_individually
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
    # Fedora 43 does not ship the Hyprland compositor in the official repos.
    # This COPR provides Fedora 43 builds with vendored Hyprland libraries.
    sudo dnf copr enable -y ashbuk/Hyprland-Fedora || {
        warn "Could not add Hyprland COPR. You may need to add it manually."
    }
}

setup_quickshell_repo_rhel() {
    info "Adding Quickshell repository for Fedora..."
    sudo dnf copr enable -y errornointernet/quickshell || {
        warn "Could not add Quickshell COPR. You may need to add it manually."
    }
}

# ── User font fallback installation ───────────────────────────────────────────
font_family_resolves() {
    local family="$1"

    command -v fc-match >/dev/null 2>&1 || return 1
    [[ "$(fc-match -f '%{family[0]}' "$family" 2>/dev/null)" == "$family" ]]
}

install_nerd_font_zip() {
    local family="$1"
    local url="$2"
    local dest="$HOME/.local/share/fonts/omd/$family"
    local tmp_zip="/tmp/omd-${family// /-}.zip"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/omd..."
    mkdir -p "$dest"
    if curl -fL "$url" -o "$tmp_zip"; then
        unzip -o "$tmp_zip" '*.ttf' -d "$dest" >/dev/null || warn "Could not extract $family"
        rm -f "$tmp_zip"
    else
        warn "Could not download $family"
        return 1
    fi
}

install_material_symbols_font() {
    local family="Material Symbols Rounded"
    local dest="$HOME/.local/share/fonts/omd/material-symbols"
    local file="$dest/MaterialSymbolsRounded.ttf"
    local url="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/omd..."
    mkdir -p "$dest"
    curl -fL "$url" -o "$file" || {
        warn "Could not download $family"
        return 1
    }
}

install_symbols_nerd_font() {
    local family="Symbols Nerd Font"
    local dest="$HOME/.local/share/fonts/omd/symbols-nerd"
    local tmp_zip="/tmp/omd-symbols-nerd.zip"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/omd..."
    mkdir -p "$dest"
    if curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" -o "$tmp_zip"; then
        unzip -o "$tmp_zip" '*.ttf' -d "$dest" >/dev/null || warn "Could not extract $family"
        rm -f "$tmp_zip"
    else
        warn "Could not download $family"
        return 1
    fi
}

install_ia_writer_font() {
    local family="iA Writer Mono S"
    local dest="$HOME/.local/share/fonts/omd/ia-writer"
    local tmp_zip="/tmp/omd-ia-writer.zip"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/omd..."
    mkdir -p "$dest"
    if curl -fL "https://github.com/iaolo/iA-Fonts/archive/refs/heads/master.zip" -o "$tmp_zip"; then
        unzip -o "$tmp_zip" 'iA-Fonts-master/iA Writer Mono/Static/*.ttf' -d "$dest" >/dev/null 2>&1 || {
            # fallback: try underscore variant
            unzip -o "$tmp_zip" 'iA-Fonts-master/iA_Writer_Mono/Static/*.ttf' -d "$dest" >/dev/null 2>&1 || {
                # fallback: try extracting all ttf
                unzip -o "$tmp_zip" '*.ttf' -d "$dest" >/dev/null 2>&1 || warn "Could not extract $family"
            }
        }
        # move fonts out of nested dirs
        find "$dest" -name '*.ttf' -exec mv -t "$dest" {} + 2>/dev/null || true
        rm -rf "$dest"/iA-Fonts-master 2>/dev/null || true
        rm -f "$tmp_zip"
    else
        warn "Could not download $family"
        return 1
    fi
}

install_user_fonts() {
    info "Checking OMD UI fonts..."

    install_nerd_font_zip "JetBrainsMono Nerd Font Mono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || true
    install_nerd_font_zip "MesloLGS Nerd Font Mono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" || true
    install_material_symbols_font || true
    install_symbols_nerd_font || true
    install_ia_writer_font || true

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts/omd" >/dev/null 2>&1 || true
    fi

    for family in "Cantarell" "Noto Color Emoji" "JetBrainsMono Nerd Font Mono" "MesloLGS Nerd Font Mono" "Material Symbols Rounded" "Symbols Nerd Font" "iA Writer Mono S"; do
        if font_family_resolves "$family"; then
            ok "  font available: $family"
        else
            warn "font still missing or falling back: $family"
        fi
    done
}

# ── User binary fallback installation ─────────────────────────────────────────
# Some OMD dependencies are not packaged for every distro (notably walker and
# elephant on Fedora). Download prebuilt binaries from upstream releases into
# ~/.local/bin so OMD can still run end-to-end.
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) err "Unsupported architecture: $arch"; return 1 ;;
    esac
}

install_github_release_binary() {
    local repo="$1"          # e.g. "abenz1267/walker"
    local asset_glob="$2"    # e.g. "walker-*-x86_64-unknown-linux-gnu.tar.gz"
    local binary_name="$3"   # e.g. "walker"
    local bin_dir="$HOME/.local/bin"
    local tmp_dir

    if command -v "$binary_name" >/dev/null 2>&1; then
        ok "  $binary_name"
        return 0
    fi

    info "Fetching $binary_name from $repo..."
    tmp_dir="$(mktemp -d)"
    if ! curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
            | jq -r --arg glob "$asset_glob" '.assets[] | select(.name | test($glob)) | .browser_download_url' \
            | head -n1 > "$tmp_dir/url"; then
        warn "Could not query releases for $repo"
        rm -rf "$tmp_dir"
        return 1
    fi

    local url
    url="$(cat "$tmp_dir/url")"
    if [[ -z "$url" ]]; then
        warn "No matching release asset for $binary_name"
        rm -rf "$tmp_dir"
        return 1
    fi

    mkdir -p "$bin_dir"
    if [[ "$url" == *.tar.gz || "$url" == *.tgz ]]; then
        if curl -fL "$url" | tar -xz -C "$tmp_dir" 2>/dev/null; then
            if [[ -x "$tmp_dir/$binary_name" ]]; then
                install -m 0755 "$tmp_dir/$binary_name" "$bin_dir/$binary_name"
            else
                local found
                found="$(find "$tmp_dir" -name "$binary_name" -type f -executable | head -n1)"
                if [[ -n "$found" ]]; then
                    install -m 0755 "$found" "$bin_dir/$binary_name"
                else
                    warn "Could not locate $binary_name in archive"
                    rm -rf "$tmp_dir"
                    return 1
                fi
            fi
        else
            warn "Could not download $url"
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        if curl -fL "$url" -o "$bin_dir/$binary_name"; then
            chmod +x "$bin_dir/$binary_name"
        else
            warn "Could not download $url"
            rm -rf "$tmp_dir"
            return 1
        fi
    fi
    rm -rf "$tmp_dir"
    ok "  installed $binary_name -> $bin_dir/$binary_name"
}

install_user_binaries() {
    info "Checking OMD user binaries (walker, elephant, providers)..."

    local arch
    arch="$(detect_arch)" || return 0

    # Walker launcher (Rust)
    install_github_release_binary "abenz1267/walker" \
        "walker-.*-${arch}-unknown-linux-gnu\.tar\.gz$" "walker" || true

    # Elephant provider daemon (Rust). Upstream ships linux-amd64/linux-arm64
    # tarballs, not arch-named files, so translate.
    local elephant_arch
    case "$arch" in
        x86_64)  elephant_arch="amd64" ;;
        aarch64) elephant_arch="arm64" ;;
    esac
    install_github_release_binary "abenz1267/elephant" \
        "^elephant-linux-${elephant_arch}\.tar\.gz$" "elephant" || true

    # Required providers used by ~/.config/walker/config.toml.
    # We only install the ones referenced in the OMD walker config so we don't
    # pull down every upstream provider.
    local providers=(
        "calc"
        "clipboard"
        "desktopapplications"
        "files"
        "providerlist"
        "symbols"
        "websearch"
    )
    local p
    for p in "${providers[@]}"; do
        install_github_release_binary "abenz1267/elephant" \
            "^${p}-linux-${elephant_arch}\.tar\.gz$" "elephant-${p}" || true
    done

    for bin in walker elephant elephant-desktopapplications elephant-providerlist elephant-files elephant-symbols elephant-calc elephant-websearch elephant-clipboard; do
        if command -v "$bin" >/dev/null 2>&1; then
            ok "  binary available: $bin"
        else
            warn "binary still missing: $bin"
        fi
    done
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

    # Quickshell
    info "═══ Quickshell ═══"
    case "$DISTRO_FAMILY" in
        rhel)
            setup_quickshell_repo_rhel || true
            ;;
    esac
    install_packages "${PACKAGES_QUICKSHELL[@]}"
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

    # Fonts
    info "═══ Fonts & Icons ═══"
    install_packages "${PACKAGES_FONTS[@]}"
    if [[ "$DISTRO_FAMILY" == "rhel" ]]; then
        install_packages "${PACKAGES_FONTS_FEDORA[@]}"
    fi
    install_user_fonts
    echo

    # User binaries (walker, elephant, providers)
    info "═══ User Binaries (walker, elephant) ═══"
    install_user_binaries
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
        "$HOME/.config/walker|$REPO/config/walker"
        "$HOME/.config/foot|$REPO/config/foot"
        "$HOME/.config/kitty|$REPO/config/kitty"
        "$HOME/.config/alacritty|$REPO/config/alacritty"
        "$HOME/.config/ghostty|$REPO/config/ghostty"
        "$HOME/.config/omd|$REPO"
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

# ── Session registration ──────────────────────────────────────────────────────
install_session_files() {
    echo
    info "Installing GDM/Wayland session entry..."

    mkdir -p "$HOME/.local/bin"
    cat >"$HOME/.local/bin/uwsm-app" <<'EOF'
#!/bin/bash
set -e

if [[ ${OMD_FORCE_NO_UWSM:-0} == 1 ]]; then
    [[ ${1:-} == -- ]] && shift
    exec "$@"
fi

if command -v uwsm >/dev/null 2>&1; then
    exec uwsm app -- "$@"
fi

[[ ${1:-} == -- ]] && shift
exec "$@"
EOF
    chmod +x "$HOME/.local/bin/uwsm-app"
    ok "  $HOME/.local/bin/uwsm-app"

    sudo tee /usr/local/bin/omd-hyprland-session >/dev/null <<'EOF'
#!/bin/bash
set -e

export OMD_ROOT="${HOME}/.config/omd"
export OMD_FORCE_NO_UWSM=1
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=oh-my-desktop
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland,x11
export MOZ_ENABLE_WAYLAND=1
export PATH="${HOME}/.local/bin:${OMD_ROOT}/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

config="${OMD_ROOT}/hypr/hyprland.lua"

if [[ ! -f "$config" ]]; then
    echo "OMD Hyprland config not found: $config" >&2
    exit 1
fi

if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland -- -c "$config"
fi

if command -v Hyprland >/dev/null 2>&1; then
    exec Hyprland -c "$config"
fi

if command -v hyprland >/dev/null 2>&1; then
    exec hyprland -c "$config"
fi

echo "Hyprland is not installed or not in PATH." >&2
exit 127
EOF
    sudo chmod +x /usr/local/bin/omd-hyprland-session
    ok "  /usr/local/bin/omd-hyprland-session"

    sudo tee /usr/share/wayland-sessions/oh-my-desktop.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Oh My Desktop
Comment=OMD Hyprland session with Quickshell
Exec=/usr/local/bin/omd-hyprland-session
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF
    ok "  /usr/share/wayland-sessions/oh-my-desktop.desktop"

    if [[ -f /etc/gdm/custom.conf ]] && grep -Eq '^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false' /etc/gdm/custom.conf; then
        warn "GDM has WaylandEnable=false; enabling Wayland sessions."
        sudo sed -i 's/^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false/#WaylandEnable=false/' /etc/gdm/custom.conf
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
    echo "  1. Log out"
    echo "  2. In GDM, click the gear icon and choose \"Oh My Desktop\""
    echo "  3. Log in; Hyprland will load ~/.config/omd/hypr and autostart Quickshell"
    echo
    echo "Useful commands:"
    echo "  hyprctl reload            # Reload Hyprland config"
    echo "  ~/.config/omd/bin/omd-restart   # (Re)start Quickshell apps"
    echo "  ~/.config/omd/bin/omd-doctor    # Check runtime dependencies"
    echo "  journalctl --user -b | rg 'omd|quickshell|Hyprland|hyprland'  # Runtime logs"
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
    echo "  - Display tools (brightnessctl, swaybg, grim, slurp, swappy)"
    echo "  - Clipboard (cliphist, wl-clipboard)"
    echo "  - Notifications (mako)"
    echo "  - Quickshell"
    echo "  - Input method (fcitx5)"
    echo "  - Terminal (foot)"
    echo "  - Essential tools (jq, curl, git, ripgrep, fish, ydotool)"
    echo "  - Fonts/icons (Cantarell, Noto, Nerd Fonts, Material Symbols)"
    echo "  - User binaries (walker, elephant + OMD-configured providers)"
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
    install_session_files
    print_summary
}

main "$@"
