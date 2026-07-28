# WiFi & Bluetooth TUI (portable notes)

Lightweight curses frontends for everyday Linux desktops.

| Tool | Backend | Launch |
|------|---------|--------|
| `bin/sumika-wifi-tui` | NetworkManager (`nmcli`) | `bin/sumika-launch-wifi` |
| `bin/sumika-bluetooth-tui` | BlueZ (`bluetoothctl`) | `bin/sumika-launch-bluetooth` |

## Requirements

- Python **3.10+**
- **WiFi:** NetworkManager + `nmcli` (`systemctl enable --now NetworkManager`)
- **Bluetooth:** BlueZ + `bluetoothctl` (`systemctl enable --now bluetooth`)
- Optional: `rfkill`, Nerd Font (icons), a terminal emulator

## Quick test

```sh
python3 bin/sumika-wifi-tui
python3 bin/sumika-bluetooth-tui
```

Missing deps print an install hint and exit non-zero (no traceback).

## What works out of the box

- WPA2 / WPA3-PSK, open WiFi, saved profiles, disconnect, forget
- Bluetooth scan / pair / trust / connect / disconnect / remove
- Legacy PIN display (keyboard pairing) via bluetoothctl agent
- Non-English locales (tools forced to `C.UTF-8` for stable parsing)
- Soft-blocked radio: best-effort `rfkill unblock` + radio power on

## Not supported (use system tools)

- Pure **iwd** without NetworkManager → use [impala](https://github.com/pythops/impala)
- **802.1X / enterprise** WiFi → `nmtui` or GNOME/KDE settings
- Hidden SSID, hotspot/AP mode, VPN
- Multiple Bluetooth adapters (uses default controller)

## Multi-monitor brightness

`Init.sh` runs `setup_ddcutil_permissions` so external panels can be controlled:

- installs **ddcutil** + loads **i2c-dev**
- creates **i2c** group, adds the install user
- installs `/etc/udev/rules.d/60-sumika-ddcutil-i2c.rules` (`GROUP=i2c`, `MODE=0660`)
- best-effort `setfacl` on current `/dev/i2c-*` (works before re-login)

Brightness keys and the bar **Display** popup only change the **focused / bar’s monitor**.  
After first install: log out/in once (group membership), then `sumika-restart` if needed.

## Keys (both)

| Key | Action |
|-----|--------|
| `j`/`k` or arrows | Move |
| `Tab` / `h`/`l` | Next/prev section |
| `Enter` | Connect / disconnect / pair |
| `s` | Scan |
| `q` / `Esc` | Quit |

WiFi also: `t` radio on/off, `f` forget, `d` disconnect.  
Bluetooth also: `t` trust, `u`/`f` unpair/forget, `d` disconnect.
