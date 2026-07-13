# Settings Panel UX Optimization

## Purpose

OMD settings have been split into focused panels. The next step is to simplify
the content hierarchy inside each panel.

The goal is not to remove capabilities. It is to keep the first view focused
on the task that caused the user to open the panel, while moving secondary,
advanced, diagnostic, and destructive operations into local detail views.

This document is a design proposal only. It does not describe completed UI
work.

## Current Problem

The panels no longer have a global category sidebar, but most pages still use
the old control-center structure: every available card is placed in one long
scrolling column.

This creates several problems:

- common operations compete visually with rarely used configuration;
- a simple task requires scanning unrelated cards;
- diagnostics, paths, external tools, and destructive actions look as
  important as normal controls;
- the user has to remember card positions instead of following a clear local
  hierarchy;
- adding features makes each root page progressively longer.

The main example is Displays: monitor arrangement is the primary task, while
brightness, night light, wallpaper, OSD behavior, and low-level output options
are different tasks. They should not all be expanded at the same level.

## Design Principles

### 1. One panel, one primary task

The root view should answer three questions immediately:

1. What is the current state?
2. What is the most likely action?
3. Where are the less common options?

The root view should normally contain no more than two expanded sections.

### 2. Progressive disclosure

Use three levels of importance:

| Level | Content | Presentation |
| --- | --- | --- |
| Primary | current status and frequent controls | expanded on the root view |
| Secondary | a distinct task used occasionally | compact navigation row opening a local subpage |
| Advanced | diagnostics, raw values, paths, external tools, destructive actions | Advanced, Diagnostics, or Maintenance subpage |

Collapsing content must not mean putting every section into independent
accordions. Too many accordions still produce a busy page and hide structure.
Use subpages for complete tasks and disclosure sections only for a small set of
closely related controls.

### 3. Preserve context inside the panel

Opening a secondary task should not launch another unrelated settings window.
Each focused panel should own a small local navigation stack:

```text
Displays
  -> Night light
  -> Wallpaper
  -> Advanced output settings
```

The title bar changes to the subpage title and gains a Back button. Close still
closes the complete settings panel. Escape returns to the previous subpage
first, then closes the root panel.

### 4. Status is compact; controls appear when needed

A navigation row can communicate useful state without expanding its controls:

```text
Night light                         On, 4500 K  >
Wallpaper                           Tokyo street  >
Brightness                          72%           >
```

This is more useful than either hiding the feature completely or rendering its
entire form on the root page.

### 5. Separate normal, advanced, and dangerous actions

- normal actions remain near their related content;
- external tools live under Advanced or Open in external tool;
- logs and filesystem paths live under Diagnostics;
- removal, reset, and data deletion live in a Danger Zone at the bottom of a
  detail page and require confirmation.

### 6. Keep the visual language shared

The split is behavioral, not visual. Every panel continues to use
`SettingsPanelFrame.qml`, `SettingsTokens.qml`, and shared settings widgets.
New hierarchy patterns must also be implemented once as shared components.

## Shared Page Structure

Each root panel should use this order:

```text
Title bar

Status summary
  current state, warnings, one primary action

Primary controls
  only controls needed for the panel's main task

Related settings
  compact rows opening local subpages

Advanced
  one compact entry, placed last
```

Avoid using a large card for every section. A card should group controls that
form one operation. Related-settings navigation can be a single list surface
with separators.

## Proposed Shared Components

The following components should be added under
`quickshell/modules/settings/widgets/` before individual pages are redesigned:

### `SettingsSummary`

Compact status area with icon, title, state, optional warning, and one primary
action. It replaces repeated status pills and multiple state rows where a
single summary is enough.

### `SettingsNavigationRow`

A standard row with icon, label, short description, current value, and
chevron. It opens a local subpage and has a fixed row height and alignment.

### `SettingsSection`

An unframed section heading plus content. Use it when a separate card would add
visual weight without adding meaning.

### `SettingsDisclosure`

An expandable area for a small number of closely related options. Expansion
state is local to the page. It is not a replacement for task-oriented
subpages.

### `SettingsSubpage`

Defines a local page title, optional subtitle, content, and Back behavior. The
shared panel frame owns its navigation stack and scrolling position.

### `SettingsDangerZone`

Consistent destructive-action container with warning text and explicit
confirmation state.

### `SettingsEmptyState`

Consistent empty/loading/error presentation for network lists, Bluetooth
devices, voice history, and VM state.

## Panel Proposals

## Network

### Root view

- Wi-Fi radio and current connection in one compact summary.
- Current SSID, signal strength, and connection state.
- Available networks list, with Scan as the primary toolbar action.
- Ethernet appears as a compact status row only when available.

### Secondary views

- **Known Networks**: saved networks, autoconnect state, forget, priority.
- **Connection Details**: interface, addresses, gateway, DNS, security.
- **Advanced**: Connection Editor and Network TUI launchers.

Bluetooth must not appear in the Network root view when the panel was opened as
Bluetooth. The shared backend may remain, but the two entry points should have
independent page hierarchies.

## Bluetooth

### Root view

- Adapter power and discovery state in the summary.
- Connected devices first, including battery when available.
- Nearby devices below, with Scan as the primary action.

### Secondary views

- Selecting a device opens **Device Details** with connect/disconnect, trust,
  pair/unpair, battery, address, and device type.
- **Saved Devices** contains paired devices that are not currently nearby.
- **Advanced** contains adapter details and Blueman Manager.

## Sound

### Root view

- Master output volume, mute, and current output device.
- Microphone volume, mute, and current input device.
- Device selectors should be compact rows rather than full device-management
  lists.

### Secondary views

- **Output Devices**: select, rename, inspect, and remove aliases.
- **Input Devices**: select and configure microphones.
- **Application Mixer**: per-application streams when supported.
- **Feedback & OSD**: volume OSD, microphone OSD, and system feedback options.
- **Advanced**: external volume control and audio-service restart.

## Displays

### Root view

- Monitor canvas remains the dominant element.
- Selecting a monitor exposes only resolution, scale, orientation, and the
  pending Apply/Reset actions.
- Identify and Refresh stay in the monitor-canvas toolbar.
- A single **Related settings** list appears below the canvas.

### Related settings

- **Brightness**: current percentage; subpage contains slider and OSD option.
- **Night light**: current on/off state and temperature; subpage contains
  enable, temperature, schedule, and preview/reset actions.
- **Wallpaper**: current file/folder; subpage owns image selection, folder
  rotation, interval, next image, and stop rotation.
- **Advanced output settings**: position coordinates, refresh-rate details,
  future VRR/HDR/10-bit controls, and `wlr-randr` launcher.

Brightness is screen-specific. The subpage must clearly identify which output
is being adjusted and preserve the monitor selected on the root view.

## Appearance

### Root view

- Current theme summary with its name and generated color swatches.
- A compact, searchable theme list or grid. No wallpaper screenshots.
- Applying a theme remains the primary operation and must not close the panel.

### Secondary views

- **Terminal Font**: family, size, preview, and Apply.
- **Effects & Performance**: High Performance, Balanced, Best Visuals, followed
  by the individual settings represented by the preset.
- **Theme Details**: palette, source directory, refresh, and open folder.

Wallpaper remains under Displays because it is a desktop-output operation in
the current product model. Appearance may show the current wallpaper only as a
link to the Displays wallpaper subpage, not duplicate its controls.

## Power & Battery

### Root view

- Battery level, charging state, remaining time, and health in one summary.
- Power profile segmented control.
- Temporary Prevent Sleep toggle.

### Secondary views

- **Charging & Battery Protection**: charge limit and reached-limit alert.
- **Low Battery Actions**: low/critical thresholds, notifications, power saver,
  and automatic suspend.
- **Idle & Sleep**: screensaver, lock, DPMS, suspend, and lock-before-suspend.
- **Automatic Profiles**: separate AC and battery profile policies.
- **Feedback & OSD**: power profile and idle-inhibitor OSD.
- **Battery Details**: power draw, health, and technical values.

The root page should not expose all timeout dropdowns. Power profile and
Prevent Sleep are the only controls that need immediate access.

## System

The current System page contains several unrelated administration tasks. Its
root should become a directory rather than a long form.

### Root view

- Compact system/OMD status summary.
- Navigation rows for Autostart, Window Rules, Default Applications, and OMD
  Application Commands.

### Secondary views

- **Autostart Applications**: list, enable/disable, open folder, refresh.
- **Window Rules**: rule list. Add/Edit opens a separate editor subpage rather
  than displaying the editor below the list.
- **Default Applications**: browser, file manager, and MIME defaults.
- **OMD Application Commands**: terminal, task manager, and update command.
- **Diagnostics**: configuration paths, reload actions, and doctor output.

Quick Add presets belong inside the Window Rule editor, not on the System root.

## Voice Input

### Root view

- Engine readiness summary.
- One Record/Stop test action.
- Last transcription or last error, never both as equally prominent rows.
- Current shortcut as a compact row.

### Secondary views

- **Setup & Model**: environment, model installation, size, and recheck.
- **Shortcut**: configure and capture key.
- **History**: transcription history and clear action.
- **Diagnostics**: Quick Test, TUI Test, diagnose, daemon state, paths, cache,
  and socket.

Runtime paths are implementation details and must not occupy the root page.

## Keyboard Remap

### Root view

- keyd readiness and pending-change state in the summary.
- Keyboard list with connected/saved state.
- Apply Changes appears only while a draft exists.

### Device detail view

- Device name, connection state, and Enable toggle.
- Preset list with current mappings.
- Selecting a preset opens the existing key editor as a proper local subpage.

### Secondary views

- **Setup & Permissions**: keyd setup, authorization, and vendor/product ID.
- **Advanced**: raw generated config, refresh, and troubleshooting.
- Removing a saved profile belongs in a Danger Zone in device details.

The Apply confirmation remains a modal because it authorizes a system write;
normal device navigation should not use modals.

## Windows VM

### Root view

- VM state summary: Not installed, Installing, Stopped, Running, or Ready.
- One state-dependent primary action: Install, Continue Setup, Start & Connect,
  or Connect.
- Compact resource summary for CPU, RAM, disk, and storage location.
- Installation progress appears in place of normal controls while active.

### Secondary views

- **Requirements**: KVM, Docker, Compose, FreeRDP, disk space, and repair
  actions. Show this automatically only when a blocker exists.
- **Connection**: RDP endpoint, web console, and Keep Alive.
- **Resources & Sharing**: RAM, CPU, disk, user, and shared folder.
- **Logs & Diagnostics**: phase, reachability, logs, and refresh.
- **Maintenance**: Stop and confirmed Remove. Remove belongs in a Danger Zone.

System requirements should not remain permanently expanded after the VM is
healthy.

## OMD Tools

The wrench menu is the primary entry point. If `OMD Tools` is opened as a
window, it should stay a simple directory with four navigation rows:

- Themes
- Voice Input
- Keyboard Remap
- Windows VM

It should contain no status dashboard and no configuration controls. Its only
job is discoverability for advanced tools that do not own a dedicated bar
status icon.

## Navigation Behavior

### Opening

- A bar item opens the root of its focused panel.
- A direct action may open a specific subpage, for example Displays ->
  Wallpaper.
- Reopening an already running panel with a different target resets the local
  navigation stack to that target.

### Back and close

- Back button: pop one local subpage.
- Escape/Q on a subpage: pop one local subpage.
- Escape/Q on the root page: close the panel.
- Close button: always close the panel immediately.
- Losing focus: do nothing.

### State preservation

- Preserve selected monitor/device while navigating within the same panel.
- Preserve draft edits until Apply, Reset, or close confirmation.
- Preserve scroll position per local subpage while the process remains open.
- Do not persist transient navigation paths across cold starts.

## Visual Rules

- Root pages should normally fit their summary and primary controls without
  scrolling at the default dialog size.
- Use one main content column, with two columns only for short controls that
  form one operation.
- Do not nest cards inside cards.
- Prefer separators and spacing over additional borders.
- Navigation rows use one shared height, icon column, value column, and
  chevron alignment.
- Descriptions should explain consequences, not restate labels.
- A secondary value should use muted text; warnings use warning color; only the
  active selection and primary action use the theme accent.
- Empty, loading, and error states must occupy stable dimensions so lists do
  not jump during refresh.

## Implementation Order

### Phase 1: navigation foundation

1. Add the shared summary, navigation-row, section, subpage, danger-zone, and
   empty-state components.
2. Add a local navigation stack to `SettingsPanelFrame.qml` or a dedicated
   panel navigator owned by it.
3. Define Back/Escape behavior and direct subpage routing.

### Phase 2: high-impact panels

1. Displays
2. Power & Battery
3. Sound
4. Network and Bluetooth

These pages currently expose the most unrelated controls at once and will
validate the shared hierarchy components.

### Phase 3: advanced tools

1. Voice Input
2. Keyboard Remap
3. Windows VM

These pages need clear separation between normal state, setup, diagnostics,
and destructive operations.

### Phase 4: remaining panels

1. Appearance
2. System
3. OMD Tools directory

### Phase 5: consistency review

- verify default-size layout at laptop and external-monitor scales;
- verify keyboard navigation and focus restoration;
- verify direct entry from every bar popup and the wrench menu;
- verify cold start and process exit for every root page and subpage;
- check that changing shared style tokens updates every new component.

## Acceptance Criteria

The redesign is complete when:

- every entry point opens a focused root view with one obvious primary task;
- secondary tasks are reachable in one click through consistently styled rows;
- root pages do not expose diagnostics, raw paths, logs, or destructive actions;
- Back, Escape, Q, and Close have consistent behavior in every panel;
- no feature duplicates its controls across multiple panels;
- no feature page implements its own navigation chrome, row geometry, colors,
  or danger styling;
- each panel can still be cold-started independently through `bin/omd-settings`;
- all existing capabilities remain reachable after the hierarchy change.

## Decisions Needed Before Implementation

1. Confirm that wallpaper remains owned by Displays rather than Appearance.
2. Confirm that Brightness, Night light, and Wallpaper use subpages rather than
   inline accordions.
3. Confirm that Network and Bluetooth remain separate visible panels even if
   they continue sharing one QML backend temporarily.
4. Confirm that Escape on a subpage means Back, while Escape on the root closes
   the panel.
5. Confirm that OMD Tools remains a directory only and does not become another
   general settings center.
