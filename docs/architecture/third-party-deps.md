# Core Third-Party Dependencies

This document is the dependency contract for the Sumika Shell Core product
floor. `Init.sh` installs only these dependencies. Optional extensions under
`~/.local/share/sumika-shell/extensions/` own their packages, Python modules,
daemons, permissions, and setup instructions.

## Required Core Commands

|Capability|Commands|Why Core needs them|
|---|---|---|
|Session|`Hyprland`, `hyprctl`, `hypridle`|Compositor, IPC, and idle handling|
|Shell|`qs` / `quickshell`|Runs the bar, Overview, settings, and polkit agent|
|Audio|`wpctl`|Volume and mute actions; PipeWire is the audio backend|
|Network|`nmcli`, `bluetoothctl`|Wi-Fi and Bluetooth services and TUIs|
|Display|`brightnessctl`, `wlr-randr`, `grim`, `hyprpicker`|Brightness, output configuration, display previews, and color picking|
|Clipboard transport|`wl-copy`|Core Wi-Fi password copy action|
|Desktop integration|`foot`, `zenity`, `notify-send`, `secret-tool`|Core TUI host, browser picker, notifications, and keyring storage|
|Runtime tooling|`jq`, `curl`, `python3`, `systemd-run`|Registry/config processing, media artwork, Core Python TUIs, and process supervision|

PipeWire, WirePlumber, NetworkManager, BlueZ, polkit, GNOME Keyring, and the
desktop portals are required services even when their command-line tools are
not called directly from QML.

## Optional Core Capabilities

These are installed by default because they complete a Core feature, but Core
starts without them:

|Command|Capability without it|
|---|---|
|`ddcutil`|External-monitor DDC/CI brightness is unavailable|
|`hyprsunset`|Night-light controls are unavailable|
|`pavucontrol`|The advanced audio mixer link is unavailable|
|`ffplay`|UI event sounds are silent|
|`nmtui`|Enterprise/fallback network configuration is unavailable|
|`nm-connection-editor`|The advanced network editor link is unavailable|

`grim` is a Core dependency, not a screenshot-extension dependency: the
brightness service uses it for per-output preview frames.

## Core Fonts

Core QML directly requests:

- `MesloLGS Nerd Font Mono`
- `JetBrainsMono Nerd Font Mono`
- `Material Symbols Rounded`
- Noto Sans/CJK and Noto Color Emoji as fallbacks

`Init.sh` uses distribution packages for Noto and installs the three
project-specific UI fonts into `~/.local/share/fonts/sumika-shell/` when the
requested families are not already available.

## Extension-Owned Dependencies

The Core installer deliberately does not install the following. They belong to
the extension that uses them:

|Extension|Typical dependencies excluded from Core|
|---|---|
|Clipboard|`cliphist`, smart-paste helpers|
|Input method|Fcitx5 and its GTK/Qt frontends|
|Keyboard remap|`keyd`, GTK key-capture dependencies, polkit rule|
|Screenshot/OCR|`slurp`, `swappy`/`satty`, OCR Python packages|
|Voice input|`parecord`, `ydotool`/`wtype`, speech-model Python packages|
|File backup|`rsync`, Samba tools, backup polkit rule|
|Windows VM|QEMU/libvirt, RDP/Looking Glass tools|
|Theme settings|Wallpaper/theme assets and `swaybg`|

An extension may reuse a Core dependency such as `python3`, `curl`, `grim`, or
`wl-copy`, but that does not make its additional dependency set part of Core.

## Distribution Support

`Init.sh` normalizes packages for these families:

|Family|Package manager|Status|
|---|---|---|
|Arch, Manjaro, EndeavourOS, CachyOS|`pacman`|Supported|
|Fedora/RHEL family|`dnf`|Supported; repositories are added only when the required package is absent|
|Debian/Ubuntu family|`apt`|Best effort; recent Hyprland and Quickshell packages may require a newer release or an external repository|
|openSUSE Tumbleweed/Slowroll|`zypper`|Best effort; some Hyprland ecosystem packages may require `X11:Wayland`|
|NixOS|declarative configuration|Supported through the generated NixOS block|

The installer verifies commands after package installation. It stops with an
explicit missing-command list instead of reporting success after a package
manager silently skipped an unavailable package.

Package names that intentionally differ by family include:

|Normalized|Debian/Ubuntu|Fedora|Arch|openSUSE|
|---|---|---|---|---|
|NetworkManager|`network-manager`|`NetworkManager`|`networkmanager`|`NetworkManager`|
|PipeWire Pulse|`pipewire-pulse`|`pipewire-pulseaudio`|`pipewire-pulse`|`pipewire-pulseaudio`|
|Power Profiles API|`power-profiles-daemon`|`tuned-ppd`|`power-profiles-daemon`|`power-profiles-daemon`|
|Qt Wayland|`qt6-wayland`|`qt6-qtwayland`|`qt6-wayland`|`libqt6-qtwayland`|
|Kvantum Qt6|`qt-style-kvantum`|`kvantum`|`kvantum`|`kvantum-qt6`|
|Keyring CLI|`libsecret-tools`|`libsecret`|`libsecret`|`libsecret-tools`|

Run `bin/sumika-doctor` after installation. Its required checks cover only
Core; it reports installed extensions without treating their private
dependencies as Core failures.
