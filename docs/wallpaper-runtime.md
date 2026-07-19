# Wallpaper Runtime Contract

OMD imports the selected wallpaper into a stable, machine-local runtime file:

```text
~/.config/omd/current/wallpaper   # copied image, ignored by Git
~/.config/omd/current/background  # relative symlink -> wallpaper
```

The source selected by the user is only an import source. Moving, renaming, or
deleting it after selection must not affect the active desktop.

## Update Flow

`bin/omd-theme-bg-set <image>` performs the update:

1. Validate and resolve the selected source image.
2. Copy it to a temporary file beside `current/wallpaper`.
3. Atomically replace `current/wallpaper`.
4. Repair the relative `current/background -> wallpaper` link.
5. Publish an ignored runtime revision at
   `~/.config/omd/current/wallpaper.revision`, then store the stable path in
   Quickshell config.
6. Restart `swaybg` with the stable path.

Folder rotation uses the same import function for every selected image. Its
mode, source folder, and interval are stored under
`~/.local/state/omd/wallpaper/`. Hyprland autostart runs
`omd-wallpaper restore`, which first starts `swaybg` with the existing managed
image and then recreates the transient user-systemd timer when the persisted
mode is `folder`. Restoring only the timer is insufficient: previews can still
read the image file while the real desktop remains unpainted.

All image and solid-color renderer launches go through `bin/omd-wallpaper`.
The renderer is a directly detached `swaybg` process rather than an
`uwsm-app` scope, so wallpaper restoration does not depend on user D-Bus being
ready during early Hyprland startup. Renderer stderr is retained in
`~/.local/state/omd/wallpaper/renderer.log` instead of being discarded.
There must be exactly one autostart owner: `hypr/autostart.lua` invokes
`omd-wallpaper restore`; default Hyprland modules must not launch another
`swaybg` process directly.

Hyprland destroys and recreates output surfaces when a monitor is connected,
removed, or re-enabled. `omd-hyprland-monitor-watch` therefore coalesces
`monitoradded*` and `monitorremoved*` event bursts and invokes
`omd-wallpaper refresh-outputs` after the topology settles. This recreates
`swaybg` for every active output while preserving the selected source, folder
mode, interval, and current timer deadline. A preview updating successfully is
not proof that the desktop renderer covers every output: previews read the
managed image file, while the desktop requires a live layer surface per output.

The interval file is read directly whenever the timer is created. Changing the
interval uses `omd-wallpaper restart`; it must not use `stop`, because `stop`
is the explicit user action that changes the persisted mode from `folder` to
`file`.

## Consumer Rule

Wallpaper consumers must use `Config.options.background.wallpaperPath`, whose
runtime value is the stable `current/background` path. This includes overview
workspace thumbnails, lock screen, color extraction, and future previews.
Do not retain or introduce direct paths to the original imported file.

Because the stable path does not change during folder rotation, long-running
Quickshell image consumers must also depend on `Wallpaper.revision` (or use
`Wallpaper.versionedUrl(path)`). The ignored revision file changes on every
successful wallpaper import, forcing Qt to decode the new contents instead of
returning a cached image for the unchanged path. This runtime value must not be
stored in the tracked `quickshell/config.json`.

Overview naturally falls back to the active theme's background color when the
managed file cannot be decoded or when solid color mode is active. `Init.sh`
seeds the managed file from the default theme's wallpaper during first setup
or runtime repair. The overview process's 1x1 keepalive `PanelWindow` owns a
transparent `Image` that decodes the versioned wallpaper independently of the
on-demand workspace widget. The `Wallpaper` singleton publishes the requested
and last-ready URLs, while workspace previews reuse Qt's decoded image cache.
When the revision changes, `Wallpaper.readyUrl` retains the last successfully
decoded revision until the replacement is ready. The preloader must remain in
a real window: an `Image` owned only by a singleton may never enter a scene
graph and therefore may never load. This avoids both a black frame and a
default-wallpaper flash without retaining window screencopy resources while
overview is closed.

## Repository Rule

`current/background` is tracked because it is a portable relative symlink.
`current/wallpaper` and `current/wallpaper.revision` are ignored because they
contain machine-local runtime data; the wallpaper may also be large or private.
