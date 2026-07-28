# Third-Party Dependencies

All external programs used by Sumika Shell, grouped by feature. Technical
commands and package identifiers use the `sumika` prefix.

## Hyprland Core

| Program | Purpose | Required |
|---|---|---|
| `hyprland` | Wayland compositor | Yes |
| `hyprctl` | Hyprland control CLI | Yes |
| `hypridle` | Idle management | Yes |
| `hyprpicker` | Color picker | Yes |
| `swaybg` | Wallpaper renderer | Yes |
| `xdg-desktop-portal-hyprland` | Portal backend | Yes |

## Network

| Program | Purpose | Required |
|---|---|---|
| `nmcli` | NetworkManager CLI (WiFi scan/connect) | Yes |
| `nmtui` | NetworkManager TUI (WiFi config) | Optional |
| `nm-connection-editor` | NetworkManager GUI editor | Optional |
| `bluetoothctl` | Bluetooth control CLI | Optional |
| `blueman-manager` | Bluetooth GUI manager | Optional |

## Audio

| Program | Purpose | Required |
|---|---|---|
| `pamixer` | PulseAudio volume control | Yes |
| `playerctl` | Media player control | Yes |
| `pavucontrol` | PulseAudio volume GUI | Optional |
| `ffplay` | System sound playback (from ffmpeg) | Optional |
| `parecord` | Audio recording (voice input) | Optional |

## Display / Brightness

| Program | Purpose | Required |
|---|---|---|
| `brightnessctl` | Backlight brightness control | Yes |
| `ddcutil` | External monitor brightness (DDC/CI) | Optional |
| `wlr-randr` | Transactional output mode, scale, rotation, and layout control | Yes |

## Screenshot / Screen Record

| Program | Purpose | Required |
|---|---|---|
| `grim` | Wayland screenshot tool | Yes |
| `slurp` | Region selector | Yes |
| `swappy` | Screenshot annotation | Optional |
| `satty` | Screenshot annotation (alt to swappy) | Optional |
| `wl-screenrec` | Screen recording | Optional |

## Clipboard

| Program | Purpose | Required |
|---|---|---|
| `wl-copy` | Wayland clipboard write | Yes |
| `wl-paste` | Wayland clipboard read | Yes |
| `cliphist` | Clipboard history manager | Yes |

## Input / Keyboard

| Program | Purpose | Required |
|---|---|---|
| `ydotool` | Input simulation (auto-paste) | Optional |
| `keyd` | Keyboard remapping daemon | Optional |

## Terminal

| Program | Purpose | Required |
|---|---|---|
| `foot` | Default terminal emulator | Yes |
| `kitty` | Alternative terminal | Optional |

## Session / Power

| Program | Purpose | Required |
|---|---|---|
| `systemctl` | Systemd control (suspend/hibernate) | Yes |
| `loginctl` | Login session control | Yes |
| `polkit-gnome` | Polkit authentication agent | Yes |

## Nightlight

| Program | Purpose | Required |
|---|---|---|
| `hyprsunset` | Blue light filter | Optional |

## Utilities

| Program | Purpose | Required |
|---|---|---|
| `jq` | JSON processing | Yes |
| `curl` | HTTP requests | Yes |
| `git` | Version control | Yes |
| `ripgrep` | Fast text search | Yes |
| `fish` | Default shell | Yes |
| `xdg-open` | Open files/URLs | Yes |
| `notify-send` | Desktop notifications | Yes |
| `zenity` | GTK dialog boxes | Optional |
| `kdialog` | KDE dialog boxes | Optional |
| `mkdir` | Directory creation | Yes |
| `rm` | File deletion | Yes |
| `cat` | File reading | Yes |
| `cp` / `mv` | File copy/move | Yes |
| `date` | Date/time formatting | Yes |
| `sleep` | Delay | Yes |
| `pidof` | Process detection | Yes |
| `pkill` | Process termination | Yes |
| `killall` | Kill all instances | Yes |
| `cmp` | File comparison | Yes |
| `tee` | Split output | Yes |
| `awk` | Text processing | Yes |

## Fonts

| Font | Purpose |
|---|---|
| Cantarell | Main UI font |
| Noto Sans | Fallback UI font |
| Noto Sans CJK | CJK support |
| Noto Color Emoji | Emoji support |
| JetBrainsMono Nerd Font | Monospace + icons |
| MesloLGS Nerd Font | Monospace UI |
| Material Symbols | Material icons |
| Font Awesome | Awesome icons |

## Package Names by Distro

### Fedora

| Normalized Name | Fedora Package |
|---|---|
| network-manager | NetworkManager |
| network-manager-wifi | NetworkManager-wifi |
| network-manager-tui | NetworkManager-tui |
| network-manager-editor | nm-connection-editor |
| pavucontrol | pavucontrol |
| brightnessctl | brightnessctl |
| ddcutil | ddcutil |
| wlr-randr | wlr-randr |
| swaybg | swaybg |
| grim | grim |
| slurp | slurp |
| swappy | swappy |
| satty | satty |
| wl-clipboard | wl-clipboard |
| cliphist | cliphist |
| foot | foot |
| kitty | kitty |
| ffplay | ffmpeg-free |
| hyprsunset | hyprsunset |
| keyd | keyd |
| blueman | blueman |
| jq | jq |
| curl | curl |
| git | git |
| ripgrep | ripgrep |
| fish | fish |
| ydotool | ydotool |
| python3 | python3 |
| python3-pip | python3-pip |
| fontconfig | fontconfig |
| unzip | unzip |
| cantarell-fonts | abattis-cantarell-vf-fonts |
| noto-fonts | google-noto-sans-vf-fonts |
| noto-cjk-fonts | google-noto-sans-cjk-vf-fonts |
| noto-emoji-fonts | google-noto-color-emoji-fonts |
| jetbrains-mono-nerd-fonts | jetbrains-mono-fonts-all |
| font-awesome | fontawesome-6-free-fonts |
| qt6-wayland | qt6-qtwayland |
| qt5-wayland | qt5-qtwayland |
| adwaita-qt5 | adwaita-qt5 |
| gnome-themes-extra | gnome-themes-extra |
| xdg-desktop-portal-gtk | xdg-desktop-portal-gtk |
| kdialog | kdialog |
| zenity | zenity |
| qt6ct | qt6ct |
| kvantum | kvantum |
| nautilus | nautilus |
| evince | evince |
| plasma-systemmonitor | plasma-systemmonitor |
| power-profiles-daemon | power-profiles-daemon |
| polkit-gnome | polkit-gnome |
| gnome-keyring | gnome-keyring |
| mako | mako |

### Debian / Ubuntu

| Normalized Name | Debian Package |
|---|---|
| network-manager | network-manager |
| network-manager-wifi | network-manager |
| network-manager-tui | network-manager-tui |
| network-manager-editor | network-manager-gnome |
| pavucontrol | pavucontrol |
| brightnessctl | brightnessctl |
| ddcutil | ddcutil |
| wlr-randr | wlr-randr |
| swaybg | swaybg |
| grim | grim |
| slurp | slurp |
| swappy | swappy |
| satty | satty |
| wl-clipboard | wl-clipboard |
| cliphist | cliphist |
| foot | foot |
| kitty | kitty |
| ffmpeg | ffmpeg |
| hyprsunset | hyprsunset |
| keyd | keyd |
| blueman | blueman |
| jq | jq |
| curl | curl |
| git | git |
| ripgrep | ripgrep |
| fish | fish |
| ydotool | ydotool |
| python3 | python3 |
| python3-pip | python3-pip |
| fontconfig | fontconfig |
| unzip | unzip |
| cantarell-fonts | fonts-cantarell |
| noto-fonts | fonts-noto-core |
| noto-cjk-fonts | fonts-noto-cjk |
| noto-emoji-fonts | fonts-noto-color-emoji |
| jetbrains-mono-nerd-fonts | fonts-jetbrains-mono |
| font-awesome | fonts-font-awesome |
| qt6-wayland | qt6-wayland |
| qt5-wayland | libqt5waylandclient5 |
| adwaita-qt5 | adwaita-qt |
| gnome-themes-extra | gnome-themes-extra |
| xdg-desktop-portal-gtk | xdg-desktop-portal-gtk |
| kdialog | kdialog |
| zenity | zenity |
| qt6ct | qt6ct |
| kvantum | qt5-style-kvantum |
| nautilus | nautilus |
| evince | evince |
| plasma-systemmonitor | plasma-systemmonitor |
| power-profiles-daemon | power-profiles-daemon |
| polkit-gnome | polkit-gnome |
| gnome-keyring | gnome-keyring |
| mako | mako |

### Arch Linux

| Normalized Name | Arch Package |
|---|---|
| network-manager | networkmanager |
| network-manager-wifi | networkmanager |
| network-manager-tui | networkmanager |
| network-manager-editor | nm-connection-editor |
| pavucontrol | pavucontrol |
| brightnessctl | brightnessctl |
| ddcutil | ddcutil |
| wlr-randr | wlr-randr |
| swaybg | swaybg |
| grim | grim |
| slurp | slurp |
| swappy | swappy |
| satty | satty |
| wl-clipboard | wl-clipboard |
| cliphist | cliphist |
| foot | foot |
| kitty | kitty |
| ffmpeg | ffmpeg |
| hyprsunset | hyprsunset |
| keyd | keyd |
| blueman | blueman |
| jq | jq |
| curl | curl |
| git | git |
| ripgrep | ripgrep |
| fish | fish |
| ydotool | ydotool |
| python3 | python3 |
| python3-pip | python-pip |
| fontconfig | fontconfig |
| unzip | unzip |
| cantarell-fonts | cantarell-fonts |
| noto-fonts | noto-fonts |
| noto-cjk-fonts | noto-fonts-cjk |
| noto-emoji-fonts | noto-fonts-emoji |
| jetbrains-mono-nerd-fonts | ttf-jetbrains-mono-nerd |
| font-awesome | ttf-font-awesome |
| kvantum | kvantum-qt5 |
