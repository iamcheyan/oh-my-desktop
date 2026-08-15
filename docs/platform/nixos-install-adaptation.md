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

## Distro-assumption audit and fixes (2026-08-15, host `nixos-new`)

A full audit against a fresh NixOS 26.05 install (no merged `/usr`, `/bin`
contains only `sh`, quickshell at `/run/current-system/sw/bin`) found five
breakage classes. Four were fixed in this repository; the fifth is
declarative host config, recorded below.

### 1. Absolute `#!/bin/bash` shebangs — 33 scripts dead

NixOS has no `/bin/bash`. Any script invoked by absolute path failed with
ENOENT, including the voice extension's NixOS LD_LIBRARY_PATH wrappers (their
`omarchy-voice-setup`/`omarchy-voice-download` implementation scripts were the
actual offenders). All changed to `#!/usr/bin/env bash`:

- `bin/`, `share/bin/` (lock, logout, wake, 14 hyprland toggles, launchers,
  notification wrapper), `share/system-sleep/`
- `quickshell/modules/{wifi,audio}/bin/` TUI and mute/switch helpers
- `Init.sh` (first line **and** the four heredocs that generate `uwsm-app`
  and the session wrappers)

Rule: shell scripts in this repo MUST use `#!/usr/bin/env <shell>`, never an
absolute interpreter path.

### 2. systemd unit issues

- `share/systemd/sumika-session-save.service`: `ExecStart=/bin/true` failed
  203/EXEC (no `/bin/true`; bare `true` is also not PATH-resolved in
  `ExecStart=` on this systemd). Now `/bin/sh -c true` — `/bin/sh` is the one
  path guaranteed on every layout. Without this, the save-on-session-end
  `ExecStop` never ran.
- `sumika-wallpaper` (theme-settings extension): transient
  `systemd-run` units do not inherit the session PATH, so the bare
  `sumika-theme-bg-set` sibling call exited 127 every rotation tick. The
  script now bootstraps its own directory into `PATH`. Lesson for every
  extension script launched from a transient unit: self-bootstrap `PATH`.

### 3. Quickshell binary resolution and process patterns

- `sumika-screenshot` (and the rebuilt `website/downloads/sumika-ext-screenshot.tar.gz`):
  qs probing now covers `/run/current-system/sw/bin` and falls back to
  `command -v`, fixing edit/OCR/record cold start.
- `bin/sumika-restart`: pgrep/pkill patterns now match `(quickshell|qs)`, not
  just `quickshell`, so bar reload cannot stack instances when only one binary
  name exists.
- `share/bin/sumika-launch-tui`: terminal fallbacks (`kitty --class`,
  `foot --app-id`, …) now carry the app-id, so `hypr/looknfeel.lua`
  `sumika_tui_ids` float rules match without `xdg-terminal-exec` (absent on
  this host).

### 4. Hardcoded `/usr/share` data paths

`Directories.qml` `cosmicIcons` now resolves via the last `/share` entry of
`XDG_DATA_DIRS` (system-wide prefix: `/usr/share` on Arch,
`/run/current-system/sw/share` on NixOS). Verified both ways with a minimal
qs instance.

## Host config additions (extension dependencies)

Applied to `~/nixos-config` (flake; host `nixos-new` = `modules/*.nix`):

|Change|Purpose|
|---|---|
|`modules/desktop.nix`: `cosmic-icons`|OSD volume/brightness indicator icons|
|`modules/desktop.nix`: `glib`|`gdbus` for PowerProfiles + input-method Rime schema switching|
|`hosts/nixos-new`: import `modules/keyd.nix`|keyboard-remap extension daemon|
|`hosts/nixos-new`: `freerdp`, `cifs-utils`, `docker-compose`|windows-vm RDP client, SMB mounts (backup polkit path), VM provisioning|
|`hosts/nixos-new`: `virtualisation.docker.enable` + user in `docker` group|windows-vm docker backend|
|`modules/keyd.nix`: tmpfiles `d/f /etc/keyd`|the extension installs `/etc/keyd/sumika.conf` imperatively via pkexec; a `preStart` mkdir inside the unit fails EROFS (`ProtectSystem=strict`), so the directory is created declaratively|
|`modules/keyd.nix`: `CapabilityBoundingSet` + SETGID/SETUID|keyd self-demotes at startup; module default bounding set is insufficient|
|`modules/core.nix`: `zramSwap` (zstd, 50%, prio 100)|no zram by default → cold pages sat on the NVMe swap partition and refaulting them caused visible stalls; disk swap kept as spill|
|`modules/desktop.nix`: `amdgpu-dpm.service` + udev AC rule|Cezanne iGPU sclk oscillated 400↔1750 MHz on `auto` while compositing 4K@scale2 (frame jitter); pins `high` on AC, `auto` on battery|

`musubi` (file-backup TUI) is built from `~/development/musubi` with
`go build -ldflags "-s -w" -o bin/musubi ./cmd/musubi` and installed to
`~/.local/bin` (no `make` on this host). The repo's committed binary is
aarch64 — rebuild when moving between architectures.

Rebuild command for this host:

```sh
NIX_CONFIG='experimental-features = nix-command flakes' \
  /run/wrappers/bin/pkexec nixos-rebuild switch --flake ~/nixos-config#nixos-new
```

(`pkexec`/`sudo` must be invoked via `/run/wrappers/bin` — PATH may resolve
the non-setuid store copies first.)

Membership in the `docker` group only takes effect at next login.

## Known remaining limitations on NixOS

- `Updates.qml` counts updates via Arch's `checkupdates` (pacman-contrib).
  On NixOS the badge is gracefully absent; a nix-native check is future work.
- OCR auto-install (`pip install paddleocr onnxruntime`) installs manylinux
  wheels without a loader path. `programs.nix-ld.enable = true` (already in
  `modules/core.nix`) makes the venv import path work; first run still needs
  the pip bootstrap.
- ~~`sumika_tui_ids` stale short names~~ — fixed 2026-08-15: every extension
  launcher now delegates to the unified `sumika-launch-tui` (app-id derived
  from the TUI filename; `-a` override for non-script commands such as
  `$EDITOR config` and the standalone musubi binary). All derived ids are
  registered; legacy short names kept for any un-migrated install.
- `bin/sumika-doctor`'s SDDM PAM probe misses NixOS-declared PAM — its
  keyring warning is a false positive here.
- The BCM4377 bluetooth suspend/resume hook installs only inside the
  non-NixOS session-file path; declare it in NixOS config if that hardware
  applies.

## Polkit GUI agent: kirigami / Qt5Compat QML resolution (2026-08-15)

Symptom: `sumika-polkit.service` crash-looped (`restart counter` climbing)
since first login, and every `pkexec` from a non-TTY context failed with
`Error creating textual authentication agent` — no GUI dialog ever appeared.

Root cause chain:

1. The agent app's shared widgets (`RippleButton` → Breeze `Button.qml`)
   import `org.kde.kirigami` and `Qt5Compat.GraphicalEffects`.
2. `QT_QPA_PLATFORMTHEME=kde` (plasma6 platform theme) activates the Breeze
   Quick style, making that import path load — with `qt6ct`/kvantum the
   default style is used and the imports never resolve, which is why manual
   shell tests passed while the session-launched agent crashed.
3. Neither module is resolvable through the profile join:
   - `org/kde/kirigami` in `/run/current-system/sw/lib/qt-6/qml` is a
     **styles-only stub from libplasma** that wins the symlink-join over the
     real module (`lib.setPrio` does not help — the join picks the whole
     subtree).
   - `kdePackages.kirigami` itself evaluates to a **wrapper stub** containing
     only `nix-support/`; the real module lives at
     `kdePackages.kirigami.unwrapped`.
   - `Qt5Compat` is not propagated by the quickshell wrapper and no profile
     carries it.

Fix (in `modules/desktop.nix`):

```nix
environment.sessionVariables.QML2_IMPORT_PATH = lib.concatStringsSep ":" [
  "${pkgs.kdePackages.kirigami.unwrapped}/${pkgs.qt6.qtbase.qtQmlPrefix}"
  "${pkgs.kdePackages.qt5compat}/${pkgs.qt6.qtbase.qtQmlPrefix}"
];
```

The qt module appends the profile-relative entries after these, so the real
modules shadow the poisoned join. Verified end-to-end after
`switch-to-configuration switch`: agent stable (`NRestarts=0`), `pkexec`
pops the GUI dialog. Note the registration window: an auth request issued
within ~10 s of agent start can still fall back to the textual agent.

Related extension-side fix: `keyboard-remap/bin/sumika-settings-keyboard`
resolved its `omarchy-keyboard-*` helpers against the session-wide
`SUMIKA_SHELL_ROOT` (the core repo, which does not ship them) — the TUI's
Apply action failed with "No such file or directory". All five call sites now
resolve from `SCRIPT_DIR`; the legacy `profiles.json` fallback paths in
`omarchy-keyboard-apply`/`-render` and the TUI derive from the extension root
instead of the repo root as well.
