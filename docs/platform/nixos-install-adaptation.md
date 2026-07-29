# NixOS Installation

Sumika Shell Core is installed declaratively on NixOS. `Init.sh` adds a
marked Sumika block to `/etc/nixos/configuration.nix`, validates it with
`nixos-rebuild dry-build`, and only then applies it. A timestamped backup is
restored if validation or activation fails.

The generated configuration is intentionally Core-only. Clipboard history,
input methods, keyboard remapping, screenshots/OCR, voice input, backup,
virtual machines, and theme management are extensions and must declare their
own NixOS packages and services.

## Core configuration

The generated block enables:

- Hyprland and the Hyprland/GTK desktop portals
- Quickshell
- PipeWire, Pulse compatibility, WirePlumber, and realtime scheduling
- NetworkManager and Bluetooth
- polkit, GNOME Keyring, and power-profiles-daemon
- I2C access for optional DDC/CI monitor brightness
- the `Sumika Shell` display-manager session

It installs the commands listed in
[Core third-party dependencies](../architecture/third-party-deps.md), plus the
Qt Wayland/Kvantum integration and Core fonts.

Run:

```sh
cd ~/development/OMD
./Init.sh
```

After the rebuild, log out and select **Sumika Shell** from the display
manager. Re-running `Init.sh --runtime-only` repairs the repository symlink and
runtime configuration without changing NixOS packages.

## Manual verification

```sh
bin/sumika-doctor
hyprctl monitors
qs --version
wpctl status
nmcli general status
bluetoothctl show
```

`ddcutil` is optional at runtime. If it cannot access an external display,
verify that `hardware.i2c.enable = true`, reconnect the monitor, and start a
new login session.

## Extensions

Do not add extension dependencies to the Core block merely because an
extension is installed on one machine. Keep them in a separate NixOS module or
Home Manager module associated with that extension. Examples:

|Extension|Typical NixOS additions|
|---|---|
|Clipboard|`cliphist`, any smart-paste transport it selects|
|Input method|Fcitx5 plus the desired addons and frontend integration|
|Keyboard remap|`keyd`, its service, permissions, and GTK capture libraries|
|Screenshot/OCR|`slurp`, an annotation editor, and OCR packages|
|Voice input|Pulse recording tools, paste transport, and model/runtime packages|
|Theme settings|Wallpaper renderer and theme assets|
|Windows VM|libvirt/QEMU and the selected remote-display clients|

An extension may reuse Core commands such as `python3`, `grim`, `wl-copy`, or
`curl`; only its additional requirements belong in the extension module.

## Existing generated block

`Init.sh` does not rewrite an existing Sumika-marked block automatically,
because modifying arbitrary Nix expressions is unsafe. If the dependency
contract changes, compare the current block in `Init.sh` with
`/etc/nixos/configuration.nix`, update the marked block manually, then run:

```sh
sudo nixos-rebuild dry-build
sudo nixos-rebuild switch
bin/sumika-doctor
```
