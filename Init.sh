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
        nixos)
            DISTRO_FAMILY="nixos"
            ;;
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

# Network + Bluetooth
# WiFi TUI (omd-wifi-tui) needs NetworkManager + nmcli.
# Bluetooth TUI (omd-bluetooth-tui) needs BlueZ + bluetoothctl.
# nmtui stays as a fallback; blueman is intentionally omitted (agent conflicts).
PACKAGES_NETWORK=(
    network-manager
    network-manager-wifi
    network-manager-tui
    network-manager-editor
    bluez
    bluez-utils
    rfkill
)

# Display/brightness
PACKAGES_DISPLAY=(
    brightnessctl
    ddcutil
    wlr-randr
    swaybg
    grim
    slurp
    swappy
    satty
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
    gnome-keyring-pam
)

# Terminal
PACKAGES_TERMINAL=(
    foot
    kitty
)

# Essential tools
PACKAGES_TOOLS=(
    go
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
    ffmpeg
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

# Desktop extras (optional but used by OMD)
PACKAGES_DESKTOP_EXTRAS=(
    hyprsunset
    keyd
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
        network-manager-tui)    echo "network-manager-tui" ;;
        network-manager-editor) echo "network-manager-gnome" ;;
        bluez)                  echo "bluez" ;;
        bluez-utils)            echo "bluez" ;;  # bluetoothctl ships in bluez on Debian
        rfkill)                 echo "rfkill" ;;
        brightnessctl)          echo "brightnessctl" ;;
        ddcutil)                echo "ddcutil" ;;
        wlr-randr)              echo "wlr-randr" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        swappy)                 echo "swappy" ;;
        satty)                  echo "satty" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        mako)                   echo "mako" ;;
        quickshell)             echo "quickshell" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-frontend-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-frontend-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        gnome-keyring-pam)      echo "libpam-gnome-keyring" ;;
        foot)                   echo "foot" ;;
        kitty)                  echo "kitty" ;;
        go)                     echo "golang-go" ;;
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
        ffmpeg)                 echo "ffmpeg" ;;
        hyprsunset)             echo "hyprsunset" ;;
        keyd)                   echo "keyd" ;;
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
        network-manager-tui)    echo "NetworkManager-tui" ;;
        network-manager-editor) echo "nm-connection-editor" ;;
        bluez)                  echo "bluez" ;;
        bluez-utils)            echo "bluez" ;;  # bluetoothctl in bluez on Fedora
        rfkill)                 echo "util-linux" ;;  # rfkill binary; usually already installed
        brightnessctl)          echo "brightnessctl" ;;
        ddcutil)                echo "ddcutil" ;;
        wlr-randr)              echo "wlr-randr" ;;
        swaybg)                 echo "swaybg" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        swappy)                 echo "swappy" ;;
        satty)                  echo "satty" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        cliphist)               echo "cliphist" ;;
        mako)                   echo "mako" ;;
        quickshell)             echo "quickshell" ;;
        fcitx5)                 echo "fcitx5" ;;
        fcitx5-gtk)             echo "fcitx5-gtk3" ;;
        fcitx5-qt)              echo "fcitx5-qt5" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit-gnome)           echo "polkit-gnome" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        gnome-keyring-pam)      echo "gnome-keyring-pam" ;;
        foot)                   echo "foot" ;;
        kitty)                  echo "kitty" ;;
        go)                     echo "golang" ;;
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
        ffmpeg)                 echo "ffmpeg-free" ;;
        hyprsunset)             echo "hyprsunset" ;;
        keyd)                   echo "keyd" ;;
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
        go)                     echo "go" ;;
        network-manager)        echo "networkmanager" ;;
        network-manager-wifi)   echo "networkmanager" ;;
        network-manager-tui)    echo "networkmanager" ;;
        network-manager-editor) echo "nm-connection-editor" ;;
        bluez)                  echo "bluez" ;;
        bluez-utils)            echo "bluez-utils" ;;  # bluetoothctl on Arch
        gnome-keyring-pam)      echo "gnome-keyring" ;; # PAM module ships in the main package
        rfkill)                 echo "util-linux" ;;
        ffmpeg)                 echo "ffmpeg" ;;
        cantarell-fonts)        echo "cantarell-fonts" ;;
        noto-fonts)             echo "noto-fonts" ;;
        noto-cjk-fonts)         echo "noto-fonts-cjk" ;;
        noto-emoji-fonts)       echo "noto-fonts-emoji" ;;
        jetbrains-mono-nerd-fonts) echo "ttf-jetbrains-mono-nerd" ;;
        meslo-nerd-fonts)       echo "ttf-meslo-nerd" ;;
        material-symbols-fonts) echo "ttf-material-symbols-variable-git" ;;
        font-awesome)           echo "ttf-font-awesome" ;;
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
        nixos)
            info "NixOS detected; package installation is handled by /etc/nixos/configuration.nix."
            return 0
            ;;
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

install_nixos_system_config() {
    local config_file="/etc/nixos/configuration.nix"
    local backup_file
    local stamp
    stamp="$(date +%Y%m%d_%H%M%S)"
    backup_file="${config_file}.bak-omd-${stamp}"

    if [[ ! -f "$config_file" ]]; then
        err "NixOS configuration not found: $config_file"
        exit 1
    fi

    if grep -q "Codex/OMD: Hyprland + Quickshell desktop" "$config_file"; then
        ok "NixOS OMD system configuration already present"
        return 0
    fi

    info "Adding OMD Hyprland/Quickshell configuration to $config_file..."
    sudo cp "$config_file" "$backup_file"

    local tmp_file
    local packages_file
    tmp_file="$(mktemp)"
    packages_file="$(mktemp)"
    cat >"$packages_file" <<'EOF'
    # OMD / Hyprland runtime
    hyprland
    hypridle
    hyprpicker
    xdg-desktop-portal-hyprland
    quickshell
    cliphist
    wl-clipboard
    mako

    # Audio, display, screenshot, power and session tools
    pamixer
    playerctl
    pavucontrol
    pulseaudio
    networkmanager
    networkmanagerapplet
    networkmanager-tui
    bluez
    brightnessctl
    ddcutil
    wlr-randr
    swaybg
    grim
    slurp
    swappy
    satty
    ydotool
    ffmpeg
    hyprsunset
    keyd
    libqalculate
    imagemagick
    power-profiles-daemon
    gnome-keyring
    polkit_gnome

    # Terminals and shell/tooling
    foot
    kitty
    go
    jq
    curl
    git
    ripgrep
    fish
    fontconfig
    unzip
    python3
    python3Packages.pip

    # Qt/GTK integration and file tools
    kdePackages.qtwayland
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    adwaita-qt
    gnome-themes-extra
    xdg-desktop-portal-gtk
    zenity
    nautilus
    evince
    kdePackages.plasma-systemmonitor
EOF

    awk -v pkgfile="$packages_file" '
      /environment\.systemPackages = with pkgs; \[/ && !inserted {
        print
        while ((getline line < pkgfile) > 0) print line
        close(pkgfile)
        inserted=1
        next
      }
      { print }
    ' "$config_file" | sed '$d' >"$tmp_file"
    cat >>"$tmp_file" <<'EOF'

  # Codex/OMD: Hyprland + Quickshell desktop
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.dconf.enable = true;

  # OMD WiFi / Bluetooth TUIs (nmcli + bluetoothctl)
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # External monitor brightness via ddcutil
  hardware.i2c.enable = true;

  fonts.packages = with pkgs; [
    cantarell-fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    material-symbols
    font-awesome
  ];

  services.displayManager.sessionPackages = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "oh-my-desktop-session";
      version = "1";
      dontUnpack = true;
      passthru.providedSessions = [ "oh-my-desktop" ];
      installPhase = ''
        mkdir -p $out/bin $out/share/wayland-sessions
        cp ${pkgs.writeShellScript "omd-hyprland-session" ''
          export OMD_ROOT="''${HOME}/.config/omd"
          export OMD_FORCE_NO_UWSM=1
          export XDG_CURRENT_DESKTOP=Hyprland
          export XDG_SESSION_DESKTOP=oh-my-desktop
          export XDG_SESSION_TYPE=wayland
          export QT_QPA_PLATFORM=wayland
          export GDK_BACKEND=wayland,x11
          export MOZ_ENABLE_WAYLAND=1
          export PATH="''${HOME}/.local/bin:''${OMD_ROOT}/bin:${pkgs.hyprland}/bin:${pkgs.quickshell}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/run/current-system/sw/bin:''${PATH}"

          config="''${OMD_ROOT}/hypr/hyprland.lua"
          if [[ ! -f "$config" ]]; then
            echo "OMD Hyprland config not found: $config" >&2
            exit 1
          fi

          if [[ -x ${pkgs.hyprland}/bin/start-hyprland ]]; then
            exec ${pkgs.hyprland}/bin/start-hyprland -- -c "$config"
          fi

          exec ${pkgs.hyprland}/bin/Hyprland -c "$config"
        ''} $out/bin/omd-hyprland-session
        printf '%s\n' \
          '[Desktop Entry]' \
          'Name=Oh My Desktop' \
          'Comment=OMD Hyprland session with Quickshell' \
          "Exec=$out/bin/omd-hyprland-session" \
          'Type=Application' \
          'DesktopNames=Hyprland' \
          'Keywords=tiling;wayland;compositor;' \
          > $out/share/wayland-sessions/oh-my-desktop.desktop
      '';
    })
  ];
}
EOF

    sudo install -m 0644 "$tmp_file" "$config_file"
    rm -f "$tmp_file" "$packages_file"

    info "Validating NixOS configuration..."
    if ! sudo nixos-rebuild dry-build; then
        err "NixOS dry-build failed; restoring $backup_file"
        sudo install -m 0644 "$backup_file" "$config_file"
        exit 1
    fi
    info "Applying NixOS configuration..."
    if ! sudo nixos-rebuild switch; then
        err "nixos-rebuild switch failed; restoring $backup_file"
        sudo install -m 0644 "$backup_file" "$config_file"
        exit 1
    fi
    ok "NixOS OMD system configuration applied"
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

# ── DDC/CI for external monitor brightness (ddcutil / i2c) ───────────────────
# Without this, omd-brightness-display and the bar Display slider cannot talk to
# external panels — /dev/i2c-* stays root:root 600 on many distros (incl. Fedora/Asahi).
setup_ddcutil_permissions() {
    info "Configuring DDC/CI access for external monitor brightness..."

    # Kernel module for userspace i2c
    if command -v modprobe >/dev/null 2>&1; then
        sudo modprobe i2c-dev 2>/dev/null || true
        if [[ -d /etc/modules-load.d ]]; then
            echo "i2c-dev" | sudo tee /etc/modules-load.d/omd-i2c-dev.conf >/dev/null
            ok "  i2c-dev module load-on-boot"
        fi
    fi

    # System group for i2c devices
    if ! getent group i2c >/dev/null 2>&1; then
        if sudo groupadd --system i2c 2>/dev/null; then
            ok "  created system group: i2c"
        else
            warn "  could not create i2c group"
        fi
    else
        ok "  i2c group exists"
    fi

    local target_user="${SUDO_USER:-$USER}"
    if [[ -n "$target_user" && "$target_user" != "root" ]] && getent group i2c >/dev/null 2>&1; then
        if id -nG "$target_user" 2>/dev/null | tr ' ' '\n' | grep -qx i2c; then
            ok "  user $target_user already in i2c group"
        else
            if sudo usermod -aG i2c "$target_user" 2>/dev/null; then
                ok "  added $target_user to i2c group (log out/in for group to apply)"
            else
                warn "  could not add $target_user to i2c group"
            fi
        fi
    fi

    # udev: group+mode so ddcutil works even when uaccess tags do not (common on Asahi).
    # Also keep ddcutil's class filter as a secondary rule if packaged.
    local rule_file="/etc/udev/rules.d/60-omd-ddcutil-i2c.rules"
    sudo tee "$rule_file" >/dev/null <<'EOF'
# OMD: allow members of group i2c to use ddcutil for monitor brightness (VCP 10).
# See docs/wifi-bluetooth-tui.md / multi-monitor brightness notes.
KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
# ddcutil vendor hint (harmless if ATTRS unsupported on some buses)
SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", ATTRS{class}=="0x030000", GROUP="i2c", MODE="0660", TAG+="uaccess"
EOF
    ok "  wrote $rule_file"

    # Prefer packaged ddcutil udev rules as well when present
    for vendor_rule in \
        /usr/lib/udev/rules.d/60-ddcutil-i2c.rules \
        /usr/share/ddcutil/data/60-ddcutil-i2c.rules; do
        if [[ -f "$vendor_rule" && ! -e /etc/udev/rules.d/$(basename "$vendor_rule") ]]; then
            sudo cp "$vendor_rule" /etc/udev/rules.d/ 2>/dev/null || true
        fi
    done

    if command -v udevadm >/dev/null 2>&1; then
        sudo udevadm control --reload-rules 2>/dev/null || true
        sudo udevadm trigger --subsystem-match=i2c-dev --action=add 2>/dev/null || true
        ok "  udev rules reloaded"
    fi

    # Immediate access without re-login (group membership only applies after new session).
    # setfacl is best-effort; udev group rule covers the next boot / re-login.
    if [[ -n "${target_user:-}" && "$target_user" != "root" ]] && command -v setfacl >/dev/null 2>&1; then
        local node
        for node in /dev/i2c-*; do
            [[ -e "$node" ]] || continue
            sudo setfacl -m "u:${target_user}:rw" "$node" 2>/dev/null || true
        done
        ok "  ACL: granted $target_user rw on existing /dev/i2c-* (current session)"
    fi

    # Drop stale DDC cache so Brightness service re-probes buses after permissions fix
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/omd/ddc-detect-brief.txt" \
          "${XDG_CACHE_HOME:-$HOME/.cache}/omd/ddc-bus-map.txt" 2>/dev/null || true

    # Non-fatal probe
    if command -v ddcutil >/dev/null 2>&1; then
        if ddcutil detect --brief >/dev/null 2>&1; then
            ok "  ddcutil can probe displays"
        else
            warn "  ddcutil still cannot open i2c — log out/in (i2c group), re-plug the monitor, then: omd-restart"
        fi
    else
        warn "  ddcutil not installed — external brightness needs the ddcutil package"
    fi
}

# ── Enable WiFi/Bluetooth backends for omd-*-tui ─────────────────────────────
enable_network_bluetooth_services() {
    info "Enabling NetworkManager + bluetooth services..."

    if ! command -v systemctl >/dev/null 2>&1; then
        warn "systemctl not available; skip service enable"
        return 0
    fi

    # Soft-unblock radios when rfkill exists
    if command -v rfkill >/dev/null 2>&1; then
        rfkill unblock wifi 2>/dev/null || true
        rfkill unblock wlan 2>/dev/null || true
        rfkill unblock bluetooth 2>/dev/null || true
    fi

    local svc
    for svc in NetworkManager bluetooth; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null \
            || systemctl status "${svc}.service" &>/dev/null; then
            if sudo systemctl enable --now "${svc}.service" 2>/dev/null; then
                ok "  ${svc}.service enabled"
            else
                warn "  could not enable ${svc}.service (may need manual setup)"
            fi
        else
            warn "  ${svc}.service not found on this system"
        fi
    done

    # Quick sanity for TUI backends
    if command -v nmcli >/dev/null 2>&1; then
        ok "  nmcli ready (omd-wifi-tui)"
    else
        warn "  nmcli missing after install — omd-wifi-tui will not work"
    fi
    if command -v bluetoothctl >/dev/null 2>&1; then
        ok "  bluetoothctl ready (omd-bluetooth-tui)"
    else
        warn "  bluetoothctl missing after install — omd-bluetooth-tui will not work"
    fi
}

# ── Main installation flow ────────────────────────────────────────────────────
install_all_dependencies() {
    info "Installing core dependencies..."
    echo

    if [[ "$DISTRO_FAMILY" == "nixos" ]]; then
        install_nixos_system_config
        echo

        info "═══ Fonts & Icons ═══"
        install_user_fonts
        echo

        ok "NixOS dependencies installed!"
        return 0
    fi

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

    # Network + Bluetooth (omd-wifi-tui / omd-bluetooth-tui)
    info "═══ Network & Bluetooth ═══"
    install_packages "${PACKAGES_NETWORK[@]}"
    enable_network_bluetooth_services
    echo

    # Display
    info "═══ Display & Screenshots ═══"
    install_packages "${PACKAGES_DISPLAY[@]}"
    setup_ddcutil_permissions
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

    # Qt/GTK
    info "═══ Qt/GTK Integration ═══"
    install_packages "${PACKAGES_QT_GTK[@]}"
    echo

    # File managers
    info "═══ File Managers ═══"
    install_packages "${PACKAGES_FILES[@]}"
    echo

    # Desktop extras (optional tools used by OMD)
    info "═══ Desktop Extras ═══"
    install_packages "${PACKAGES_DESKTOP_EXTRAS[@]}"
    echo

    ok "All dependencies installed!"
}

# ── Symlink creation ──────────────────────────────────────────────────────────
create_symlinks() {
    local LINKS=(
        "$HOME/.config/quickshell|$REPO/quickshell"
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

repair_runtime_config() {
    echo
    info "Repairing runtime config..."

    local config_file="$REPO/quickshell/config.json"
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file="$(mktemp)"
        if jq 'del(.audio.levels)' "$config_file" >"$tmp_file"; then
            if ! cmp -s "$config_file" "$tmp_file"; then
                mv "$tmp_file" "$config_file"
                ok "  removed runtime-only audio.levels from quickshell/config.json"
            else
                rm -f "$tmp_file"
                ok "  quickshell/config.json"
            fi
        else
            rm -f "$tmp_file"
            warn "  could not parse quickshell/config.json; leaving it unchanged"
        fi
    else
        warn "  jq unavailable or config missing; skipped config repair"
    fi

    mkdir -p "$REPO/current"
    if [[ ! -f "$REPO/current/wallpaper" ]]; then
        cp "$REPO/quickshell/assets/images/default_wallpaper.png" "$REPO/current/wallpaper"
        chmod 0644 "$REPO/current/wallpaper"
        ok "  seeded current/wallpaper from the default wallpaper"
    fi
    ln -sfn "wallpaper" "$REPO/current/background"
    ok "  current/background -> wallpaper"

    date +%s%N >"$REPO/current/wallpaper.revision"

    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local wallpaper_tmp
        wallpaper_tmp="$(mktemp)"
        if jq '.background.wallpaperPath = "~/.config/omd/current/background" | .background.thumbnailPath = ""' \
            "$config_file" >"$wallpaper_tmp"; then
            mv "$wallpaper_tmp" "$config_file"
            ok "  configured stable wallpaper path"
        else
            rm -f "$wallpaper_tmp"
            warn "  could not configure the stable wallpaper path"
        fi
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

install_nixos_session_files() {
    echo
    info "Installing NixOS-compatible OMD helper scripts..."

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
    ok "  Oh My Desktop session is managed by NixOS services.displayManager.sessionPackages"
}

# ── Custom OMD launchers ──────────────────────────────────────────────────────
install_custom_launchers() {
    echo
    info "Installing custom OMD launchers..."
    if [[ -x "$REPO/scripts/install-launchers" ]]; then
        "$REPO/scripts/install-launchers" || warn "custom launchers install failed"
    else
        warn "scripts/install-launchers not found; skipping"
    fi
}

# ── Go tools ─────────────────────────────────────────────────────────────────
build_go_tools() {
    local required="${1:-1}"

    echo
    info "Building OMD Go tools..."
    if [[ ! -x "$REPO/scripts/build-go-tools" ]]; then
        if [[ "$required" == 1 ]]; then
            err "scripts/build-go-tools is missing or not executable"
            return 1
        fi
        warn "scripts/build-go-tools is missing or not executable; skipping"
        return 0
    fi

    if "$REPO/scripts/build-go-tools"; then
        ok "OMD Go tools ready"
    elif [[ "$required" == 1 ]]; then
        err "OMD Go tools could not be built"
        return 1
    else
        warn "OMD Go tools could not be refreshed; run the full ./Init.sh"
    fi
}

# ── Print summary ─────────────────────────────────────────────────────────────
print_summary() {
    local login_manager="your display manager"
    if systemctl is-enabled sddm.service >/dev/null 2>&1; then
        login_manager="SDDM"
    elif systemctl is-enabled gdm.service >/dev/null 2>&1; then
        login_manager="GDM"
    fi

    echo
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  oh-my-desktop setup complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo "Next steps:"
    echo "  1. Log out"
    echo "  2. In ${login_manager}, choose \"Oh My Desktop\" from the session menu"
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
    local runtime_only=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --runtime-only)
                runtime_only=1
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--runtime-only]"
                echo
                echo "  --runtime-only  Only repair symlinks and runtime config; do not install packages or session files."
                exit 0
                ;;
            *)
                err "Unknown option: $1"
                echo "Usage: $0 [--runtime-only]" >&2
                exit 2
                ;;
        esac
    done

    echo
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  oh-my-desktop installer${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo

    detect_distro
    echo

    if [[ "$runtime_only" == 1 ]]; then
        info "Runtime-only mode: repairing symlinks and runtime config."
        create_symlinks
        repair_runtime_config
        install_custom_launchers
        build_go_tools 0
        ok "Runtime repair complete."
        exit 0
    fi

    # Ask for confirmation
    echo "This will install the following packages:"
    echo "  - Hyprland ecosystem (compositor, lock, idle, portal)"
    echo "  - Quickshell dependencies"
    echo "  - Audio (PipeWire, WirePlumber)"
    echo "  - Network & Bluetooth (NetworkManager, nmtui, bluez — omd-wifi-tui / omd-bluetooth-tui)"
    echo "  - Display tools (brightnessctl, ddcutil, wlr-randr, swaybg, grim, slurp, swappy, satty)"
    echo "  - Clipboard (cliphist, wl-clipboard)"
    echo "  - Notifications (mako)"
    echo "  - Quickshell"
    echo "  - Input method (fcitx5)"
    echo "  - Terminal (foot)"
    echo "  - Essential tools (Go, jq, curl, git, ripgrep, fish, ydotool, ffmpeg)"
    echo "  - Desktop extras (hyprsunset, keyd)"
    echo "  - Fonts/icons (Cantarell, Noto, Nerd Fonts, Material Symbols)"
    echo "  - Qt/GTK integration"
    echo

    read -p "Proceed with installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    install_all_dependencies
    build_go_tools 1
    create_symlinks
    repair_runtime_config
    install_custom_launchers
    if [[ "$DISTRO_FAMILY" == "nixos" ]]; then
        install_nixos_session_files
    else
        install_session_files
    fi
    print_summary
}

main "$@"
