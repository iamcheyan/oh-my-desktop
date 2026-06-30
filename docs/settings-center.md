# Settings Center

OMD settings are being consolidated into a single Quickshell settings center
instead of many unrelated per-feature dialogs.

## Goal

The visual reference is COSMIC Settings:

- left category sidebar
- right content page
- rounded grouped cards
- quiet dark surfaces
- compact rows with trailing values or toggles
- accent only for selected navigation and enabled controls

The implementation remains QML/Quickshell. We do not import COSMIC's real
Rust/libcosmic widgets, because `cosmic-settings` is a Rust application built
on `libcosmic`/`iced`, not a QML component library.

## Runtime Entry

The settings center lives at:

```text
quickshell/modules/settings/SettingsCenter.qml
```

Top bar detailed dialogs are routed through:

```text
quickshell/modules/bar/BarDialogOverlay.qml
```

`GlobalStates.barDialogType` selects the initial settings page:

```text
wifi        -> Network & Wireless
bluetooth   -> Bluetooth
audio       -> Sound
nightlight  -> Displays
battery     -> Power & Battery
theme       -> Appearance
themes      -> Themes
wallpaper   -> Appearance
virtualization / vm / windows-vm -> Windows VM
settings    -> Overview
control     -> Overview
```

## Style Ownership

`SettingsCenter.qml` currently owns a small COSMIC-like token set:

```text
cosmicBg
cosmicPanel
cosmicPanelAlt
cosmicPanelHover
cosmicCard
cosmicCardHover
cosmicFg
cosmicMuted
cosmicDim
cosmicLine
cosmicAccent
cosmicAccentSoft
cosmicRadius
cosmicRoundRadius
```

Do not hand-style settings rows in each page. Use the local shared components
inside `SettingsCenter.qml`:

```text
SettingsNavItem
SettingsCard
SettingsRow
SettingsToggleRow
SettingsButton
SettingsIconButton
SettingsMeter
SettingsStatusPill
ButtonRow
```

If this design stabilizes, move those components into
`quickshell/modules/settings/widgets/` and keep the token source in one file.

## Window Behavior

`WindowDialog` now exposes `dragOffsetX` and `dragOffsetY`. Settings Center uses
those offsets from its title bar so the whole control center can be dragged
without changing how existing non-draggable dialogs are positioned.

## Migration Rule

New settings work should prefer this hierarchy:

1. Add or reuse a page in `SettingsCenter.qml`.
2. Add rows/cards using the shared settings components above.
3. Route top-bar "manage/settings" actions to the matching page via
   `GlobalStates.barDialogType`.
4. Keep small hover bubbles and lightweight status popups in
   `BarStatusPopup.qml`; keep actual configuration in Settings Center.

## Themes Page

The Themes page is backed by:

```text
bin/omd-settings-theme
```

That helper is intentionally thin. It lists and applies Omarchy themes while
leaving the real theme implementation in Omarchy's own scripts:

```text
share/bin/omarchy-theme-list
share/bin/omarchy-theme-current
share/bin/omarchy-theme-set
share/bin/omarchy-theme-bg-next
```

Theme list rows are tab-separated:

```text
slug<TAB>display-name<TAB>preview-path<TAB>current|available
```

Preview selection order:

```text
preview.png / preview.jpg / preview.jpeg / preview.webp / preview.gif / preview.bmp
first image in backgrounds/
```

Applying a theme calls:

```sh
~/.config/omd/bin/omd-settings-theme apply <theme-slug> with-wallpaper
```

If the user disables wallpaper switching, the helper calls `omarchy-theme-set`
with `OMARCHY_THEME_SKIP_BACKGROUND=1`.

## Windows VM Page

The Windows VM page is backed by:

```text
bin/omd-settings-windows-vm
```

It does not reimplement VM setup. It only exposes status and calls:

```text
share/bin/omarchy-windows-vm
```

Status is returned as simple `key=value` lines:

```text
configured=true|false
kvm=true|false
dockerCli=true|false
dockerRunning=true|false
compose=true|false
container=running|exited|missing|...
web=http://127.0.0.1:8006
composeFile=~/.config/windows/docker-compose.yml
storageDir=~/.windows
sharedDir=~/Windows
ram=...
cpu=...
disk=...
user=...
```

Install and remove are deliberately launched in an interactive terminal because
they involve large downloads, disk allocation, sudo/package operations, and
destructive deletion. The QML page adds a first confirmation click, and the
underlying `omarchy-windows-vm` script still performs its own terminal
confirmation.
