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
5. Store `~/.config/omd/current/background` in Quickshell config.
6. Restart `swaybg` with the stable path.

Folder rotation uses the same import function for every selected image.

## Consumer Rule

Wallpaper consumers must use `Config.options.background.wallpaperPath`, whose
runtime value is the stable `current/background` path. This includes overview
workspace thumbnails, lock screen, color extraction, and future previews.
Do not retain or introduce direct paths to the original imported file.

Overview additionally falls back to
`quickshell/assets/images/default_wallpaper.png` when the managed file cannot be
decoded. `Init.sh` seeds the managed file from that default during first setup
or runtime repair.

## Repository Rule

`current/background` is tracked because it is a portable relative symlink.
`current/wallpaper` is ignored because it contains machine-local user data and
may be large or private.
