# Appearance Settings Layout

Date: 2026-07-15

## Goal

Align Appearance (theme / wallpaper / terminal font / effects) with the
Display / Voice / Windows VM master–detail layout:

- left: **theme** (primary visual choice)
- right: **wallpaper, terminal font, performance**
- demote folder paths and long explanations

## Target Layout

```text
wide (≥980)
├── left · Themes
│   ├── hero (current name + swatches)
│   └── theme grid (click to apply)
└── right · Desktop & terminal
    ├── wallpaper preview + choose image/folder
    ├── rotation controls (folder mode)
    ├── terminal font size + apply
    └── performance / effects

footer: Close
```

## Notes

- Theme apply remains immediate via `omd-settings-theme apply`.
- Wallpaper uses existing picker (`settingsRoot.openWallpaperPicker`).
- Local `parseKeyValue` / `fileUrl` helpers on the page (do not rely on missing
  SettingsDialog methods).
- File: `quickshell/modules/settings/pages/AppearancePage.qml`
