# Wallpaper Runtime Contract

Sumika imports the active wallpaper into stable machine-local state. Consumers
must never depend on the user's original file path.

## Paths

```text
~/.local/state/sumika-shell/wallpaper/
├── wallpaper       # managed image copy
├── background      # relative symlink -> wallpaper
├── revision        # cache invalidation token
├── mode            # file | folder | color
├── source          # selected source file/folder
├── interval        # rotation interval in seconds
└── renderer.log
```

All paths honor `SUMIKA_SHELL_STATE_HOME`. User configuration lives in
`~/.config/sumika-shell/sumika.json`; its `background.wallpaperPath` points to
`~/.local/state/sumika-shell/wallpaper/background`.

## Update Flow

`bin/omd-theme-bg-set <image>`:

1. validates the selected source;
2. atomically copies it to the managed `wallpaper` file;
3. repairs `background -> wallpaper`;
4. updates `revision` and the user configuration path;
5. asks `bin/omd-wallpaper` to render the managed image.

Folder rotation uses the same import path for every selected image. It changes
the managed file and revision, not the public path. `omd-wallpaper restore`
recreates both the renderer and the transient rotation timer after login.

## Renderer Ownership

The desktop is painted by `swaybg` in the dedicated transient user service
`omd-wallpaper-renderer.service`. Rotation runs separately as
`omd-wallpaper-random.service`. Keeping the renderer out of the short-lived
rotation cgroup prevents it from being killed as soon as a rotation command
exits.

If a user systemd manager is unavailable, the script falls back to a detached
`swaybg`. There must still be one renderer owner. Hyprland autostart calls
`omd-wallpaper restore`; no second autostart path may launch `swaybg` directly.

Monitor topology changes destroy layer surfaces. The monitor watcher therefore
calls `omd-wallpaper refresh-outputs` after output add/remove events settle.

## Consumer Rule

Overview thumbnails, empty workspaces, lock screen, color extraction, and
previews use `Config.options.background.wallpaperPath`. Long-running QML image
consumers must also observe `Wallpaper.revision`, because folder rotation keeps
the same path while replacing its contents.

Never introduce:

- a bundled fallback wallpaper that briefly flashes before the managed image;
- a direct reference to the imported source file;
- a second independent wallpaper renderer;
- state under `~/.config/omd/current` or `~/.local/state/omd`.

## Modes

- `file`: one imported image; no rotation timer.
- `folder`: persisted folder and interval; timer selects and imports images.
- `color`: renderer uses the current theme background color.

Changing the folder interval restarts the timer without changing `mode`.
`stop` intentionally changes folder mode to file mode and is not a generic
timer refresh operation.

## Diagnostics

```sh
~/.config/omd/bin/omd-wallpaper status
systemctl --user status omd-wallpaper-renderer.service
cat ~/.local/state/sumika-shell/wallpaper/renderer.log
readlink ~/.local/state/sumika-shell/wallpaper/background
```

A correct preview does not prove that the desktop renderer is healthy: the
preview reads the managed file, while the desktop also requires a live
`swaybg` surface on every output.
