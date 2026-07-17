# Top Bar (omd-bar) Implementation

This document explains how the OMD top bar is built, what is shown on it, the
exact left-to-right order of elements, and which icon fonts are used. It maps
directly to the code under `quickshell/modules/bar/` and `apps/omd-bar/`.

## 1. Process & window model

- The bar runs as its own Quickshell process: `apps/omd-bar/shell.qml`,
  launched via `bin/omd-bar` (part of the `omd-restart` app split).
- `Bar.qml` defines a `Scope` that creates **one `PanelWindow` per monitor**
  using `Variants { model: Quickshell.screens }`. A `screenList` config option
  can restrict which monitors get a bar.
- Each bar window is a Wayland layer-shell (`WlrLayershell.namespace:
  "quickshell:bar"`), `exclusionMode: Ignore`, so it does not reserve space by
  default. It is positioned at the top (or bottom via `Config.options.bar.bottom`).
- The bar is toggleable: hidden when `GlobalStates.barOpen` is false or when
  `GlobalStates.screenLocked` is true. It exposes an IPC handler `bar` with
  `toggle / open / close`, plus global shortcuts `barToggle`, `barOpen`,
  `barClose`.
- Background: a `Rectangle` (`#000000` opaque when `bar.showBackground`, else
  transparent), with rounded corners and optional drop shadow depending on
  `bar.cornerStyle` (0 = hug screen edges, 1 = floating with gaps). A
  `RoundCorner` decorator draws the screen-edge corners in hug mode.

Key geometry (from `Appearance.qml` + `config.json`):

| Token | Value | Meaning |
| --- | --- | --- |
| `Appearance.sizes.baseBarHeight` | 32 px | Bar height (doubles via gaps in cornerStyle 1) |
| `Config.options.bar.rightIconSlotWidth` | 28 px | Square hit area of each right-side icon |
| `Config.options.bar.rightIconSize` | 20 px | Drawn icon size |
| `Config.options.bar.rightModuleSpacing` | 8 px | Gap between right-side modules |
| `barSidePadding` | 10 px | Inner left/right padding |

## 2. Layout: three sections

`BarContent.qml` arranges content into three regions inside each bar window:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ [Applications]  [Workspaces]  [ActiveWindow title]        (center empty)   │
│                                            [tray] [IM] [audio] [wifi]      │
│                                            [clip] [sess] [disp] [tools]    │
│                                            [clock] [sidebar indicators]    │
└──────────────────────────────────────────────────────────────────────────┘
   LEFT (left-aligned)              CENTER (empty spacer)   RIGHT (right-aligned)
```

- **Left section** — a `RowLayout` (`leftSectionRowLayout`, spacing 14, left
  padding 10): `AppLauncherButton`, `Workspaces`, `ActiveWindow`.
- **Center section** — an empty `Item` used only to horizontally center the
  layout; no widgets are placed there by default.
- **Right section** — a `FocusedScrollMouseArea` containing `rightSectionRowLayout`
  (spacing = `rightModuleSpacing`), right-aligned: `SysTray`, `InputMethodButton`,
  `AudioButton`, `WifiButton`, `ClipboardButton`, `SessionButton`,
  `DisplayButton`, `ToolsButton`, `ClockWidget`, `SidebarIndicators`.

## 3. Left side, in order

### 3.1 Applications — `AppLauncherButton.qml`
- A `BarTextButton` showing the text **"Applications"** (no icon; uses the main
  UI font). Clicking runs `~/.config/omd/bin/omd-applauncher toggle` (opens the
  app launcher / overview launcher).

### 3.2 Workspaces — `Workspaces.qml`
- A `BarTextButton` showing the text **"Workspaces"**. Clicking toggles the
  overview via `qs -p .../apps/omd-overview ipc call overview toggle`.
- (Note: this is a labeled text button, not a per-workspace dot strip. The
  workspace pager itself lives in the overview.)

### 3.3 ActiveWindow — `ActiveWindow.qml`
- Shows the focused window's **icon + title** for the active workspace, or
  "Desktop" when none.
- Icon: tries `AppSearch.iconSource(AppSearch.guessIcon(windowClass))` (an
  `IconImage` from app `.desktop` icons); falls back to an OS distro SVG at
  `~/.config/omd/icons/OS/<distro>.svg` (e.g. `fedora`, `arch`, `ubuntu`,
  `nixos`, …). If even that fails, a single capital letter from the app id/title
  is drawn.
- Title is a `StyledText` (weight 500), width-capped (default 280 px), ellipsized.
- On narrow screens it shortens / hides (`barShortenScreenWidthThreshold` /
  `barHellaShortenScreenWidthThreshold`).

## 4. Right side, in order

All right-side icons sit in fixed 28×28 slots. Most use a `RippleButton`
background (transparent, light highlight on hover/toggle) with a `BarNerdIcon`
glyph centered inside, except where noted.

| # | Module | File | Default icon (Nerd font) | Popup / action |
| --- | --- | --- | --- | --- |
| 1 | **SysTray** | `SysTray.qml` | native tray icons + a `MaterialSymbol` `keyboard_arrow_down` overflow chevron | Click chevron → overflow grid of unpinned tray items |
| 2 | **InputMethod** | `InputMethodButton.qml` | `NerdIconMap.keyboard` (idle) / `mic` (voice) / `hourglass` (transcribing) | Toggles voice input or opens input-method popup |
| 3 | **Audio** | `AudioButton.qml` | `volumeHigh/Low/Off/Muted` from `NerdIconMap` based on level + mute | Opens `audio` popup (volume/mic/device) |
| 4 | **Wifi** | `WifiButton.qml` | `Network.nerdIcon` (wifi strength / wired / off) | Opens `wifi` popup (networks) |
| 5 | **Clipboard** | `ClipboardButton.qml` | `NerdIconMap.contentPaste` (`fa-clipboard`) | Launches `omd-clipboard toggle-at-bar` |
| 6 | **Session** | `SessionButton.qml` | `NerdIconMap.workspaceSnapshot` (`fa-archive`) | Opens `session` popup (snapshot/restore) |
| 7 | **Display** | `DisplayButton.qml` | `NerdIconMap.desktop` (`fa-desktop`) | Single click (timer) → display popup; **double click** → screenshot; right/alt → screenshot menu; scroll → brightness |
| 8 | **Tools** | `ToolsButton.qml` | `NerdIconMap.wrench` (`fa-wrench`) | Opens `tools` popup (utilities) |
| 9 | **Clock** | `ClockWidget.qml` | text only, no glyph | Click → `notifications` popup; hover → `ClockHoverPopup` |
| 10 | **SidebarIndicators** | `SidebarIndicators.qml` | `HyprlandXkbIndicator` (keyboard layout) + battery glyph | xkb popup / `battery` popup; right-click power → `PowerContextMenu` |

### 4.1 Notes per module
- **InputMethodButton** is stateful: when voice input is active it swaps the
  keyboard glyph for a mic, recolors it (recording = amber `#F5C542`,
  transcribing = blue `#5B9BD5`, error = red), pulses a ring while recording,
  and rotates the icon while transcribing. When voice UI is idle it shows a
  small badge with the current input-method engine label.
- **AudioButton** supports mouse-wheel volume up/down (no popup needed).
- **DisplayButton** scroll adjusts brightness for *that bar's monitor only*.
- **SidebarIndicators** is itself a mini-row: it contains the keyboard-layout
  indicator (`HyprlandXkbIndicator`, visible only when active) and a battery
  icon (`BarBatteryIcon`, falling back to `NerdIconMap.powerSettingsNew` when no
  battery is available). The battery icon set is driven by `NerdIconMap`
  (battery10…batteryFull, batteryCharging*, etc.).
- **SysTray** uses the **Material Symbols** font for its chevron and "no items"
  placeholder, and renders real tray item icons via `SysTrayItem`.

## 5. Icon fonts used

The bar mixes three icon sources:

1. **Nerd Font (primary bar glyphs)** — `JetBrainsMono Nerd Font Mono`
   (config `appearance.fonts.iconNerd`). Used by `NerdIcon.qml` and
   `BarNerdIcon.qml` for essentially every right-side module icon.
   - Glyph codepoints are centralized in `NerdIconMap.qml` (a singleton `QtObject`
     of named constants). Examples: `volumeHigh = \uF028` (fa-volume-high),
     `wifi4 = \uDB82\uDD28` (mdi-wifi-strength-4), `contentPaste = \uF0EA`
     (fa-clipboard), `wrench = \uF0AD`, `desktop = \uF108`,
     `workspaceSnapshot = \uF187`, `keyboard = \uF11C`, `mic = \uF130`.
   - `BarNerdIcon` adds **optical balancing**: it measures the glyph's ink box
     with `TextMetrics` and scales it (0.82×–1.14×) so different icons appear
     visually equal in weight.

2. **Material Symbols Rounded** — `Appearance.font.family.iconMaterial`
   (hard-coded `"Material Symbols Rounded"`). Used by `MaterialSymbol.qml`
   for the system-tray chevron (`keyboard_arrow_down` / `keyboard`) and a few
   other UI accents. Supports variable `FILL`/`opsz` axes.

3. **Cosmic icons / app & OS SVGs** — raster/vector image files, not a font:
   - App icons via `AppSearch.iconSource(...)` (`IconImage`) in ActiveWindow.
   - OS distro logos from `~/.config/omd/icons/OS/*.svg` (ActiveWindow).
   - Cosmic icon SVGs from `Directories.assetsPath/cosmic-icons/` via
     `CosmicIcon.qml` (used elsewhere in the shell, available to the bar).

Text labels ("Applications", "Workspaces", window titles, clock) use the main
UI font `Config.options.appearance.fonts.main` (default `Cantarell`).

## 6. Interaction model: the unified popup

Clicking most right-side modules sets `GlobalStates.barPopupType` to a string
(`audio`, `wifi`, `session`, `display`, `tools`, `inputMethod`, `xkb`,
`battery`, `notifications`, `clipboard`…). A single `BarStatusPopup.qml`
renders the matching content anchored under the bar; only one popup is open at
a time. There is a 200 ms dismiss guard (`barPopupDismissedAt`) so the same
click that closes a popup does not immediately reopen it. Wheel actions
(audio volume, display brightness) work directly on the icon without opening a
popup.

## 7. Quick file reference

| Concern | File |
| --- | --- |
| Process entry | `apps/omd-bar/shell.qml` |
| Per-monitor window + IPC + shortcuts | `quickshell/modules/bar/Bar.qml` |
| Three-section layout & ordering | `quickshell/modules/bar/BarContent.qml` |
| Left: Applications / Workspaces | `AppLauncherButton.qml`, `Workspaces.qml` |
| Left: Active window | `ActiveWindow.qml` |
| Right: modules | `modules/AudioButton.qml`, `WifiButton.qml`, `ClipboardButton.qml`, `SessionButton.qml`, `DisplayButton.qml`, `ToolsButton.qml` |
| Right: input method / clock / tray / sidebar | `modules/InputMethodButton.qml`, `ClockWidget.qml`, `SysTray.qml`, `SidebarIndicators.qml` |
| Unified popup | `BarStatusPopup.qml` |
| Nerd glyph constants | `common/widgets/NerdIconMap.qml` |
| Icon widgets | `common/widgets/NerdIcon.qml`, `BarNerdIcon.qml`, `MaterialSymbol.qml`, `CosmicIcon.qml` |
| Font/size tokens | `common/Appearance.qml`, `quickshell/config.json` |
