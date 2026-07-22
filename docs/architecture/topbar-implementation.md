# Top Bar Runtime

The top bar runs in the independent `apps/omd-bar` Quickshell process. Core bar
layout is implemented under `quickshell/modules/bar/`; feature buttons are
loaded through the transitional registry.

## Window Model

`Bar.qml` creates one layer-shell `PanelWindow` per selected monitor. Each
window owns a `BarContent` instance and is hidden while the shell is locked or
the global bar state is closed. Bar IPC exposes `open`, `close`, and `toggle`.

The bar does not own feature services. It lays out registered contributions and
opens shared surfaces such as `BarStatusPopup`.

## Layout

`BarContent.qml` provides three slots:

```text
left                         center                         right
Workspaces + contributions  reserved centered slot        contributions
```

`Workspaces` is currently part of the bar frame. Other buttons are loaded from
`ModuleLoader.leftBarButtons` and `ModuleLoader.rightBarButtons`. A failed
`Loader` is disabled and logged so one contribution does not prevent the rest
of the bar from rendering.

The built-in manifest is `quickshell/registry/builtin/bar.json`. Each entry
declares a stable `id`, slot, QML component URL, numeric order, owning module,
and whether it ignores module enablement. Ordering belongs to registry data,
not a hard-coded QML button list.

During the Core/Plugin migration this registry becomes the `topbar-*`
extension API; see
[`sumika-core-plugin-migration-plan.md`](sumika-core-plugin-migration-plan.md).

## Shared Geometry

Right-side contributions use shared configuration tokens:

- `Config.options.bar.rightIconSlotWidth` for stable hit-area width;
- `Config.options.bar.rightIconSize` for glyph size;
- `Config.options.bar.rightModuleSpacing` for inter-module spacing;
- `Appearance.sizes.baseBarHeight` for bar height.

Feature buttons must not add asymmetric outer margins to compensate for a
glyph. Optical balancing belongs in `BarNerdIcon`; spacing belongs in the row.

## Interaction Contract

- Left click performs the primary action.
- Middle click may perform a documented secondary action.
- Right click opens a context menu only where the feature owns one.
- Wheel input is reserved for direct adjustments such as volume or brightness.

Status content is rendered by the single `BarStatusPopup.qml`; do not add
per-feature popup windows. Only one shared popup type may be active at a time.
Complex operations launch the feature's independent settings surface.

## Current Built-in Contributions

The checked-in registry currently includes application launcher, active
window, system tray, input method, audio, Wi-Fi, clipboard, session, display,
tools, clock, and sidebar indicators. This list is descriptive, not an API:
inspect `quickshell/registry/builtin/bar.json` for the effective order.

## Key Files

| Concern | File |
| --- | --- |
| Process entry | `apps/omd-bar/shell.qml` |
| Per-monitor window and IPC | `quickshell/modules/bar/Bar.qml` |
| Slot layout and failure containment | `quickshell/modules/bar/BarContent.qml` |
| Built-in contributions | `quickshell/registry/builtin/bar.json` |
| Registry loader | `quickshell/services/ModuleLoader.qml` |
| Unified status popup | `quickshell/modules/bar/BarStatusPopup.qml` |
| Style tokens | `quickshell/modules/common/TuiStyle.qml` |
| Icon geometry | `quickshell/modules/common/widgets/BarNerdIcon.qml` |

## Verification

```sh
bash scripts/reload-quickshell
qs -p ~/.config/omd/apps/omd-bar ipc call bar open
```

Verify every output, equal icon spacing, one-popup-at-a-time behavior, and that
an invalid optional contribution does not hide the other buttons.
