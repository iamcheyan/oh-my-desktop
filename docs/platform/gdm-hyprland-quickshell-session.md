# GDM Hyprland + Sumika Session

`Init.sh` installs a dedicated Wayland session named **Oh My Desktop**. The
technical name remains unchanged while the public shell name is Sumika Shell.

## Installed Files

- `/usr/local/bin/omd-hyprland-session`
- `/usr/share/wayland-sessions/oh-my-desktop.desktop`
- `~/.local/bin/uwsm-app` compatibility wrapper

The session wrapper exports `SUMIKA_SHELL_ROOT` and compatibility `OMD_ROOT`
as the physical repository path, then launches:

```sh
start-hyprland -- -c <repo>/hypr/hyprland.lua
```

It falls back to `Hyprland -c` or `hyprland -c` when needed and sets native
Wayland environment variables for Qt, GTK, and Firefox.

## Runtime Chain

1. GDM starts `/usr/local/bin/omd-hyprland-session`.
2. Hyprland loads `<repo>/hypr/hyprland.lua`.
3. Repository defaults and overrides load before optional
   `~/.config/sumika-shell/hypr/*.lua` user overrides.
4. `hypr/autostart.lua` starts `bin/omd-restart` and restores wallpaper state.
5. Required Quickshell processes start; cold-start features remain stopped
   until invoked.

Do not point the session at retired `~/.config/omarchy/hypr` or
`~/.config/hypr` trees.

## Verification

```sh
test -x /usr/local/bin/omd-hyprland-session
test -f /usr/share/wayland-sessions/oh-my-desktop.desktop
Hyprland --verify-config -c ~/.config/omd/hypr/hyprland.lua
pgrep -a Hyprland
pgrep -af 'quickshell|qs -p'
hyprctl monitors
~/.config/omd/bin/omd-doctor
```

For login failures:

```sh
journalctl --user -b --no-pager | rg 'omd|sumika|quickshell|Hyprland|failed|ERROR'
```

Re-run `Init.sh` after moving the repository because the installed wrapper
stores the physical repository path.
