# Settings Panels

OMD settings use focused, independent panels rather than one control center
with a permanent category sidebar. Opening display settings shows only display
controls; opening power settings shows only power controls.

The panels still share one visual and runtime foundation, so changing a token
or widget updates every panel.

## Runtime model

`bin/omd-settings` cold-starts the `apps/omd-settings` Quickshell process.
Only one panel is loaded at a time:

```sh
omd-settings open network
omd-settings open bluetooth
omd-settings open sound
omd-settings open display
omd-settings open appearance
omd-settings open power
omd-settings open system
omd-settings open voice
omd-settings open keyremap
omd-settings open windows
```

The process exits when its dialog is dismissed. If it is already running, IPC
switches the loaded panel without creating a second process. Historical aliases
such as `wifi`, `audio`, `battery`, `theme`, and `windows-vm` remain
supported by `SettingsDialog.normalizePage()`.

## Entry points

Status-related settings are opened directly from their corresponding bar
popup. Advanced tools are exposed through the wrench icon in the top bar:

```text
OMD Tools
├── Themes
├── Voice Input
├── Keyboard Remap
└── Windows VM
```

The application launcher also exposes a lightweight `OMD Tools` entry. It is
an entry directory, not a settings center and does not own feature state.

The top-bar implementation is:

```text
quickshell/modules/bar/modules/ToolsButton.qml
quickshell/modules/bar/BarStatusPopup.qml  # toolsContent
```

Do not create a separate popup window for each tool. Bar popup content remains
owned by `BarStatusPopup.qml`.

## Ownership

```text
quickshell/modules/settings/
├── SettingsDialog.qml          # lifecycle, panel routing, shared overlays
├── SettingsPanelFrame.qml      # border, title bar, drag, close, scroll area
├── SettingsTokens.qml          # palette mapped from TuiStyle/OmarchyTheme
├── widgets/                    # shared controls
├── pages/
│   ├── OverviewPage.qml        # lightweight OMD Tools launcher
│   ├── NetworkPage.qml         # network and Bluetooth modes
│   ├── AppearancePage.qml
│   ├── SoundPage.qml
│   ├── PowerPage.qml
│   ├── SystemPage.qml
│   ├── VoicePage.qml
│   ├── KeyboardRemapPage.qml
│   ├── KeyboardEditorOverlay.qml
│   └── WindowsVmPage.qml
├── display/                    # display-specific state and controls
└── wallpaper/                  # wallpaper picker
```

Feature logic belongs to its page or dedicated service. `SettingsDialog.qml`
must not accumulate new feature cards.

## Shared style contract

All settings panels use `SettingsPanelFrame.qml`, `SettingsTokens.qml`, and
the components in `settings/widgets/`:

```text
PageBody
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

Do not hard-code panel backgrounds, borders, accent colors, row heights, or
button chrome in a feature page when a shared token/widget can express it.

## Adding a panel

1. Add `pages/FooPage.qml` with a `settingsRoot` property.
2. Register it in `pages/qmldir`.
3. Add its metadata and loader mapping to `SettingsDialog.qml`.
4. Route the owning bar popup or tool entry to
   `omd-settings open <panel-key>`.
5. Keep visible external-program launches behind
   `settingsRoot.dismiss()`, because the settings surface is layer-shell and
   otherwise remains above normal application windows.
6. Cold-start the panel and check `/tmp/omd-settings.log`.

## Window behavior

`SettingsPanelFrame.qml` owns the common shell appearance and content
viewport. `SettingsDialog.qml` owns dialog size persistence and resize
handling. Losing focus does not close the panel; the close button, Escape, or Q
dismisses it.
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
`SettingsDialog.qml`.

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

The Appearance panel renders theme previews from the theme name plus the theme
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

This helper is the Windows VM panel backend for the full VM lifecycle:
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
progressPercent=...
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
