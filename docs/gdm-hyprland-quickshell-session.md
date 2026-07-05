# GDM Hyprland + Quickshell Session

OMD registers a dedicated GDM Wayland session named `Oh My Desktop`.
Select it from the GDM gear menu to start Hyprland with this repository's
Omarchy config and split Quickshell processes.

## Installed By Init.sh

`Init.sh` performs these session steps after package install and runtime
symlink creation:

- On Fedora/RHEL-family systems, enables the `ashbuk/Hyprland-Fedora` COPR for
  Fedora 43 Hyprland packages and `errornointernet/quickshell` for Quickshell.
- Creates `~/.local/bin/uwsm-app` as a compatibility wrapper. In the OMD
  session it runs commands directly instead of requiring a full `uwsm` session.
- Creates `/usr/local/bin/omd-hyprland-session`.
- Creates `/usr/share/wayland-sessions/oh-my-desktop.desktop` for GDM.
- Re-enables GDM Wayland sessions if `/etc/gdm/custom.conf` explicitly has
  `WaylandEnable=false`.

The session wrapper exports:

```sh
OMD_ROOT="$HOME/.config/omd"
OMARCHY_PATH="$HOME/.local/share/omarchy"
OMARCHY_CONFIG="$HOME/.config/omarchy"
OMD_FORCE_NO_UWSM=1
OMARCHY_FORCE_NO_UWSM=1
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_DESKTOP=oh-my-desktop
XDG_SESSION_TYPE=wayland
```

It then starts Hyprland with:

```sh
~/.config/omarchy/hypr/hyprland.lua
```

On Fedora, it prefers `start-hyprland -- -c <config>` when available and falls
back to `Hyprland -c <config>`.

## Runtime Chain

1. GDM launches `/usr/local/bin/omd-hyprland-session`.
2. Hyprland loads `~/.config/omarchy/hypr/hyprland.lua`.
3. `omarchy/hypr/autostart.lua` runs `~/.config/omd/bin/omd-restart`.
4. `omd-restart` starts the split Quickshell apps:

```sh
omd-bar
omd-desktop
omd-overview
omd-applauncher
omd-corners
omd-clipboard
omd-clipboard-store
```

## Verification

After running `bash Init.sh`, check:

```sh
test -x ~/.local/bin/uwsm-app
test -x /usr/local/bin/omd-hyprland-session
test -f /usr/share/wayland-sessions/oh-my-desktop.desktop
command -v Hyprland || command -v hyprland
command -v quickshell
```

If already inside the OMD session, check:

```sh
pgrep -a Hyprland
pgrep -af 'quickshell|qs -p'
hyprctl monitors
```

For failures:

```sh
journalctl --user -b --no-pager | rg 'omd|quickshell|Hyprland|hyprland|uwsm|failed|ERROR'
```

## Verified On 2026-07-05

Fedora 43 Workstation was verified with:

```sh
bash Init.sh
Hyprland --verify-config -c ~/.config/omarchy/hypr/hyprland.lua
timeout 25s /usr/local/bin/omd-hyprland-session
```

Observed runtime state from the nested Hyprland test instance:

- `Hyprland --verify-config` returned `config ok`.
- `start-hyprland` launched Hyprland with
  `~/.config/omarchy/hypr/hyprland.lua`.
- `hyprctl -j monitors` reported a `WAYLAND-1` monitor.
- `hyprctl -j layers` showed `quickshell:background` and `quickshell:bar`,
  proving `omarchy/hypr/autostart.lua` started OMD's split Quickshell apps.
