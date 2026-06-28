# TUI Style System

OMD Quickshell surfaces use `quickshell/modules/common/TuiStyle.qml` as the
single style token source for the current GNOME Shell inspired dark UI.

Do not add new `Appearance.tiling` usage. Do not hard-code new shell colors in
feature modules unless the value is genuinely content-specific.

## Token Ownership

`TuiStyle.qml` owns these style groups:

```text
Base palette        bg, panel, panelAlt, fg, dim, line
Semantic aliases    accent, success, warning, info, muted, danger
Shell chrome        shellGradientTop/Mid/Bottom, shellBorder, shellRadius
Interior surfaces   surfaceSubtle, surfaceRaised, surfaceHover, surfacePressed
Controls            control, controlHover, controlMuted, controlActiveBorder
Mini controls       miniControlHover, miniControlPressed, miniRadius
Meters              meterTrack
Separators          dividerOpacity
Layout              borderWidth, radius, panelPadding, rowHeight, buttonHeight
```

When changing the global look, start in `TuiStyle.qml`. Feature files should
compose these tokens instead of declaring their own palette.

## Shared Components

Prefer these shared components for new UI:

```text
TuiShell          outer shell/dialog surface
WindowDialog      right/top anchored detailed dialogs
TuiActionButton   primary text actions
TuiMeterBar       battery/volume/brightness meters
TuiDetailRow      key/value rows
TuiSegmentedTabs  segmented tab controls
```

If a new component needs a color that does not exist in `TuiStyle.qml`, add a
named token there first. Avoid duplicating literals such as `#181818`,
`#303030`, `#8f8f8f`, or ad-hoc opacity values in feature modules.

## Current Migration State

The main active UI surfaces have been migrated to `TuiStyle`:

```text
BarStatusPopup
ControlCenterContent
BluetoothDialog
WifiDialog
NightLightDialog
VolumeDialog
ClipboardDialog / ClipboardItem
AppLauncher
OverviewSearch
WindowDialog
TuiMeterBar / TuiActionButton / notification widgets
common config widgets
```

`Appearance.tiling` is considered retired for runtime QML. It may still appear
in old documentation only as historical context.

## Review Checklist

Before finishing a style change:

```sh
rg -n "Appearance\\.tiling" quickshell apps -g '*.qml'
rg -n "#[0-9A-Fa-f]{6,8}|Qt\\.rgba\\(" quickshell/modules apps -g '*.qml'
git diff --check -- quickshell apps docs
~/.config/omd/bin/omd-restart
```

Hard-coded colors in `TuiStyle.qml` itself are expected. Hard-coded colors in
feature modules should be justified or moved into `TuiStyle.qml`.
