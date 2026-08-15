#!/bin/bash
set -eu

# Sumika Shell setup script.
# Installs dependencies and creates runtime symlinks from ~ into this repo.
# Run after cloning:  git clone ... ~/development/OMD && cd ~/development/OMD && ./Init.sh

REPO="$(cd "$(dirname "$0")" && pwd -P)"

# Init.sh creates runtime symlinks and installs dependencies for the Core
# product floor only. Optional extensions own and document their dependencies.
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
    pavucontrol
    ffmpeg
)

# Network + Bluetooth
# WiFi TUI (sumika-wifi-tui) needs NetworkManager + nmcli.
# Bluetooth TUI (sumika-bluetooth-tui) needs BlueZ + bluetoothctl.
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

# Display/brightness + capture/recording tools used by Core and the screenshot
# extension (region select, clipboard snip, screen record backend).
PACKAGES_DISPLAY=(
    brightnessctl
    ddcutil
    wlr-randr
    grim
    slurp
    wf-recorder
    wl-clipboard
    hyprsunset
)

# Quickshell runtime
PACKAGES_QUICKSHELL=(
    quickshell
)

# Power/polkit
PACKAGES_POWER=(
    power-profiles-daemon
    polkit
    gnome-keyring
    gnome-keyring-pam
    libsecret-tools
)

# Terminal
PACKAGES_TERMINAL=(
    foot
)

# Essential tools
PACKAGES_TOOLS=(
    jq
    curl
    fontconfig
    libnotify-tools
    unzip
    python3
)

# Fonts used directly by Core QML.
PACKAGES_FONTS=(
    noto-fonts
    noto-cjk-fonts
    noto-emoji-fonts
)

# Qt/GTK integration
PACKAGES_QT_GTK=(
    qt6-wayland
    xdg-desktop-portal-gtk
    zenity
    qt6ct
    kvantum
)

# NixOS user-profile fallbacks.  A declarative NixOS module is preferred, but
# Init.sh must also be useful on a freshly installed system where the user has
# not yet added Sumika to their flake.  These names are nixpkgs flake attrs,
# not distro package names; they are installed into the user's profile and do
# not mutate /etc/nixos.
PACKAGES_NIXOS_PROFILE=(
    hyprland hypridle hyprpicker quickshell
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    pipewire wireplumber pavucontrol alsa-utils
    networkmanager bluez brightnessctl ddcutil wlr-randr
    grim slurp wf-recorder wl-clipboard wtype hyprsunset swaybg
    power-profiles-daemon gnome-keyring libsecret
    foot jq curl fontconfig unzip python3 ffmpeg
    file cliphist imagemagick swappy satty libnotify
    go gcc nerd-fonts.meslo-lg
    zenity

    # Common desktop/work applications used by the reference Sumika setup.
    # Keep these in the initializer so a fresh NixOS host has the same
    # launcher entries and can execute them immediately.
    alacritty btop blender chromium mpv neovim obs-studio xournalpp
    godot ranger syncthing libreoffice wdisplays pinta htop
    kdePackages.kdenlive kdePackages.filelight kdePackages.kdeconnect-kde
    kdePackages.spectacle qt6Packages.qt6ct
    glib gtk3 xdg-utils chezmoi
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
        pavucontrol)            echo "pavucontrol" ;;
        network-manager)        echo "network-manager" ;;
        network-manager-wifi)   echo "network-manager" ;;
        network-manager-tui)    echo "network-manager" ;; # nmtui ships in network-manager
        network-manager-editor) echo "network-manager-gnome" ;;
        bluez)                  echo "bluez" ;;
        bluez-utils)            echo "bluez" ;;  # bluetoothctl ships in bluez on Debian
        rfkill)                 echo "rfkill" ;;
        brightnessctl)          echo "brightnessctl" ;;
        ddcutil)                echo "ddcutil" ;;
        wlr-randr)              echo "wlr-randr" ;;
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        wf-recorder)            echo "wf-recorder" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        quickshell)             echo "quickshell" ;;
        power-profiles-daemon)  echo "power-profiles-daemon" ;;
        polkit)                 echo "policykit-1" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        gnome-keyring-pam)      echo "libpam-gnome-keyring" ;;
        libsecret-tools)        echo "libsecret-tools" ;;
        foot)                   echo "foot" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        fontconfig)             echo "fontconfig" ;;
        libnotify-tools)        echo "libnotify-bin" ;;
        unzip)                  echo "unzip" ;;
        python3)                echo "python3" ;;
        ffmpeg)                 echo "ffmpeg" ;;
        hyprsunset)             echo "hyprsunset" ;;
        noto-fonts)             echo "fonts-noto-core" ;;
        noto-cjk-fonts)         echo "fonts-noto-cjk" ;;
        noto-emoji-fonts)       echo "fonts-noto-color-emoji" ;;
        qt6-wayland)            echo "qt6-wayland" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        zenity)                 echo "zenity" ;;
        qt6ct)                  echo "qt6ct" ;;
        kvantum)                echo "qt-style-kvantum" ;;
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
        grim)                   echo "grim" ;;
        slurp)                  echo "slurp" ;;
        wf-recorder)            echo "wf-recorder" ;;
        wl-clipboard)           echo "wl-clipboard" ;;
        quickshell)             echo "quickshell" ;;
        power-profiles-daemon)  echo "tuned-ppd" ;; # Fedora's PPD-compatible service
        polkit)                 echo "polkit" ;;
        gnome-keyring)          echo "gnome-keyring" ;;
        gnome-keyring-pam)      echo "gnome-keyring-pam" ;;
        libsecret-tools)        echo "libsecret" ;;
        foot)                   echo "foot" ;;
        jq)                     echo "jq" ;;
        curl)                   echo "curl" ;;
        fontconfig)             echo "fontconfig" ;;
        libnotify-tools)        echo "libnotify" ;;
        unzip)                  echo "unzip" ;;
        python3)                echo "python3" ;;
        ffmpeg)                 echo "ffmpeg-free" ;;
        hyprsunset)             echo "hyprsunset" ;;
        noto-fonts)             echo "google-noto-sans-vf-fonts" ;;
        noto-cjk-fonts)         echo "google-noto-sans-cjk-vf-fonts" ;;
        noto-emoji-fonts)       echo "google-noto-color-emoji-fonts" ;;
        qt6-wayland)            echo "qt6-qtwayland" ;;
        xdg-desktop-portal-gtk) echo "xdg-desktop-portal-gtk" ;;
        zenity)                 echo "zenity" ;;
        qt6ct)                  echo "qt6ct" ;;
        kvantum)                echo "kvantum" ;;
        *)                      echo "$1" ;;
    esac
}

get_arch_pkg() {
    case "$1" in
        pipewire-utils)         echo "pipewire" ;;
        network-manager)        echo "networkmanager" ;;
        network-manager-wifi)   echo "networkmanager" ;;
        network-manager-tui)    echo "networkmanager" ;;
        network-manager-editor) echo "nm-connection-editor" ;;
        bluez)                  echo "bluez" ;;
        bluez-utils)            echo "bluez-utils" ;;  # bluetoothctl on Arch
        gnome-keyring-pam)      echo "gnome-keyring" ;; # PAM module ships in the main package
        libsecret-tools)        echo "libsecret" ;;
        libnotify-tools)        echo "libnotify" ;;
        rfkill)                 echo "util-linux" ;;
        ffmpeg)                 echo "ffmpeg" ;;
        noto-fonts)             echo "noto-fonts" ;;
        noto-cjk-fonts)         echo "noto-fonts-cjk" ;;
        noto-emoji-fonts)       echo "noto-fonts-emoji" ;;
        kvantum)                echo "kvantum" ;;
        *)                      echo "$1" ;;
    esac
}

get_suse_pkg() {
    case "$1" in
        pipewire-pulse)         echo "pipewire-pulseaudio" ;;
        pipewire-utils)         echo "pipewire-tools" ;;
        network-manager)        echo "NetworkManager" ;;
        network-manager-wifi)   echo "NetworkManager" ;;
        network-manager-tui)    echo "NetworkManager-tui" ;;
        network-manager-editor) echo "NetworkManager-connection-editor" ;;
        bluez-utils)            echo "bluez" ;;
        gnome-keyring-pam)      echo "pam_gnome_keyring" ;;
        libnotify-tools)        echo "libnotify-tools" ;;
        noto-fonts)             echo "google-noto-fonts" ;;
        noto-cjk-fonts)         echo "google-noto-sans-cjk-fonts" ;;
        noto-emoji-fonts)       echo "google-noto-coloremoji-fonts" ;;
        qt6-wayland)            echo "libqt6-qtwayland" ;;
        kvantum)                echo "kvantum-qt6" ;;
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
            suse)
                mapped_pkgs+=("$(get_suse_pkg "$pkg")")
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
                suse)
                    sudo zypper --non-interactive install --no-recommends "$single" || failed=1
                    ;;
            esac
        done

        if ((failed)); then
            warn "Some packages were unavailable. Continuing; run bin/sumika-doctor afterward for exact gaps."
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
        suse)
            info "Installing packages with zypper..."
            sudo zypper --non-interactive refresh
            sudo zypper --non-interactive install --no-recommends "${mapped_pkgs[@]}" || {
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

install_nixos_profile_dependencies() {
    info "Installing Sumika Shell runtime through the Nix user profile..."

    if ! command -v nix >/dev/null 2>&1; then
        err "Nix is not available. Install Nix/NixOS first, then rerun Init.sh."
        return 1
    fi

    local attrs=()
    local pkg
    for pkg in "${PACKAGES_NIXOS_PROFILE[@]}"; do
        attrs+=("nixpkgs#$pkg")
    done

    # NixOS users commonly disable nix-command/flakes globally.  Enabling the
    # features for this invocation keeps Init.sh self-contained and does not
    # rewrite nix.conf.
    if nix --extra-experimental-features 'nix-command flakes' profile add "${attrs[@]}"; then
        ok "NixOS runtime dependencies installed in ~/.nix-profile"
    else
        err "Nix profile installation failed. See the Nix output above."
        return 1
    fi
}

install_nixos_system_config() {
    local config_file="/etc/nixos/configuration.nix"
    local backup_file
    local stamp
    stamp="$(date +%Y%m%d_%H%M%S)"
    backup_file="${config_file}.bak-sumika-${stamp}"

    if [[ ! -f "$config_file" ]]; then
        err "NixOS configuration not found: $config_file"
        exit 1
    fi

    if grep -Eq "Sumika Shell: Hyprland|Codex/OMD: Hyprland" "$config_file"; then
        ok "NixOS Sumika Shell system configuration already present"
        return 0
    fi

    info "Adding Sumika Shell Hyprland/Quickshell configuration to $config_file..."
    sudo cp "$config_file" "$backup_file"

    local tmp_file
    local packages_file
    tmp_file="$(mktemp)"
    packages_file="$(mktemp)"
    cat >"$packages_file" <<'EOF'
    # Sumika Shell / Hyprland runtime
    hyprland
    hypridle
    hyprpicker
    xdg-desktop-portal-hyprland
    quickshell
    wl-clipboard

    # Core audio, network, display, power and session tools
    pavucontrol
    wireplumber
    networkmanager
    networkmanager-tui
    bluez
    brightnessctl
    ddcutil
    wlr-randr
    grim
    slurp
    wf-recorder
    ffmpeg
    hyprsunset
    power-profiles-daemon
    gnome-keyring
    libsecret
    libnotify

    # Terminal and Core tooling
    foot
    jq
    curl
    fontconfig
    unzip
    python3

    # Qt/GTK integration
    kdePackages.qtwayland
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    xdg-desktop-portal-gtk
    zenity
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

  # Sumika Shell: Hyprland + Quickshell desktop
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
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  services.gnome.gnome-keyring.enable = true;
  services.power-profiles-daemon.enable = true;
  programs.dconf.enable = true;

  # Sumika Shell WiFi / Bluetooth TUIs (nmcli + bluetoothctl)
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # External monitor brightness via ddcutil
  hardware.i2c.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    meslo-lgs-nf
    material-symbols
  ];

  services.displayManager.sessionPackages = [
    (pkgs.stdenvNoCC.mkDerivation {
      pname = "sumika-shell-session";
      version = "1";
      dontUnpack = true;
      passthru.providedSessions = [ "sumika-shell" ];
      installPhase = ''
        mkdir -p $out/bin $out/share/wayland-sessions
        cp ${pkgs.writeShellScript "sumika-hyprland-session" ''
          export SUMIKA_SHELL_ROOT="__REPO_ROOT__"
          export SUMIKA_FORCE_NO_UWSM=1
          export XDG_CURRENT_DESKTOP=Hyprland
          export XDG_SESSION_DESKTOP=sumika-shell
          export XDG_SESSION_TYPE=wayland
          export QT_QPA_PLATFORM=wayland
          export GDK_BACKEND=wayland,x11
          export MOZ_ENABLE_WAYLAND=1
          export PATH="''${HOME}/.local/bin:''${SUMIKA_SHELL_ROOT}/bin:${pkgs.hyprland}/bin:${pkgs.quickshell}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/run/current-system/sw/bin:''${PATH}"

          config="''${SUMIKA_SHELL_ROOT}/hypr/hyprland.lua"
          if [[ ! -f "$config" ]]; then
            echo "Sumika Shell Hyprland config not found: $config" >&2
            exit 1
          fi

          if [[ -x ${pkgs.hyprland}/bin/start-hyprland ]]; then
            exec ${pkgs.hyprland}/bin/start-hyprland -- -c "$config"
          fi

          exec ${pkgs.hyprland}/bin/Hyprland -c "$config"
        ''} $out/bin/sumika-hyprland-session
        printf '%s\n' \
          '[Desktop Entry]' \
          'Name=Sumika Shell' \
          'Comment=Sumika Shell Hyprland session with Quickshell' \
          "Exec=$out/bin/sumika-hyprland-session" \
          'Type=Application' \
          'DesktopNames=Hyprland' \
          'Keywords=tiling;wayland;compositor;' \
          > $out/share/wayland-sessions/sumika-shell.desktop
      '';
    })
  ];
}
EOF

    sudo sed -i "s|__REPO_ROOT__|$REPO|g" "$tmp_file"
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
    ok "NixOS Sumika Shell system configuration applied"
}

# ── Hyprland PPA/source installation helpers ──────────────────────────────────
setup_hyprland_repo_debian() {
    if apt-cache show hyprland >/dev/null 2>&1; then
        ok "Hyprland is available from the configured APT repositories"
        return 0
    fi

    case "$DISTRO_ID" in
        ubuntu|linuxmint|pop|elementary|zorin)
            info "Hyprland is unavailable in the configured repositories; trying the Ubuntu PPA..."
            sudo apt install -y software-properties-common
            if ! grep -Rqs "hyprland/stable" /etc/apt/sources.list.d 2>/dev/null; then
                sudo add-apt-repository -y ppa:hyprland/stable || {
                    warn "Could not add the Hyprland PPA. Install Hyprland using your distribution's supported source."
                    return 1
                }
                sudo apt update
            fi
            ;;
        *)
            warn "Hyprland is unavailable in the configured Debian repositories."
            warn "An Ubuntu PPA will not be added to Debian. Enable a repository appropriate for $DISTRO_NAME."
            return 1
            ;;
    esac
}

setup_hyprland_repo_rhel() {
    if rpm -q hyprland >/dev/null 2>&1 || dnf -q list --available hyprland >/dev/null 2>&1; then
        ok "Hyprland is available from the configured DNF repositories"
        return 0
    fi

    info "Hyprland is unavailable in the configured repositories; trying the Fedora COPR..."
    sudo dnf copr enable -y ashbuk/Hyprland-Fedora || {
        warn "Could not add the Hyprland COPR. Install Hyprland using your distribution's supported source."
    }
}

setup_quickshell_repo_rhel() {
    if rpm -q quickshell >/dev/null 2>&1 || dnf -q list --available quickshell >/dev/null 2>&1; then
        ok "Quickshell is available from the configured DNF repositories"
        return 0
    fi

    info "Quickshell is unavailable in the configured repositories; trying the Fedora COPR..."
    sudo dnf copr enable -y errornointernet/quickshell || {
        warn "Could not add the Quickshell COPR. Install Quickshell using your distribution's supported source."
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
    local dest="$HOME/.local/share/fonts/sumika-shell/$family"
    local tmp_zip="/tmp/sumika-${family// /-}.zip"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/sumika-shell..."
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
    local dest="$HOME/.local/share/fonts/sumika-shell/material-symbols"
    local file="$dest/MaterialSymbolsRounded.ttf"
    local url="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"

    if font_family_resolves "$family"; then
        ok "  $family"
        return 0
    fi

    info "Installing $family into ~/.local/share/fonts/sumika-shell..."
    mkdir -p "$dest"
    curl -fL "$url" -o "$file" || {
        warn "Could not download $family"
        return 1
    }
}

install_user_fonts() {
    info "Checking Sumika Shell UI fonts..."

    install_nerd_font_zip "JetBrainsMono Nerd Font Mono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || true
    install_nerd_font_zip "MesloLGS Nerd Font Mono" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" || true
    install_material_symbols_font || true

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts/sumika-shell" >/dev/null 2>&1 || true
    fi

    for family in "Noto Color Emoji" "JetBrainsMono Nerd Font Mono" "MesloLGS Nerd Font Mono" "Material Symbols Rounded"; do
        if font_family_resolves "$family"; then
            ok "  font available: $family"
        else
            warn "font still missing or falling back: $family"
        fi
    done
}

# ── DDC/CI for external monitor brightness (ddcutil / i2c) ───────────────────
# Without this, sumika-brightness-display and the bar Display slider cannot talk to
# external panels — /dev/i2c-* stays root:root 600 on many distros (incl. Fedora/Asahi).
setup_ddcutil_permissions() {
    info "Configuring DDC/CI access for external monitor brightness..."

    # Kernel module for userspace i2c
    if command -v modprobe >/dev/null 2>&1; then
        sudo modprobe i2c-dev 2>/dev/null || true
        if [[ -d /etc/modules-load.d ]]; then
            echo "i2c-dev" | sudo tee /etc/modules-load.d/sumika-i2c-dev.conf >/dev/null
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
    local rule_file="/etc/udev/rules.d/60-sumika-ddcutil-i2c.rules"
    sudo tee "$rule_file" >/dev/null <<'EOF'
# Sumika Shell: allow members of group i2c to use ddcutil for monitor brightness (VCP 10).
# See docs/tui/wifi-bluetooth-tui.md / multi-monitor brightness notes.
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
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/sumika-shell/ddc-detect-brief.txt" \
          "${XDG_CACHE_HOME:-$HOME/.cache}/omd/ddc-detect-brief.txt" \
          "${XDG_CACHE_HOME:-$HOME/.cache}/omd/ddc-bus-map.txt" 2>/dev/null || true

    # Non-fatal probe
    if command -v ddcutil >/dev/null 2>&1; then
        if ddcutil detect --brief >/dev/null 2>&1; then
            ok "  ddcutil can probe displays"
        else
            warn "  ddcutil still cannot open i2c — log out/in (i2c group), re-plug the monitor, then: sumika-restart"
        fi
    else
        warn "  ddcutil not installed — external brightness needs the ddcutil package"
    fi
}

# ── Enable WiFi/Bluetooth backends for sumika-*-tui ──────────────────────────
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
        ok "  nmcli ready (sumika-wifi-tui)"
    else
        warn "  nmcli missing after install — sumika-wifi-tui will not work"
    fi
    if command -v bluetoothctl >/dev/null 2>&1; then
        ok "  bluetoothctl ready (sumika-bluetooth-tui)"
    else
        warn "  bluetoothctl missing after install — sumika-bluetooth-tui will not work"
    fi
}

# ── Main installation flow ────────────────────────────────────────────────────
install_all_dependencies() {
    info "Installing core dependencies..."
    echo

    if [[ "$DISTRO_FAMILY" == "nixos" ]]; then
        install_nixos_profile_dependencies

        # A flake-managed host must be changed in its own repository.  Never
        # overwrite /etc/nixos/configuration.nix behind the user's back.
        # Conventional non-flake installs may opt into the legacy helper with
        # SUMIKA_NIXOS_APPLY_SYSTEM=1.
        if [[ "${SUMIKA_NIXOS_APPLY_SYSTEM:-0}" == "1" ]]; then
            install_nixos_system_config
        elif [[ -f "$HOME/nixos-config/flake.nix" ]] || [[ -f "$REPO/flake.nix" ]]; then
            warn "Flake-managed NixOS detected; leaving the host configuration untouched."
            warn "Add the Sumika module/package list to your flake and run nixos-rebuild switch."
        else
            warn "No flake detected. The runtime profile is ready; set SUMIKA_NIXOS_APPLY_SYSTEM=1 to configure the host session."
        fi
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

    # Network + Bluetooth (sumika-wifi-tui / sumika-bluetooth-tui)
    info "═══ Network & Bluetooth ═══"
    install_packages "${PACKAGES_NETWORK[@]}"
    enable_network_bluetooth_services
    echo

    # Display
    info "═══ Display ═══"
    install_packages "${PACKAGES_DISPLAY[@]}"
    setup_ddcutil_permissions
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
    install_user_fonts
    echo

    # Qt/GTK
    info "═══ Qt/GTK Integration ═══"
    install_packages "${PACKAGES_QT_GTK[@]}"
    echo

    ok "All Core dependencies installed!"
}

verify_core_dependencies() {
    local missing=()
    local cmd

    for cmd in hyprctl wpctl nmcli bluetoothctl brightnessctl wlr-randr \
        grim slurp wf-recorder wl-copy hyprpicker foot zenity secret-tool \
        jq curl python3 notify-send; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    command -v Hyprland >/dev/null 2>&1 \
        || command -v hyprland >/dev/null 2>&1 \
        || missing+=("Hyprland/hyprland")
    command -v qs >/dev/null 2>&1 \
        || command -v quickshell >/dev/null 2>&1 \
        || missing+=("qs/quickshell")

    if ((${#missing[@]})); then
        err "Core dependency verification failed. Missing commands:"
        printf '  %s\n' "${missing[@]}" >&2
        err "Your distribution may need an additional repository; see docs/architecture/third-party-deps.md."
        return 1
    fi

    ok "Verified all required Core commands"
}

# ── Symlink creation ──────────────────────────────────────────────────────────
create_symlinks() {
    local LINKS=(
        "$HOME/.config/quickshell|$REPO/quickshell"
        # hypridle 0.1.7 ignores -c and checks HOME/XDG_CONFIG_HOME first;
        # without this symlink it crashes on every launch (SIGABRT), taking
        # the lock/idle daemon down with the session on logout.
        "$HOME/.config/hypr/hypridle.conf|$REPO/hypr/hypridle.conf"
    )

    local backup_dir=""

    # The repository root is now supplied through SUMIKA_SHELL_ROOT. Remove
    # the retired technical namespace symlink after user data migration.
    if [[ -L "$HOME/.config/omd" ]]; then
        rm -f "$HOME/.config/omd"
        ok "  removed retired ~/.config/omd symlink"
    fi

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
                backup_dir="$HOME/.config/sumika-backup-${stamp}"
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

    local wp_dir="${SUMIKA_SHELL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/sumika-shell}/wallpaper"
    mkdir -p "$wp_dir"
    if [[ ! -f "$wp_dir/wallpaper" ]]; then
        local ext_themes="${SUMIKA_SHELL_EXTENSIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sumika-shell/extensions}/theme-settings/themes"
        local seed="$ext_themes/last-horizon/backgrounds/4-new-horizons.jpg"
        [[ -f "$seed" ]] || seed="$REPO/share/themes/last-horizon/backgrounds/4-new-horizons.jpg"
        if [[ -f "$seed" ]]; then
            cp "$seed" "$wp_dir/wallpaper"
            chmod 0644 "$wp_dir/wallpaper"
            ok "  seeded wallpaper from the default theme"
        else
            warn "  default theme wallpaper not found; skipping seed"
        fi
    fi
    if [[ -f "$wp_dir/wallpaper" ]]; then
        ln -sfn "wallpaper" "$wp_dir/background"
        date +%s%N >"$wp_dir/revision"
        ok "  wallpaper/background -> wallpaper"
    else
        rm -f "$wp_dir/background"
        warn "  no wallpaper is available; Core will use its configured fallback color"
    fi

    # User settings live in ~/.config/sumika-shell/sumika.json and are never
    # rewritten by the installer. Config.qml creates defaults on first launch;
    # migrations preserve existing user overrides.
}

# ── Session registration ──────────────────────────────────────────────────────
install_session_files() {
    echo
    info "Installing GDM/Wayland session entry..."

    mkdir -p "$HOME/.local/bin"
    cat >"$HOME/.local/bin/uwsm-app" <<'EOF'
#!/bin/bash
set -e

if [[ ${SUMIKA_FORCE_NO_UWSM:-0} == 1 ]]; then
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

    sudo tee /usr/local/bin/sumika-hyprland-session >/dev/null <<'EOF'
#!/bin/bash
set -e

export SUMIKA_SHELL_ROOT="__REPO_ROOT__"
export SUMIKA_FORCE_NO_UWSM=1
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=sumika-shell
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland,x11
export MOZ_ENABLE_WAYLAND=1
export PATH="${HOME}/.local/bin:${SUMIKA_SHELL_ROOT}/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

config="${SUMIKA_SHELL_ROOT}/hypr/hyprland.lua"

if [[ ! -f "$config" ]]; then
    echo "Sumika Shell Hyprland config not found: $config" >&2
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
    sudo sed -i "s|__REPO_ROOT__|$REPO|g" /usr/local/bin/sumika-hyprland-session
    sudo chmod +x /usr/local/bin/sumika-hyprland-session
    ok "  /usr/local/bin/sumika-hyprland-session"

    sudo tee /usr/share/wayland-sessions/sumika-shell.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Sumika Shell
Comment=Sumika Shell Hyprland session with Quickshell
Exec=/usr/local/bin/sumika-hyprland-session
Type=Application
DesktopNames=Hyprland
Keywords=tiling;wayland;compositor;
EOF
    sudo rm -f /usr/share/wayland-sessions/oh-my-desktop.desktop \
        /usr/local/bin/omd-hyprland-session
    ok "  /usr/share/wayland-sessions/sumika-shell.desktop"

    if [[ -f /etc/gdm/custom.conf ]] && grep -Eq '^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false' /etc/gdm/custom.conf; then
        warn "GDM has WaylandEnable=false; enabling Wayland sessions."
        sudo sed -i 's/^[[:space:]]*WaylandEnable[[:space:]]*=[[:space:]]*false/#WaylandEnable=false/' /etc/gdm/custom.conf
    fi

    # Bluetooth suspend/resume fix: reload the BCM4377 kernel module on
    # resume so the controller firmware is re-initialised (Apple Silicon).
    # See docs/features/bluetooth-suspend-resume.md for the full rationale.
    if [[ -f "$REPO/share/system-sleep/10-bluetooth-bcm4377.sh" ]]; then
        sudo mkdir -p /etc/systemd/system-sleep
        sudo cp "$REPO/share/system-sleep/10-bluetooth-bcm4377.sh" \
            /etc/systemd/system-sleep/10-bluetooth-bcm4377.sh
        sudo chmod 755 /etc/systemd/system-sleep/10-bluetooth-bcm4377.sh
        ok "  /etc/systemd/system-sleep/10-bluetooth-bcm4377.sh"
    fi
}

# ── labwc session registration ────────────────────────────────────────────────
# Optional: installs a Sumika Shell session on top of the OFFICIAL labwc
# compositor (stacking, wlroots-based; unmodified upstream build at
# /opt/labwc-upstream). Only installed when labwc is present; the Hyprland
# session (install_session_files) is untouched. The labwc-plus fork is not
# maintained here.
install_labwc_session() {
    echo
    info "Installing labwc session entry (Sumika Shell on labwc upstream)..."

    if ! command -v labwc >/dev/null 2>&1 && [[ ! -x /opt/labwc-upstream/usr/local/bin/labwc ]]; then
        warn "labwc not found; skipping labwc session entry."
        sudo rm -f /usr/share/wayland-sessions/sumika-labwc-upstream.desktop \
            /usr/local/bin/sumika-labwc-upstream-session
        return 0
    fi

    # labwc-workspace daemon: reports the active workspace over a unix
    # socket for the bar's workspaces module (Quickshell has no
    # ext-workspace API). Built from the vendored protocol XML.
    ( cd "${REPO}/labwc/tools/labwc-workspace" && make >/dev/null && make install >/dev/null )
    ok "  labwc-workspace daemon -> ~/.local/bin/labwc-workspace"

    sudo tee /usr/local/bin/sumika-labwc-upstream-session >/dev/null <<'EOF'
#!/bin/bash
set -e

export SUMIKA_SHELL_ROOT="__REPO_ROOT__"
export SUMIKA_FORCE_NO_UWSM=1
export XDG_CURRENT_DESKTOP=labwc
export XDG_SESSION_DESKTOP=sumika-labwc-upstream
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland,x11
export MOZ_ENABLE_WAYLAND=1
export PATH="${HOME}/.local/bin:${SUMIKA_SHELL_ROOT}/bin:/opt/labwc-upstream/usr/local/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

config_dir="${SUMIKA_SHELL_ROOT}/labwc"

if [[ ! -d "$config_dir" ]]; then
    echo "Sumika Shell labwc config not found: $config_dir" >&2
    exit 1
fi

exec labwc -C "$config_dir"
EOF
    sudo sed -i "s|__REPO_ROOT__|$REPO|g" /usr/local/bin/sumika-labwc-upstream-session
    sudo chmod +x /usr/local/bin/sumika-labwc-upstream-session
    ok "  /usr/local/bin/sumika-labwc-upstream-session"

    sudo tee /usr/share/wayland-sessions/sumika-labwc-upstream.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Sumika Shell (labwc upstream)
Comment=Sumika Shell labwc session with Quickshell (official labwc 0.20.1)
Exec=/usr/local/bin/sumika-labwc-upstream-session
Type=Application
DesktopNames=labwc
Keywords=stacking;wayland;compositor;
EOF
    ok "  /usr/share/wayland-sessions/sumika-labwc-upstream.desktop"
}

install_nixos_session_files() {
    echo
    info "Installing NixOS-compatible Sumika Shell helper scripts..."

    mkdir -p "$HOME/.local/bin"
    cat >"$HOME/.local/bin/uwsm-app" <<'EOF'
#!/bin/bash
set -e

if [[ ${SUMIKA_FORCE_NO_UWSM:-0} == 1 ]]; then
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
    ok "  Sumika Shell session is managed by NixOS services.displayManager.sessionPackages"
}

# ── Custom launcher installation ────────────────────────────────────────────────────
install_custom_launchers() {
    echo
    info "Installing custom launchers..."

    local src_config="${SUMIKA_SHELL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/sumika-shell}"
    local src_launchers="$src_config/launchers"
    local dst_apps="$HOME/.local/share/applications"

    if [[ ! -d "$src_launchers" ]]; then
        warn "Launcher source not found: $src_launchers; skipping"
        return 0
    fi

    mkdir -p "$dst_apps/icons"

    local count=0
    for desktop in "$src_launchers"/*.desktop; do
        [[ -f "$desktop" ]] || continue
        # Copy desktop file, expanding $HOME to the real home directory
        sed "s|\$HOME|$HOME|g" "$desktop" > "$dst_apps/$(basename "$desktop")"
        count=$((count + 1))
    done

    # Copy icons
    if [[ -d "$src_launchers/icons" ]]; then
        cp -r "$src_launchers/icons/"* "$dst_apps/icons/" 2>/dev/null || true
    fi
    ok "Installed $count launcher(s)."
}

# ── Print summary ─────────────────────────────────────────────────────────────
print_summary() {
    local login_manager="your display manager"
    if systemctl is-enabled sddm.service >/dev/null 2>&1; then
        login_manager="SDDM"
    elif systemctl is-enabled gdm.service >/dev/null 2>&1; then
        login_manager="GDM"
    fi
    echo "  1. Log out"
    echo "  2. In ${login_manager}, choose \"Sumika Shell\" from the session menu"
    echo "  3. Log in; Hyprland will load hypr/hyprland.lua and autostart Quickshell"
    echo
    echo "Useful commands:"
    echo "  hyprctl reload                              # Reload Hyprland config"
    echo "  $REPO/bin/sumika-restart               # (Re)start Quickshell apps"
    echo "  $REPO/bin/sumika-doctor                # Check runtime dependencies"
    echo "  journalctl --user -b | rg 'sumika|quickshell|Hyprland|hyprland'  # Runtime logs"
}

migrate_sumika_data() {
    info "Migrating user data to Sumika Shell paths."
    if ! sh "$REPO/scripts/sumika-migrate.sh"; then
        err "Sumika migration failed; refusing to replace runtime symlinks."
        return 1
    fi
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
    echo -e "${CYAN}  Sumika Shell installer${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo

    detect_distro
    echo

    if [[ "$runtime_only" == 1 ]]; then
        info "Runtime-only mode: repairing symlinks and runtime config."
        migrate_sumika_data || exit 1
        create_symlinks
        repair_runtime_config
        install_custom_launchers
        ok "Runtime repair complete."
        exit 0
    fi

    # Ask for confirmation
    echo "This installs dependencies for Sumika Core only:"
    echo "  - Hyprland ecosystem (compositor, idle, portal, color picker)"
    echo "  - Quickshell"
    echo "  - Audio (PipeWire, WirePlumber, pavucontrol)"
    echo "  - Network & Bluetooth (NetworkManager, nmtui, bluez — sumika-wifi-tui / sumika-bluetooth-tui)"
    echo "  - Display tools (brightnessctl, ddcutil, wlr-randr, grim, hyprsunset)"
    echo "  - Capture / recording (slurp region picker, wf-recorder screen record backend)"
    echo "  - Wayland clipboard transport (wl-clipboard)"
    echo "  - Power, polkit and GNOME Keyring"
    echo "  - Terminal (foot)"
    echo "  - Core tools (jq, curl, Python, ffmpeg)"
    echo "  - Fonts/icons (Noto, Nerd Fonts, Material Symbols)"
    echo "  - Qt/GTK integration"
    if [[ "$DISTRO_FAMILY" == "nixos" ]]; then
        echo "  - NixOS reference applications (browser, editor, media, office, graphics, display tools)"
        echo "  - chezmoi + GTK/GIO desktop-launch support"
    fi
    echo
    echo "Optional extensions install their own dependencies separately"
    echo "(screenshot/record reuse grim+slurp+wf-recorder from Core)."
    echo

    read -p "Proceed with installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    install_all_dependencies
    verify_core_dependencies
    # Migrate user data to Sumika Shell config/state directories FIRST,
    # before removing a retired ~/.config/omd repository symlink.
    # FAILURE IS FATAL so existing user data is never discarded.
    migrate_sumika_data || exit 1
    "$REPO/scripts/migrate-sumika-namespace"
    create_symlinks
    repair_runtime_config
    install_custom_launchers
    if [[ "$DISTRO_FAMILY" == "nixos" ]]; then
        install_nixos_session_files
    else
        install_session_files
        install_labwc_session
    fi
    print_summary
}

main "$@"
