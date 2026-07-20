# OMD (oh-my-desktop) Project Handover Summary

This document summarizes the current state, architecture, recent features/fixes, and outstanding items for the OMD project to ensure a seamless transition for the next AI agent session.

---

## 1. Project Overview & Architecture

OMD is a unified desktop configuration repository for a custom Wayland desktop environment (Hyprland + Quickshell) running on Asahi Linux / Fedora.

### Process Split Architecture
To prevent single-thread QML bottlenecks, Quickshell is split into independent processes, running as transient systemd user services:
*   `omd-bar`: The top/bottom status bar.
*   `omd-desktop`: Desktop wallpaper, active window tracking, and surface interactions.
*   `omd-overview`: Workspace overview, workspace switcher, and cross-monitor dragging.
*   `omd-applauncher`: Clean fullscreen application grid (launched via `omd-applauncher toggle`).
*   `omd-clipboard`: Clipboard history manager (utilizing `cliphist` & `omd-clipboard-store`).

### Services & Styles
*   **Singletons**: Services (e.g. `Audio.qml`, `KeyboardRemap.qml`, `HyprlandData.qml`) are QML singletons under `quickshell/services/` and imported as `import qs.services`.
*   **Styling**: Standard color and layout tokens are defined in `quickshell/modules/common/TuiStyle.qml` and mapped in `quickshell/modules/common/Appearance.qml`.
*   **Config**: Central options are read from `quickshell/config.json` and parsed/deserialized dynamically via `JsonAdapter` in `quickshell/modules/common/Config.qml`.

---

## 2. Recent Accomplishments & Features (This Session)

We worked on the `refactor/settings-center` branch and accomplished the following:

### A. App Launcher Deduplication
*   **Path**: [bin/omd-applauncher-cache](file:///home/tetsuya/development/OMD/bin/omd-applauncher-cache)
*   **Issue**: Duplicate icons appeared for applications installed both globally (e.g. `/usr/share/applications`) and locally (e.g. `~/.local/share/applications`).
*   **Fix**:
    1.  Re-ordered search directories to follow standard XDG precedence (user directories first).
    2.  Added a pure-shell seen IDs checker (`case "$seen_ids" in ...`) to filter out lower-priority duplicates.
    3.  Refactored short-circuit `&&` checks to standard `if` blocks to prevent shell exits under `set -e`.

### B. Screenshot Tool (Region Selector) Optimizations
*   **Paths**: [RegionSelection.qml](file:///home/tetsuya/development/OMD/quickshell/modules/regionSelector/RegionSelection.qml), [ScreenshotAction.qml](file:///home/tetsuya/development/OMD/quickshell/modules/common/utils/ScreenshotAction.qml)
*   **Optimizations**:
    1.  **0ms Instant Activation**: Removed the slow full-screen `grim` pre-capture step and python-based OpenCV image detection. The UI now freezes and opens instantly via `ScreencopyView`.
    2.  **Zero-UI Clean Overlay**: Removed `OptionsToolbar` and the bottom Close button row entirely. The selection layer is completely clean. Press `Esc` to cancel, or release the mouse to save.
    3.  **Square Constraint**: Added `Shift` key constraint to force perfect `1:1` square selection crops.
    4.  **Edit Mode & Swappy/Satty Integration**: Fixed a bug where releasing the Left mouse button would reset the explicitly set `Edit` action back to `Copy`. Added a **"Capture & Edit"** option to the status bar screenshot right-click menu ([ScreenshotContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/ScreenshotContextMenu.qml)) which directly launches `swappy`/`satty` upon crop.

### C. Standalone Screenshot Tool Split & Launch Fixes
*   **Paths**: [shell.qml](file:///home/tetsuya/development/OMD/apps/omd-screenshot/shell.qml), [GlobalStates.qml](file:///home/tetsuya/development/OMD/apps/omd-screenshot/GlobalStates.qml)
*   **Fixes**:
    1.  **Directory-Level Symlinking**: Replaced individual file symlinks in `apps/omd-screenshot/modules/` and `apps/omd-screenshot/services/` with directory symlinks (`modules -> ../../quickshell/modules`, `services -> ../../quickshell/services`). This allows Quickshell's virtual interceptor to correctly generate virtual `qmldir` files, resolving styling singletons (`TuiStyle` and `OmarchyTheme`) automatically.
    2.  **Prevent Startup Auto-Exit**: Set `regionSelectorOpen` to `true` by default in the standalone `GlobalStates.qml`. This instantiates the window immediately, keeping the event loop alive.
    3.  **Correct Import Namespaces**: Swapped relative directory imports with the `qs` namespace (`import qs.modules.common` and `import qs.services`) in `shell.qml` to correctly resolve singleton instances.
    4.  **Launcher Script Safety**: Bound `action="${1:-screenshot}"` at the top of [bin/omd-screenshot](file:///home/tetsuya/development/OMD/bin/omd-screenshot) to prevent unbound variable crashes under `set -u`.
    5.  **UI Droplet Removal**: Rewrote [CursorGuide.qml](file:///home/tetsuya/development/OMD/quickshell/modules/regionSelector/CursorGuide.qml) and [TargetRegion.qml](file:///home/tetsuya/development/OMD/quickshell/modules/regionSelector/TargetRegion.qml) to replace droplet shapes with rounded rectangles matching `TuiStyle`.

### D. Network TUI (nmtui) Sizing & Floating Fixes
*   **Paths**: [NetworkContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/NetworkContextMenu.qml), [looknfeel.lua](file:///home/tetsuya/development/OMD/hypr/looknfeel.lua)
*   **Issues**:
    1.  **TUI Size Mismatch**: When launched, the terminal window was tiled/sized dynamically, causing `nmtui` to render with massive unpainted black margins because it missed the window manager's resize events.
    2.  **Tiling/Floating Race**: Matching rules by window title (`title = "nmtui"`) is unreliable in Hyprland because the title is set asynchronously after mapping, causing the window to sometimes default to tiling.
*   **Fixes**:
    1.  **Pass Size on Startup**: Added `--window-size-pixels=880x620` to the `foot` command to force it to start at the target size.
    2.  **Class/App-ID Matching**: Added `--app-id=nmtui` to the launcher, and matched the rule using `o.window("^nmtui$", ...)` directly, ensuring the window floats, centers, and scales perfectly with 100% blue canvas coverage.


### E. Display Button Right-Click Context Menu Restoration
*   **Paths**: [DisplayButton.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/modules/DisplayButton.qml), [ScreenshotContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/modules/ScreenshotContextMenu.qml)
*   **Fix**:
    1.  **Self-Contained Right-Click Menu**: Re-created `ScreenshotContextMenu.qml` as a self-contained component inside the `bar/modules` folder. It declares inline helper components (`MenuItem` and `Separator`) and uses `TuiStyle` visual tokens to match the unified GNOME Shell aesthetics.
    2.  **Alt-Action Binding**: Added `altAction: () => screenshotMenu.open()` to the `CircleUtilButton` inside `DisplayButton.qml`, enabling independent right-click behavior.
    3.  **Property Collision Fix**: Named the icon property `menuIcon` inside the inline `MenuItem` component to avoid conflict with Qt Quick Control's final `Button.icon` property.


### F. Clock Hover Timezone Popup Restoration
*   **Paths**: [ClockWidget.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/ClockWidget.qml), [ClockHoverPopup.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/ClockHoverPopup.qml)
*   **Fix**:
    1.  **Timezone Popup Restoration**: Re-created `ClockHoverPopup.qml` inside `quickshell/modules/bar/` to dynamically calculate and render local times for Japan (JST), China (CST), and US Eastern (EST/EDT).
    2.  **Hover Binding**: Restored `hoverEnabled: true` and `mouseArea` ID in `ClockWidget.qml`'s `MouseArea`, and targeted `ClockHoverPopup` to open on hover.


### G. Power Button Right-Click Context Menu Restoration
*   **Paths**: [SidebarIndicators.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/SidebarIndicators.qml), [PowerContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/PowerContextMenu.qml)
*   **Fix**:
    1.  **Right-Click Menu**: Re-created `PowerContextMenu.qml` as a self-contained component in `quickshell/modules/bar/` aligned with the design styling rules of `TuiStyle`.
    2.  **Power Button Hook**: Added a nested `MouseArea` to `powerButton` accepting only `Qt.RightButton`, loading and opening `PowerContextMenu` on right-click without affecting the default left-click behavior.
    3.  **English UI**: Configured all menu labels in both `PowerContextMenu.qml` and `ScreenshotContextMenu.qml` as plain English literals to enforce standard English titles.


### H. Global Settings TUI Compact Styling Redesign
*   **Paths**: [SettingsTokens.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/SettingsTokens.qml), [DisplayPage.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/display/DisplayPage.qml), [OutputCard.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/display/OutputCard.qml), [MonitorCanvas.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/display/MonitorCanvas.qml)
*   **Fix**:
    1.  **Global Corner Rounding Reduction**: Decreased global `radius` to `4` and `roundRadius` to `6` in `SettingsTokens.qml`, transforming all cards, buttons, dropdowns, and rows to a blocky, retro TUI aesthetic.
    2.  **Monitor Canvas Optimization**: Reduced preview canvas height to `160px` (from `260px`) and aligned all color backgrounds, internal padding, and border outlines to `SettingsTokens`.
    3.  **Display Settings Layout Spacing**: Shrank layout spaces and paddings from `18` to `12` on `DisplayPage.qml`.
    4.  **Control Scaling**: Downscaled custom `SmallButton` and `ComboBox` heights from `42`/`38` to `30`/`28` across the display pages, replacing hardcoded color hex values with global semantic tokens.


### I. Topbar Popup Headers Divider Line Restoration
*   **Paths**: [PopupHeader.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/PopupHeader.qml), [PopupDeviceRow.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/PopupDeviceRow.qml), [BarStatusPopup.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/BarStatusPopup.qml)
*   **Fix**:
    1.  **Divider Opacity Enhancement**: Changed the default bottom divider line opacity from `0.10` to `TuiStyle.dividerOpacity` (which is `0.28`) in both `PopupHeader.qml` and `PopupDeviceRow.qml`. This makes the divider below the headers clearly visible against the dark background for all status bar popup windows.
    2.  **Volume Popup Header Addition**: Added a matching `PopupHeader` component to the top of `audioContent` (the volume/mic sliders panel) in `BarStatusPopup.qml`, displaying active muting and volume percentages along with the divider line.


### J. Divider Unification & Hover Background Rounded Corner Masking
*   **Paths**: [TuiShell.qml](file:///home/tetsuya/development/OMD/quickshell/modules/common/widgets/TuiShell.qml), [BarStatusPopup.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/BarStatusPopup.qml), [ScreenshotContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/modules/ScreenshotContextMenu.qml), [PowerContextMenu.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/PowerContextMenu.qml)
*   **Fix**:
    1.  **Rounded Corner Masking**: Enabled QML layers and applied an `OpacityMask` on `TuiShell.qml`, `ScreenshotContextMenu.qml`, and `PowerContextMenu.qml` backgrounds. This forces all inner elements (such as list item highlights and bottom footer links) to clip perfectly to the window's rounded corners, resolving the issue where hover background shapes covered up the container's rounded borders.
    2.  **Divider Line Unification**: Standardized all horizontal section/footer dividers in `BarStatusPopup.qml` to use a consistent height of `1px` and opacity of `TuiStyle.dividerOpacity`, matching the visual brightness of header/device separators.


### K. Restricted Toggle Clicks to Switch Controls
*   **Paths**: [SettingsRow.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/widgets/SettingsRow.qml), [SettingsToggleRow.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/widgets/SettingsToggleRow.qml)
*   **Fix**:
    1.  **Row Clickability Property**: Added a `clickable` property (defaulting to `true`) on the base `SettingsRow.qml` to disable row-level mouse clicks and hover highlights when set to `false`.
    2.  **Switch-Only Event Handling**: Applied `clickable: false` on `SettingsToggleRow.qml` (meaning the row itself does not highlight or trigger clicks) and added a dedicated `MouseArea` directly inside the switch's `Rectangle` control to trigger the toggle, preventing clicking on blank row areas or labels from activating the switch.


### L. Notifications Popup Header & List Height Optimization
*   **Paths**: [PopupHeader.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/PopupHeader.qml), [BarStatusPopup.qml](file:///home/tetsuya/development/OMD/quickshell/modules/bar/BarStatusPopup.qml), [TuiNotificationList.qml](file:///home/tetsuya/development/OMD/quickshell/modules/schedulePopup/notifications/TuiNotificationList.qml)
*   **Fix**:
    1.  **Switch & Broom Relocation**: Moved the DND switch and the notification clear broom (`delete_sweep` icon) directly into the right side of the `PopupHeader`. Removed the redundant "Do not disturb" list row.
    2.  **Row Height Sizing Fix**: Added `height: implicitHeight` on `NotificationRow` in `TuiNotificationList.qml` to prevent inner text content from overlapping or breaking card borders due to lack of explicit height bindings.
    3.  **Scroll & Height Expansion**: Expanded the maximum list height constraint to `Math.round((popupWindow.screen?.height ?? 900) * 0.72)` (occupying ~72% of the screen height, allowing space for more notification cards) and integrated `ScrollBar.vertical: StyledScrollBar {}` for smooth scrolling.
    4.  **Layout Padding / Margin Fix**: Resolved a circular QML layout dependency on `implicitWidth` inside `TuiNotificationList.qml` by declaring explicit left/right margins (16px) on the list's `ColumnLayout` and removing parent-anchoring width loops. Added `Layout.topMargin: 12` and `Layout.bottomMargin: 16` on `TuiNotificationList` in `BarStatusPopup.qml` to prevent notification cards from touching the top divider or bottom window shell borders.
    5.  **Toggle Switch Size Unification**: Standardized the inline DND switch inside `BarStatusPopup.qml` and `TuiToggle` in `TuiNotificationList.qml` to use the exact same dimensions (`46px` width, `26px` height, and `20px` knob size) as defined in `SettingsToggleRow.qml`, enforcing visual consistency across all toggle switches in the system.
    6.  **Divider Resolution Import Fix**: Resolved a QML `ReferenceError` where `TuiStyle` was undefined inside `PopupToggleRow.qml`, `PopupFooterLink.qml`, and `PopupInfoRow.qml` due to missing module imports. By adding `import qs.modules.common` to these files, `TuiStyle` now resolves correctly, allowing all divider line opacities to properly bind to `0.28` (making them uniform, subtle dark grey lines instead of falling back to default solid white).

---

## 3. Important Design Details & Development Gotchas

### Quickshell Systemd Transient Units
*   Quickshell services are restarted via `scripts/reload-quickshell` (which calls `bin/omd-restart`).
*   **Gotcha**: If a service (like `omd-bar`) crashes with a Segfault, its systemd user transient unit will enter the `failed` state. Systemd refuses to spawn a new service with the same unit name until the failure state is cleared.
*   **Fix**: Run `systemctl --user reset-failed omd-bar` to reset it, or use `scripts/reload-quickshell` which handles teardowns.

### Uncommitted Working Tree Diffs
There are uncommitted changes on the `refactor/settings-center` branch that represent active keyboard remapping work:
1.  **`keyboard-remap/profiles.json`**: Device profile definitions including the user's magic keyboard and SPI keyboard.
2.  **`share/bin/omarchy-keyboard-list`**: Optimizations to keyboard detection heuristics (replacing mouse-sibling checks).
3.  **`share/bin/omarchy-system-logout`**: Updated exit dispatcher call.

---

## 4. Handover & Next Steps

When spawning the next session:
1.  Ensure all quickshell services are active: `pgrep -af '(quickshell)'`.
2.  Test the **"Capture & Edit"** menu item on the top bar's screenshot right-click menu.
3.  Re-integrate the `keyd` warning card into [SettingsCenter.qml](file:///home/tetsuya/development/OMD/quickshell/modules/settings/SettingsCenter.qml#L1716) if requested.

This summary document is saved at:
`/home/tetsuya/development/OMD/docs/project-handover-summary.md`
