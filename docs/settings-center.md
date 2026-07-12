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

## Layer-Shell & External Program Launch

The Settings Center runs as a Wayland **layer-shell** surface (`WlrLayer.Overlay`),
which is always rendered above normal toplevel windows. This means:

- Screenshot tools (`grim`, Hyprland thumbnails) do not capture it
- External programs launched from within the Settings Center appear **behind** it
  and are invisible to the user

To work around this, any `onClicked` handler that launches an external GUI/TUI
program must **dismiss the Settings Center first**:

```qml
onClicked: {
    root.dismiss();
    Quickshell.execDetached(["some-external-program"]);
}
```

For sub-pages that access the settings root via `settingsRoot`:

```qml
onClicked: {
    pageRoot.settingsRoot.dismiss();
    Quickshell.execDetached(["some-external-program"]);
}
```

### Current dismiss-on-launch locations

| File | Program | Trigger |
|---|---|---|
| `SettingsCenter.qml` | `blueman-manager` | Bluetooth Manager button |
| `SettingsCenter.qml` | `nm-connection-editor` | Connection Editor button |
| `SettingsCenter.qml` | `nmtui` (foot) | Network TUI button |
| `SettingsCenter.qml` | `omd-launch-tui voice-bind-tui` | Configure button |
| `SettingsCenter.qml` | `key-test-launcher --hotkey` | Capture Key button |
| `SettingsCenter.qml` | `omd-launch-tui voice-test-tui` | TUI Test button |
| `SettingsCenter.qml` | `omd-launch-tui voice-diagnose` | Diagnose button |
| `SettingsCenter.qml` | `omd-settings-windows-vm launch` | Connect button |
| `SettingsCenter.qml` | `omd-settings-windows-vm launch-keepalive` | Keep Alive button |
| `SoundPage.qml` | `pavucontrol` | Volume Control button |
| `DisplayPage.qml` | `wlr-randr` (foot) | wlr-randr button |
| `SystemPage.qml` | `xdg-open autostartDir` | Open Autostart Folder button |
| `SystemPage.qml` | `zenity` file picker | Set Default Browser button |

Do not add new external program launches without `dismiss()`. If the program
is a background command with no visible window (e.g. `hyprctl reload`,
`omd-wallpaper`, `notify-send`), `dismiss()` is unnecessary.

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

This helper is the Settings Center backend for the full Windows VM lifecycle:
status, resource checks, one-click default install, start, connect, stop,
logs, web console, and confirmed removal. The old interactive
`share/bin/omarchy-windows-vm` script is no longer the Settings page contract.

Status is returned as simple `key=value` lines:

```text
configured=true|false
storagePresent=true|false
storageUsedBytes=...
kvm=true|false
dockerCli=true|false
dockerDaemon=true|false
dockerAccess=true|false
dockerSocket=true|false
dockerGroupMember=true|false
dockerError=...
compose=true|false
freerdp=true|false
freerdpBin=...
container=running|exited|missing|...
phase=not-installed|downloading|preparing|installing|booting|ready|error|stopped
ready=true|false
webReachable=true|false
rdpReachable=true|false
web=http://127.0.0.1:8006
rdpPort=3389
rdpEndpoint=127.0.0.1:3389
rdpPortBusy=true|false
rdpPortConflict=true|false
composeFile=~/.config/windows/docker-compose.yml
storageDir=~/.windows
sharedDir=~/Windows
diskAvailable=...
ramTotal=...
cpuTotal=...
ram=...
cpu=...
disk=...
user=...
```

Primary commands used by the page:

```text
status
install-status
auto-fix
install-defaults
start
launch
launch-keepalive
stop
remove --yes
logs
web
```

Install is non-interactive after the user clicks the Settings button. The
helper picks conservative defaults: roughly half RAM capped at 16G, half CPU
cores capped at 8, 128G disk when space allows, user `win11`, and password
`admin` unless an existing compose file already defines credentials.

RDP defaults to `127.0.0.1:3389`, but the helper checks for host port conflicts
before writing or starting the compose file. If another service such as `xrdp`
already owns 3389, the VM is moved to the first free fallback port in the
3390-3400 range and the Settings page shows the actual `rdpEndpoint`.

Removal is destructive because it deletes the VM storage directory. The QML page
requires a two-step remove click before invoking `remove --yes`.
