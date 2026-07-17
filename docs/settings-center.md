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

The detailed geometry and spacing rules are documented in
[`settings-layout-system.md`](settings-layout-system.md). The Displays panel is
the reference implementation for a wide two-column page.

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
├── OutputSummaryCard.qml
└── OutputDetailPane.qml
```

This is an OMD adaptation of DankMaterialShell's display configuration design.
The parts we intentionally ported are:

- monitor preview canvas
- draggable monitor rectangles
- edge snapping and overlap checks
- selectable output summaries
- pending edits before applying
- resolution/refresh, scale, rotation, and position controls

The page uses a responsive master-detail layout:

```text
wide window
├── left: physical arrangement canvas and display selection
└── right: controls for the selected display

narrow window
├── physical arrangement canvas and display selection
└── controls for the selected display
```

The canvas and output list share `DisplayPage.selectedOutputName`; they must
never maintain independent selections. Resolution and refresh rate are shown
as separate controls even though Hyprland applies them as one mode string.
Position coordinates and diagnostic tools are kept in the collapsed Advanced
section.

Display changes are one transaction. The page has exactly one Discard action
and one Apply action, both operating on `DisplayConfigState` drafts. Do not add
per-output Apply buttons or restore the generic `SettingsPanelFrame` Confirm
footer on this page.

The original DMS implementation depends on its Go daemon's
`WlrOutputService`, `CompositorService`, `SettingsData`, display profiles, and
multiple compositor backends. OMD does not run that daemon stack. Instead,
`bin/omd-display-config` uses `wlr-randr`, which is a small client for the same
`wlr-output-management` protocol used by the DMS Go backend:

```text
DisplayConfigState.qml
  -> omd-display-config get
       -> wlr-randr --json
       -> merge Hyprland focused-output metadata
  -> omd-display-config apply <complete layout>
       -> validate every output and value
       -> wlr-randr --dryrun <complete layout>
       -> wlr-randr <complete layout>
       -> wlr-randr --json and verify every requested value
       -> write ~/.local/state/omd/display/layout.lua
       -> hypr/monitors.lua reads it on startup or config reload
```

The helper exposes the current mode as `currentMode` and the complete mode
catalog as `modes`; the QML adapter also accepts Hyprland's legacy
`availableModes` field as a fallback. Refresh rates retain millihertz precision
internally because the protocol requires an exact advertised-mode match (for
example, `59.951Hz` is not interchangeable with `59.950Hz`). Scale presets run
from 100% through 400% in consistent 25% increments.

This preserves the useful DMS behavior without importing its entire daemon:

- the compositor receives all output changes as one configuration
- invalid configurations are tested before changing the screens
- command success alone is not accepted; reported live state must match
- startup persistence is written only after live verification succeeds
- the monitor module is loaded with `dofile`, so a later `hyprctl reload`
  reads the newest machine-local layout instead of a cached Lua module
- mode data comes from the output-management protocol instead of reconstructed
  values from unrelated UI state
- Identify Displays uses the DMS multi-output overlay pattern: one click-through
  overlay per screen with connector, display name, and physical resolution

Display geometry has one invariant: every enabled output belongs to one
edge-connected layout and no two logical rectangles overlap. Dragging always
chooses the nearest legal shared-edge position; it does not stop snapping after
an arbitrary distance. Changing resolution, scale, rotation, or advanced
coordinates reflows the remaining outputs around the changed output so an old
shared edge cannot become a gap or overlap. The backend validates the same
invariant before its compositor dry run.

Logical boundaries use the same nearest-integer calculation as Hyprland's
`CMonitor::m_size`. Scale choices start at 100% and stay on the 25% grid. Each
choice shows both the familiar UI preset and the clean scale Hyprland can
actually apply, for example `175% · actual 166.67%`. OMD submits the displayed
actual value and computes monitor attachment from that value, so Hyprland does
not silently change the scale after positions have already been calculated.
If Hyprland's bounded search cannot find a clean scale, the preset remains
visible as `unavailable` and cannot be selected.

Hyprland searches scale values on a 1/120 grid. It starts from the requested
value and checks the next higher candidate before the equally distant lower
candidate. The result depends on the active physical mode; it is not a global
percentage table. For the two displays used during development, presets from
100% through 300% resolve as follows:

| UI preset | 3840x2160 actual | 3024x1964 actual |
| ---: | ---: | ---: |
| 100% | 100% | 100% |
| 125% | 125% | 133.33% |
| 150% | 150% | 133.33% |
| 175% | 166.67% | 200% |
| 200% | 200% | 200% |
| 225% | 240% | 200% |
| 250% | 250% | 200% |
| 275% | 266.67% | unavailable |
| 300% | 300% | unavailable |

Changing resolution rebuilds this mapping because a different physical mode
has a different set of clean divisors. The draft stores the UI preset and the
effective compositor scale separately, which also lets the Apply button treat
two presets mapping to the same actual value as a real user edit.
The selected preset is persisted in
`~/.local/state/omd/display/layout.json` alongside the effective scale, while
`layout.lua` remains the Hyprland startup configuration. This preserves labels
such as `175% · actual 166.67%` after reopening the settings panel.

The footer uses an edit-session dirty flag: it starts disabled, remains enabled
after any user edit even when a control is returned to its original value, and
is cleared only by Apply or Discard. After a verified display transaction, the
applied values become the new baseline and the settings process runs
`scripts/reload-quickshell --quickshell-only`. Display changes invalidate
layer-shell geometry, so all persistent OMD Quickshell processes are recreated
against the new output layout; Hyprland is not reloaded a second time and the
on-demand settings window is intentionally closed by that reload.

The wildcard Hyprland monitor rule is registered before saved per-output rules.
Hyprland resolves monitor rules newest-first, so this order keeps the wildcard
as a fallback instead of allowing it to override the persisted layout during a
configuration reload.

Keep display draft and canvas logic in `DisplayConfigState.qml`, and keep
protocol/command validation in `bin/omd-display-config`. Do not add monitor
layout logic directly to `SettingsDialog.qml`.

Current scope:

- connected outputs exposed through `wlr-output-management`
- output arrangement by dragging preview rectangles
- mode, scale, transform, and position changes
- refresh and identify actions
- direct display configuration remains isolated from brightness, night light,
  and wallpaper popup controls

Not yet ported from DMS:

- display profiles
- Niri backend
- disconnected-output preservation
- Hyprland-specific HDR/10-bit/VRR advanced controls
- rollback confirmation timer after applying monitor changes

If those are added later, prefer extending `DisplayConfigState.qml` and
`OutputDetailPane.qml` instead of embedding feature-specific code in the
settings root.

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

The connect action is intentionally simple: before launching FreeRDP it focuses
a new empty Hyprland workspace, then starts FreeRDP normally. Hyprland's
`xfreerdp` app rule keeps the RDP session fullscreen and inhibits idle while
Windows is open. The helper does not manually resize or move the RDP window
after launch, and it does not pass FreeRDP's own `/f` fullscreen flag.

Removal is destructive because it deletes the VM storage directory. The QML page
requires a two-step remove click before invoking `remove --yes`.
