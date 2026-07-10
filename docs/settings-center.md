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
audio       -> Sound & Feedback
nightlight  -> Displays
battery     -> Power & Battery
theme       -> Appearance
themes      -> Appearance (alias)
wallpaper   -> Appearance
sounds      -> Sound & Feedback (alias)
osd         -> Notifications (alias)
session     -> Notifications (alias)
notifications -> Notifications
autostart   -> System (alias)
windowrules -> System (alias)
apps        -> System (alias)
virtualization / vm / windows-vm -> Windows VM
settings    -> Overview
control     -> Overview
```

## Navigation (primary + Advanced)

```text
Overview
Network & Wireless
Bluetooth
Sound & Feedback
Displays
Appearance
Power & Battery
Notifications
System
— Advanced —
  Voice Input
  Keyboard Remap
  Windows VM
```

## File layout

```text
quickshell/modules/settings/
├── SettingsCenter.qml          # shell: nav, search, overlays, loader routing
├── SettingsTokens.qml          # singleton palette (TuiStyle / OmarchyTheme)
├── widgets/                    # shared shell rows/cards/buttons
├── pages/
│   ├── OverviewPage.qml
│   ├── AppearancePage.qml      # themes + wallpaper + font
│   ├── SoundPage.qml           # audio devices + system sounds + audio OSD
│   ├── NotificationsPage.qml   # popups, history, clipboard, OSD position
│   ├── PowerPage.qml
│   └── SystemPage.qml          # autostart, window rules, default apps
└── display/                    # Displays page (separate module)
```

Network, Bluetooth, Voice, Keyboard Remap, and Windows VM remain inline
`Component` blocks in `SettingsCenter.qml` for now.

## Style Ownership

`SettingsTokens.qml` maps the settings palette from `TuiStyle` and
`OmarchyTheme`. Shell widgets under `settings/widgets/` consume `SettingsTokens`.

Do not hand-style settings rows in each page. Import shared widgets:

```text
qs.modules.settings.widgets.*
PageBody
SettingsNavItem
SettingsCard
SettingsRow
SettingsToggleRow
SettingsButton
SettingsIconButton
SettingsMeter
SettingsStatusPill
SettingsSlider
SettingsDropdownRow
SettingsTextFieldRow
ButtonRow
```

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

## Displays Page

The Displays page has been split out of the monolithic settings file:

```text
quickshell/modules/settings/display/
├── DisplayPage.qml
├── DisplayConfigState.qml
├── MonitorCanvas.qml
├── MonitorRect.qml
└── OutputCard.qml
```

This is an OMD adaptation of DankMaterialShell's display configuration design.
The parts we intentionally ported are:

- monitor preview canvas
- draggable monitor rectangles
- edge snapping and overlap checks
- per-output cards
- pending edits before applying
- resolution/refresh, scale, rotation, and position controls

The original DMS implementation depends on `WlrOutputService`,
`CompositorService`, `SettingsData`, DMS display profiles, and both Hyprland and
Niri backends. OMD does not run that daemon stack, so the state layer is adapted
for the current Omarchy + Hyprland session:

```text
hyprctl -j monitors all
hyprctl keyword monitor <name>,<mode>,<x>x<y>,<scale>,transform,<n>
```

Keep display-specific parsing and command generation in
`DisplayConfigState.qml`. Do not add new monitor layout logic directly to
`SettingsCenter.qml`.

Current scope:

- connected Hyprland outputs
- output arrangement by dragging preview rectangles
- mode, scale, transform, and position changes
- refresh and identify actions
- brightness, night light, and wallpaper entry points remain on the Displays
  page

Not yet ported from DMS:

- display profiles
- Niri backend
- disconnected-output preservation
- Hyprland-specific HDR/10-bit/VRR advanced controls
- rollback confirmation timer after applying monitor changes

If those are added later, prefer extending `DisplayConfigState.qml` and
`OutputCard.qml` instead of embedding feature-specific code in the settings
root.

## Appearance / Themes

Theme selection lives on the **Appearance** page (merged from the former
standalone Themes page). It is backed by:

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

Theme list rows are tab-separated. `preview-path` is retained for compatibility
but intentionally empty; the UI does not load preview images.

```text
slug<TAB>display-name<TAB>preview-path<TAB>current|available<TAB>accent<TAB>background<TAB>foreground
```

Settings Center renders theme previews from the theme name plus the theme
`accent`, `background`, and `foreground` color swatches. Do not add screenshot
or wallpaper preview dependencies to the Themes page.

Applying a theme calls:

```sh
~/.config/omd/bin/omd-settings-theme apply <theme-slug>
```

Theme switching never changes wallpaper. The helper always calls
`omarchy-theme-set` with `OMARCHY_THEME_SKIP_BACKGROUND=1`. Wallpaper selection
is owned by the Appearance page and `bin/omd-wallpaper`.

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
