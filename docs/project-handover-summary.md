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
