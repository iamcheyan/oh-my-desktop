# Custom Launchers

This directory holds custom desktop entries that show up in the OMD App
Launcher. Each entry is a standard `.desktop` file; the install script copies
them into `~/.local/share/applications/`, which the launcher's cache already
scans — no QML changes needed.

## Layout

```
launchers/
├── README.md                 This file
├── remote-desktop.desktop    Example entry
└── icons/
    └── remote-desktop.png    Icons referenced by entries (use $HOME paths)
```

## Adding a new launcher

1. Drop a `.desktop` file in this directory. Reference repo paths with
   `$HOME/.config/omd/...` — the install script expands `$HOME` to the real
   home directory.

   ```desktop
   [Desktop Entry]
   Name=My App
   Comment=Short description
   Exec=$HOME/.config/omd/scripts/my-app
   Icon=$HOME/.config/omd/launchers/icons/my-app.png
   Terminal=false
   Type=Application
   Categories=System;Utility;
   ```

2. Put the icon in `launchers/icons/` and point `Icon=` at it.

3. Install it:

   ```sh
   ./scripts/install-launchers
   ```

   Use `--dry` to preview without writing:

   ```sh
   ./scripts/install-launchers --dry
   ```

The App Launcher refreshes its cache on next open (or in the background shortly
after opening), so new entries appear automatically.

## How it works

- `scripts/install-launchers` copies every `launchers/*.desktop` into
  `~/.local/share/applications/`, expanding `$HOME`, and copies
  `launchers/icons/*` into `~/.local/share/applications/icons/`.
- `Init.sh` calls `install_custom_launchers` on first setup and on
  `--runtime-only` re-runs, so re-running `./Init.sh --runtime-only` refreshes
  all entries after you add or edit them.

## Example

`remote-desktop.desktop` launches `scripts/remote-desktop` (RDP to
192.168.3.65). After `./scripts/install-launchers` it appears in the App
Launcher as "Remote Desktop".
