# Sumika Shell — Custom Launchers
#
# This directory holds personal desktop entries.  The .desktop files reference
# scripts from ~/.config/sumika-shell/scripts/ and icons from
# ~/.config/sumika-shell/launchers/icons/.
#
# Init.sh's install_custom_launchers() copies these to
# ~/.local/share/applications/ on each setup or --runtime-only run.
#
# Personal scripts are managed through chezmoi at ~/.config/sumika-shell/scripts/
# and are NOT tracked in the Sumika Shell repository.

## Layout

```
launchers/
├── README.md                 This file
├── keepassxc.desktop         Example entry
├── remote-desktop.desktop    Example entry
├── wechat.desktop            Example entry
├── wps.desktop               Example entry
└── icons/
    ├── keepassxc.png
    ├── remote-desktop.png
    ├── wechat.png
    └── wps.png
```

## Adding a new launcher

1. Drop a `.desktop` file in this directory with these paths (Init.sh expands $HOME):

   ```desktop
   [Desktop Entry]
   Name=My App
   Comment=Short description
   Exec=$HOME/.config/sumika-shell/scripts/my-app
   Icon=$HOME/.config/sumika-shell/launchers/icons/my-app.png
   Terminal=false
   Type=Application
   Categories=System;Utility;
   ```

2. Put the icon in `icons/` and the launch script in `~/.config/sumika-shell/scripts/`.

3. Run `Init.sh --runtime-only` to install to `~/.local/share/applications/`.

The App Launcher refreshes its cache on next open, so new entries appear
automatically.

## How it works

- `Init.sh`'s install_custom_launchers() copies every `launchers/*.desktop`
  into `~/.local/share/applications/`, expanding `$HOME`, and copies icons
  into `~/.local/share/applications/icons/`.
- Personal scripts must be placed in `~/.config/sumika-shell/scripts/` by the
  user or via chezmoi.  The repository only ships the .desktop source definitions.

## Existing launchers

| .desktop | Script | Purpose |
|----------|--------|---------|
| `keepassxc.desktop` | `~/.config/sumika-shell/scripts/keepassxc` | KeePassXC via Flatpak |
| `remote-desktop.desktop` | `~/.config/sumika-shell/scripts/remote-desktop` | RDP to 192.168.3.65 |
| `wechat.desktop` | `~/.config/sumika-shell/scripts/wechat` | WeChat via Flatpak |
| `wps.desktop` | `~/.config/sumika-shell/scripts/wps` | WPS 365 via Flatpak |
